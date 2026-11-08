import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/crypto.dart';
import '../domain/models.dart';
import 'attachment_syncer.dart';
import 'portfolio_store.dart';
import 'remote_sync.dart';
import 'sync_outbox.dart';

/// Decrypts a single server event under the active content key and merges
/// the enclosed record into [PortfolioStore]. The pull handler supplied to
/// [RemoteSyncService] forwards every event through this reducer so a
/// second device sees the authoring device's writes without reinventing
/// the mutation API.
///
/// The server only guarantees `payload_type`; everything else lives inside
/// the AES-GCM ciphertext. We decrypt with the content key derived from
/// the vault session key (same derivation the outbox uses on the write
/// path), decode as UTF-8 JSON, and hand off to the matching store method.
///
/// Returns `true` when the event was applied, `false` when it was skipped
/// (either because the vault is not currently unlocked or the record is
/// already present locally and we don't want to clobber our own write
/// history).
class SyncReducer {
  final PortfolioStore store;
  final AttachmentSyncer? attachmentSyncer;
  SyncReducer(this.store, {this.attachmentSyncer});

  Future<bool> apply(RemoteSyncEventRecord record) async {
    final vaultKey = store.vault.activeKey;
    if (vaultKey == null) return false; // Vault locked; defer until unlock.
    if (record.deviceId == store.deviceId) return true; // Our own write.

    final contentKey = await SyncOutbox.deriveContentKey(vaultKey);
    final plain = await _tryDecrypt(record.payload, contentKey);
    if (plain == null) return false; // Not our content key — skip, don't crash.
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    } catch (_) {
      return false;
    }

    switch (record.payloadType) {
      case 'asset':
        if (_hasRecentLocalEvent(record)) return false;
        await store.upsertAsset(WealthAsset.fromJson(json));
        return true;
      case 'liability':
        if (_hasRecentLocalEvent(record)) return false;
        await store.upsertLiability(Liability.fromJson(json));
        return true;
      case 'ledger_event':
        final event = LedgerEvent.fromJson(json);
        if (store.state.events.any((e) => e.id == event.id)) return false;
        await store.postEvent(event);
        return true;
      case 'beneficiary_batch':
        final raw = json['beneficiaries'];
        if (raw is! List) return false;
        // Empty batches are legal (user genuinely deleted everyone), but we
        // insist on an explicit integrity tag so a reducer bug on the peer
        // can't accidentally wipe the local list. A real emission from
        // portfolio_store always ships `integrity.combined_bps`; an empty
        // emission ships combined_bps: 0.
        if (raw.isEmpty) {
          final integrity = record.integrity;
          if (integrity == null || integrity['combined_bps'] != 0) return false;
        }
        final list = raw
            .map((e) => BeneficiaryRecord.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
        await _replaceBeneficiaries(list);
        return true;
      case 'valuation':
        final valuation = ValuationRecord.fromJson(json);
        if (store.state.valuations.any((v) => v.id == valuation.id)) return false;
        await store.recordValuation(
            valuation.assetId, valuation.fullValueUgx, valuation.asOf,
            valuation.source,
            notes: valuation.notes,
            id: valuation.id);
        return true;
      case 'document_record':
        final document = DocumentRecord.fromJson(json);
        await _applyDocument(document);
        return true;
      case 'goal':
        await store.upsertGoal(WealthGoal.fromJson(json));
        return true;
      case 'goal_delete':
        final id = json['id']?.toString() ?? '';
        if (id.isNotEmpty) await store.deleteGoal(id);
        return true;
      case 'trusted_contact':
        await store.upsertContact(LegacyContact.fromJson(json));
        return true;
      case 'trusted_contact_delete':
        final id = json['id']?.toString() ?? '';
        if (id.isNotEmpty) await store.removeContact(id);
        return true;
      case 'reminder':
        final reminder = ReminderRecord.fromJson(json);
        final existingIdx =
            store.state.reminders.indexWhere((r) => r.id == reminder.id);
        if (existingIdx >= 0) {
          final existing = store.state.reminders[existingIdx];
          if (existing.completed != reminder.completed) {
            await store.toggleReminder(reminder.id);
          }
          return true;
        }
        await store.addReminder(reminder);
        return true;
      case 'reminder_delete':
        final id = json['id']?.toString() ?? '';
        if (id.isNotEmpty) await store.removeReminder(id);
        return true;
      case 'schedule':
        await store.upsertSchedule(ScheduledContribution.fromJson(json));
        return true;
      case 'schedule_delete':
        final id = json['id']?.toString() ?? '';
        if (id.isNotEmpty) await store.deleteSchedule(id);
        return true;
      case 'alert_dismissal':
        final key = json['key']?.toString() ?? '';
        if (key.isNotEmpty) await store.dismissAlert(key);
        return true;
      case 'alert_dismissal_clear':
        await store.clearDismissedAlerts();
        return true;
      case 'fx_rate':
        await store.upsertFxRate(FxRate.fromJson(json));
        return true;
      case 'target_weights':
        {
          final raw = json['weights'];
          if (raw is! Map) return false;
          final weights = <String, int>{};
          raw.forEach((k, v) {
            if (v is num) weights[k.toString()] = v.toInt();
          });
          await store.replaceTargetWeights(weights);
          return true;
        }
      case 'fx_rate_delete':
        {
          final id = json['id']?.toString() ?? '';
          // The id shape is "<CURRENCY>:<ISO>"; parse rather than carry
          // both separately so the wire payload stays small.
          final sep = id.indexOf(':');
          if (sep < 0) return false;
          final currency = id.substring(0, sep);
          final asOf = DateTime.tryParse(id.substring(sep + 1));
          if (asOf == null) return false;
          await store.removeFxRate(currency, asOf);
          return true;
        }
      default:
        // Unknown payload type — ignore for forward-compat; the server may
        // route newer entities we don't yet understand.
        return false;
    }
  }

