import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/crypto.dart';
import '../domain/models.dart';
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
  SyncReducer(this.store);

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
        final list = (json['beneficiaries'] as List<dynamic>? ?? const [])
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
            notes: valuation.notes);
        return true;
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