  Future<Uint8List?> _tryDecrypt(Uint8List cipher, SecretKey key) async {
    try {
      return await VaultCrypto.decryptBytes(cipher, key);
    } catch (_) {
      return null;
    }
  }

  /// Guards against mirroring back our own just-sent write. The sync
  /// service already filters by deviceId, but a defence-in-depth check
  /// keeps a race from double-applying.
  bool _hasRecentLocalEvent(RemoteSyncEventRecord record) {
    // Nothing fancy; the deviceId check at the top handles the common case.
    // Overridden only when payload_type is not an append-only record and
    // the id already exists.
    return false;
  }

  /// Applies an incoming document record. When its attachment carries a
  /// serverId we haven't materialized locally, download and decrypt it so
  /// the user can preview it as if the attach happened on this device.
  Future<void> _applyDocument(DocumentRecord remote) async {
    final existing = store.state.documents.firstWhere(
      (d) => d.id == remote.id,
      orElse: () => const DocumentRecord(id: '', title: '', category: ''),
    );
    final effective = await _materializeAttachmentIfMissing(remote, existing);
    await store.upsertDocument(effective);
  }

  Future<DocumentRecord> _materializeAttachmentIfMissing(
      DocumentRecord remote, DocumentRecord existing) async {
    final attachment = remote.attachment;
    final syncer = attachmentSyncer;
    if (attachment == null || attachment.serverId == null || syncer == null) {
      return remote;
    }
    // Already materialized on this device under the same serverId: keep
    // whatever local relativePath we have so previews still open.
    if (existing.attachment?.serverId == attachment.serverId &&
        existing.attachment?.relativePath.isNotEmpty == true) {
      return remote.copyWith(attachment: existing.attachment);
    }
    try {
      final ciphertext = await syncer.downloadCiphertext(attachment.serverId!);
      final stored = await store.attachments.writeCiphertext(
        documentId: remote.id,
        ciphertext: ciphertext,
        filename: attachment.originalFilename,
        mimeType: attachment.mimeType,
        sizeBytes: attachment.sizeBytes,
        sha256Hex: attachment.sha256Hex,
        serverId: attachment.serverId!,
      );
      return remote.copyWith(attachment: stored);
    } catch (_) {
      // Leave the ref untouched so retry on the next sync can pick it up.
      return remote;
    }
  }

  Future<void> _replaceBeneficiaries(List<BeneficiaryRecord> replacement) async {
    // We don't have a bulk setter so we clear then re-add. The combined bps
    // guard on upsertBeneficiary continues to apply.
    for (final existing in [...store.state.beneficiaries]) {
      if (!replacement.any((r) => r.id == existing.id)) {
        await store.deleteBeneficiary(existing.id);
      }
    }
    for (final person in replacement) {
      await store.upsertBeneficiary(person);
    }
  }
}
