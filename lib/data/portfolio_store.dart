import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../domain/models.dart';
import '../domain/finance.dart';
import 'vault.dart';
import 'attachment_store.dart';
import 'attachment_syncer.dart';
import 'resource_publisher.dart';
import 'sync_outbox.dart';

/// Local, offline-first repository. In 0.3 this wrote cleartext to
/// SharedPreferences; 0.4 can transparently keep the same payload on disk, or
/// — when a passphrase is set — persist an AES-GCM envelope and mediate all
/// reads and writes through [Vault]. Nothing is pushed to a server.
class PortfolioStore extends ChangeNotifier {
  PortfolioStore({
    Vault? vault,
    AttachmentStore? attachments,
    this.outbox,
    this.attachmentSyncer,
    this.resourcePublisher,
    String? deviceId,
  })  : vault = vault ?? Vault(),
        attachments = attachments ?? AttachmentStore(),
        deviceId = deviceId ?? _newDeviceId() {
    this.vault.addListener(notifyListeners);
  }

  final Vault vault;
  final AttachmentStore attachments;
  final SyncOutbox? outbox;
  final AttachmentSyncer? attachmentSyncer;
  /// Optional publisher that mirrors every outbox write to the server's
  /// REST resource layer. When null (no online scope wired, or the user
  /// has not signed in yet), every mutation still goes to the outbox and
  /// the next /sync/events push will carry it across.
  final ResourcePublisher? resourcePublisher;
  final String deviceId;

  /// When true, _recordOutbox is a no-op. Set by the SyncReducer while
  /// replaying a pulled record so the store doesn't re-emit the same
  /// mutation back to the server — which would otherwise ping-pong
  /// between every pair of devices forever.
  bool _suppressOutbox = false;

  /// Hook for the reducer. Wraps the block in a flag so every write it
  /// performs stays local (no outbox, no REST publish).
  Future<T> applyingRemote<T>(Future<T> Function() block) async {
    final previous = _suppressOutbox;
    _suppressOutbox = true;
    try {
      return await block();
    } finally {
      _suppressOutbox = previous;
    }
  }

  static int _deviceIdCounter = 0;
  static String _newDeviceId() {
    final ms = DateTime.now().millisecondsSinceEpoch.toString().padLeft(13, '0');
    final suffix = (_deviceIdCounter++).toString().padLeft(4, '0');
    // Shape a UUID-like identifier that matches the server's uuid validator.
    final part = '${ms.substring(0, 8)}-${ms.substring(8, 12)}-4${ms.substring(12).padRight(3, '0').substring(0, 3)}-a$suffix';
    return '$part-${DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(12, '0').substring(0, 12)}';
  }

  Future<void> _recordOutbox({
    required String payloadType,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? integrity,
  }) async {
    // Reducer-triggered mutations must not re-emit, or the server would
    // ping-pong the same event between every pair of devices. The flag
    // is scoped via applyingRemote() below.
    if (_suppressOutbox) return;
    final box = outbox;
    final key = vault.activeKey;
    if (box == null || key == null) return;
    try {
      await box.record(
        payloadType: payloadType,
        payload: payload,
        integrity: integrity,
        vaultKey: key,
        deviceId: deviceId,
      );
    } catch (_) {
      // Record-on-mutation failures do not break the local write; the next
      // sync run will retry when the vault is available.
    }
    // Mirror the write to the REST resource layer (if wired). The
    // publisher is fire-and-forget: the outbox remains the source of
    // truth for cross-device replay, this is a best-effort push so a
    // web client can see the row before the next pull cycle.
    final publisher = resourcePublisher;
    if (publisher != null) {
      unawaited(publisher.publish(
        kind: payloadType,
        payload: payload,
        integrity: integrity,
        vaultKey: key,
        deviceId: deviceId,
      ));
    }
  }

  PortfolioState _state = const PortfolioState();
  PortfolioState get state => _state;
  WealthTotals get totals => computeTotals(_state.assets, _state.liabilities);
  String? loadError;
  bool isDemo = false;
  bool _loaded = false;
  bool get isLoaded => _loaded;
  bool get isUnlocked => vault.isUnlocked;
  DateTime? _lastSavedAt;
  DateTime? get lastSavedAt => _lastSavedAt;

  Future<void> load() async {
    await vault.load();
    try {
      final raw = await vault.readPayload();
      if (raw != null) {
        _state = PortfolioState.fromJson(jsonDecode(raw) as Json);
      }
      loadError = null;
    } on StateError {
      // Vault is locked; wait for an unlock call.
    } catch (e) {
      loadError = 'Saved local data could not be loaded. Nothing was deleted.';
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> unlock(String passphrase) async {
    final raw = await vault.unlock(passphrase);
    try {
      _state = PortfolioState.fromJson(jsonDecode(raw) as Json);
      loadError = null;
    } catch (_) {
      loadError = 'Vault unlocked, but contents could not be parsed.';
    }
    notifyListeners();
  }

  Future<void> unlockWithBiometrics() async {
    final raw = await vault.unlockWithBiometricStash();
    _state = PortfolioState.fromJson(jsonDecode(raw) as Json);
    notifyListeners();
  }

  Future<void> enablePassphrase(String passphrase) async {
    await vault.enablePassphrase(passphrase, currentCleartext: _state.encode());
  }

  Future<void> disablePassphrase() async {
    await vault.disablePassphrase(currentCleartext: _state.encode());
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      await vault.writePayload(_state.encode());
      _lastSavedAt = DateTime.now();
    } catch (_) {
      loadError = 'The last change may not be saved. Storage is unavailable.';
      notifyListeners();
    }
  }

  /// Destructive: clear every local portfolio record and tear down the vault
  /// (encryption off, metadata removed). Used by the Settings → Reset flow.
  /// Attachments on disk are also removed on a best-effort basis — missing
  /// files are ignored so a partial failure cannot corrupt the store.
  Future<void> resetLocal() async {
    for (final doc in _state.documents) {
      final ref = doc.attachment;
      if (ref == null) continue;
      try {
        await attachments.delete(ref);
      } catch (_) {
        // Attachment file may already be gone or unreadable; move on.
      }
    }
    try {
      await vault.disablePassphrase(currentCleartext: '');
    } on StateError {
      // Vault had no passphrase; nothing to tear down.
    }
    _state = const PortfolioState();
    isDemo = false;
    _lastSavedAt = null;
    await _save();
  }

  Future<void> setOwner(String name) async {
    _state = _replace(ownerName: name.trim(), onboardingDone: true);
    await _save();
  }

  Future<void> upsertAsset(WealthAsset asset) async {
    if (asset.name.trim().isEmpty ||
        asset.valueUgx < 0 ||
        asset.ownershipBps < 0 ||
        asset.ownershipBps > 10000) {
      throw ArgumentError('Invalid asset name, value or ownership share');
    }
    final list = [..._state.assets];
    final i = list.indexWhere((x) => x.id == asset.id);
    if (i < 0) {
      list.add(asset);
    } else {
      list[i] = asset;
    }
    var history = _state.valuations;
    if (!asset.archived &&
        (i < 0 ||
            list[i].valueUgx != _state.assets[i].valueUgx ||
            list[i].valuedAt != _state.assets[i].valuedAt)) {
      history = [
        ...history,
        ValuationRecord(
            id: makeId(),
            assetId: asset.id,
            fullValueUgx: asset.valueUgx,
            asOf: asset.valuedAt,
            source: asset.status.name)
      ];
    }
    // Grow the known-institutions set so a subsequent form sees this
    // name as a pickable option.
    Set<String>? nextInstitutions;
    final trimmed = asset.institution.trim();
    if (trimmed.isNotEmpty &&
        !_state.knownInstitutions.contains(trimmed)) {
      nextInstitutions = {..._state.knownInstitutions, trimmed};
    }
    _state = _replace(
        assets: list,
        valuations: history,
        knownInstitutions: nextInstitutions);
    await _save();
    await _recordOutbox(
      payloadType: 'asset',
      payload: asset.toJson(),
      integrity: {'ownership_bps': asset.ownershipBps},
    );
  }

  Future<void> archiveAsset(WealthAsset asset) async =>
      upsertAsset(asset.copyWith(archived: true));
  Future<void> restoreAsset(WealthAsset asset) async =>
      upsertAsset(asset.copyWith(archived: false));

  Future<void> upsertLiability(Liability liability) async {
    if (liability.name.trim().isEmpty || liability.outstandingUgx < 0) {
      throw ArgumentError('Invalid debt');
    }
    final list = [..._state.liabilities];
    final i = list.indexWhere((x) => x.id == liability.id);
    if (i < 0) {
      list.add(liability);
    } else {
      list[i] = liability;
    }
    Set<String>? nextInstitutions;
    final trimmed = liability.lender.trim();
    if (trimmed.isNotEmpty &&
        !_state.knownInstitutions.contains(trimmed)) {
      nextInstitutions = {..._state.knownInstitutions, trimmed};
    }
    _state = _replace(
        liabilities: list, knownInstitutions: nextInstitutions);
    await _save();
    await _recordOutbox(payloadType: 'liability', payload: liability.toJson());
  }

  Future<void> archiveLiability(Liability debt) async =>
      upsertLiability(debt.copyWith(archived: true));
  Future<void> restoreLiability(Liability debt) async =>
      upsertLiability(debt.copyWith(archived: false));

  Future<void> postEvent(LedgerEvent event) async {
    if (event.amountUgx < 0 || event.description.trim().isEmpty) {
      throw ArgumentError('Invalid transaction');
    }
    if (_state.events.any((x) => x.id == event.id)) return;
    if (event.kind == EventKind.reversal &&
        (!_state.events.any(
                (x) => x.id == event.reversalOf && x.kind != EventKind.reversal) ||
            _state.events.any((x) => x.reversalOf == event.reversalOf))) {
      throw ArgumentError('Invalid or duplicate reversal');
    }
    _state = _replace(events: [..._state.events, event]);
    await _save();
    await _recordOutbox(
      payloadType: 'ledger_event',
      payload: event.toJson(),
      integrity: {'amount_ugx': event.amountUgx},
    );
  }

  Future<void> reverseEvent(LedgerEvent event) async => postEvent(LedgerEvent(
      id: makeId(),
      description: 'Reversal: ${event.description}',
      kind: EventKind.reversal,
      amountUgx: event.amountUgx,
      occurredAt: DateTime.now(),
      assetId: event.assetId,
      reversalOf: event.id));

  Future<void> addGoal(WealthGoal goal) async {
    _state = _replace(goals: [..._state.goals, goal]);
    await _save();
    await _recordOutbox(payloadType: 'goal', payload: goal.toJson());
  }

  Future<void> upsertGoal(WealthGoal goal) async {
    if (goal.name.trim().isEmpty || goal.targetUgx <= 0 || goal.savedUgx < 0) {
      throw ArgumentError('Invalid goal');
    }
    final goals = [..._state.goals];
    final i = goals.indexWhere((x) => x.id == goal.id);
    if (i < 0) {
      goals.add(goal);
    } else {
      goals[i] = goal;
    }
    _state = _replace(goals: goals);
    await _save();
    await _recordOutbox(payloadType: 'goal', payload: goal.toJson());
  }

  Future<void> deleteGoal(String id) async {
    _state = _replace(goals: _state.goals.where((x) => x.id != id).toList());
    await _save();
    await _recordOutbox(
        payloadType: 'goal_delete', payload: {'id': id});
  }

  /// Append-only contact create. Preserved for back-compat with earlier
  /// call sites; new flows should prefer [upsertContact] so an existing
  /// row with the same id can be edited in place.
  Future<void> addContact(LegacyContact contact) async =>
      upsertContact(contact);

  Future<void> upsertContact(LegacyContact contact) async {
    if (contact.name.trim().isEmpty || contact.relationship.trim().isEmpty) {
      throw ArgumentError('Contact needs a name and relationship');
    }
    final contacts = [..._state.contacts];
    final i = contacts.indexWhere((x) => x.id == contact.id);
    if (i < 0) {
      contacts.add(contact);
    } else {
      contacts[i] = contact;
    }
    _state = _replace(contacts: contacts);
    await _save();
    await _recordOutbox(
        payloadType: 'trusted_contact', payload: contact.toJson());
  }

  Future<void> removeContact(String id) async {
    _state = _replace(
        contacts: _state.contacts.where((x) => x.id != id).toList());
    await _save();
    await _recordOutbox(
        payloadType: 'trusted_contact_delete', payload: {'id': id});
  }

  Future<void> addReminder(ReminderRecord reminder) async {
    _state = _replace(reminders: [..._state.reminders, reminder]);
    await _save();
    await _recordOutbox(payloadType: 'reminder', payload: reminder.toJson());
  }

  Future<void> removeReminder(String id) async {
    _state = _replace(
        reminders: _state.reminders.where((x) => x.id != id).toList());
    await _save();
    await _recordOutbox(
        payloadType: 'reminder_delete', payload: {'id': id});
  }

  Future<void> toggleReminder(String id) async {
    _state = _replace(
        reminders:
            _state.reminders.map((r) => r.id == id ? r.toggle() : r).toList());
    await _save();
    final toggled = _state.reminders.firstWhere(
      (r) => r.id == id,
      orElse: () => ReminderRecord(id: id, title: '', dueAt: DateTime.now()),
    );
    if (toggled.title.isNotEmpty) {
      await _recordOutbox(payloadType: 'reminder', payload: toggled.toJson());
    }
  }

  Future<void> upsertDocument(DocumentRecord document) async {
    if (document.title.trim().isEmpty || document.category.trim().isEmpty) {
      throw ArgumentError('Document title and category are required');
    }
    if (document.expiresAt != null &&
        document.issuedAt != null &&
        document.expiresAt!.isBefore(document.issuedAt!)) {
      throw ArgumentError('Expiry must follow issue date');
    }
    final docs = [..._state.documents];
    final i = docs.indexWhere((x) => x.id == document.id);
    if (i < 0) {
      docs.add(document);
    } else {
      docs[i] = document;
    }
    _state = _replace(documents: docs);
    await _save();
    await _recordOutbox(
      payloadType: 'document_record',
      payload: document.toJson(),
    );
  }

  Future<void> archiveDocument(DocumentRecord document) async =>
      upsertDocument(document.copyWith(archived: true));
  Future<void> restoreDocument(DocumentRecord document) async =>
      upsertDocument(document.copyWith(archived: false));

  /// Maximum attachment size enforced client-side. Larger files are rejected
  /// before they ever touch disk so we never half-write an encrypted blob.
  /// The current cap mirrors the online-service plan's free-tier soft limit.
  static const maxAttachmentBytes = 25 * 1024 * 1024;

  /// Common MIME prefixes we let through. Anything else is rejected so a
  /// stray `.exe` from a filesystem picker cannot be smuggled into the vault
  /// disguised as a document.
  static const allowedMimePrefixes = {
    'application/pdf',
    'image/',
    'text/',
    'application/json',
    'application/zip',
    'application/vnd.oasis.opendocument',
    'application/vnd.openxmlformats-officedocument',
    'application/msword',
    'application/vnd.ms-excel',
    'application/octet-stream',
  };

  /// Attaches raw [bytes] to [document], encrypts them under the vault key and
  /// writes the AttachmentRef back into the record. Requires an unlocked vault
  /// when a passphrase is set; otherwise falls back to an unprotected on-disk
  /// write but with the same encrypted-at-rest file format (random fingerprint
  /// key) so file bytes are never readable to other apps.
  Future<DocumentRecord> attachFile(DocumentRecord document, List<int> bytes,
      {required String filename, required String mimeType}) async {
    if (bytes.isEmpty) {
      throw ArgumentError('Attachment is empty');
    }
    if (bytes.length > maxAttachmentBytes) {
      throw ArgumentError(
          'Attachment exceeds the ${maxAttachmentBytes ~/ (1024 * 1024)} MB limit');
    }
    final acceptable = allowedMimePrefixes
        .any((prefix) => mimeType == prefix || mimeType.startsWith(prefix));
    if (!acceptable) {
      throw ArgumentError('Attachment type "$mimeType" is not allowed');
    }
    final key = vault.activeKey;
    final ref = await attachments.write(
        documentId: document.id,
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
        key: key);
    AttachmentRef effective = ref;
    final syncer = attachmentSyncer;
    if (syncer != null) {
      try {
        final ciphertext = await attachments.readCiphertext(ref);
        final sha = _hexToBytes(ref.sha256Hex);
        final serverId = await syncer.uploadCiphertext(
          bytes: ciphertext,
          sha256: sha,
          mimeType: mimeType,
        );
        effective = ref.withServerId(serverId);
      } catch (_) {
        // Upload failure is tolerated: the local attachment stays usable.
        // The next sync or a manual retry will carry it to the server.
      }
    }
    final updated = document.copyWith(attachment: effective);
    await upsertDocument(updated);
    return updated;
  }

  /// Sweeps the document set for attachments that have no serverId —
  /// typically because an earlier upload failed (offline, flaky
  /// network, 5xx) — and retries the three-phase presign dance.
  /// Returns the number of attachments successfully uploaded. Safe
  /// to call repeatedly; already-synced attachments are skipped.
  Future<int> retryPendingAttachments() async {
    final syncer = attachmentSyncer;
    if (syncer == null) return 0;
    var retried = 0;
    for (final doc in [..._state.documents]) {
      final ref = doc.attachment;
      if (ref == null || ref.serverId != null) continue;
      try {
        final ciphertext = await attachments.readCiphertext(ref);
        final sha = _hexToBytes(ref.sha256Hex);
        final serverId = await syncer.uploadCiphertext(
          bytes: ciphertext,
          sha256: sha,
          mimeType: ref.mimeType,
        );
        final updated = doc.copyWith(attachment: ref.withServerId(serverId));
        await upsertDocument(updated);
        retried += 1;
      } catch (_) {
        // Leave the doc untouched; the next sweep tries again.
      }
    }
    return retried;
  }

  Future<void> removeAttachment(DocumentRecord document) async {
    final ref = document.attachment;
    if (ref == null) return;
    await attachments.delete(ref);
    final syncer = attachmentSyncer;
    final serverId = ref.serverId;
    if (syncer != null && serverId != null) {
      try {
        await syncer.deleteRemote(serverId);
      } catch (_) {
        // Best-effort; the server's unused attachment will be swept by
        // the operator cleanup job.
      }
    }
    await upsertDocument(document.copyWith(clearAttachment: true));
  }

  static List<int> _hexToBytes(String hex) {
    final out = <int>[];
    for (var i = 0; i + 1 < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  Future<void> upsertBeneficiary(BeneficiaryRecord person) async {
    if (person.name.trim().isEmpty ||
        person.relationship.trim().isEmpty ||
        person.intendedShareBps < 0 ||
        person.intendedShareBps > 10000) {
      throw ArgumentError('Invalid beneficiary planning note');
    }
    final entries = [..._state.beneficiaries];
    final i = entries.indexWhere((x) => x.id == person.id);
    if (i < 0) {
      entries.add(person);
    } else {
      entries[i] = person;
    }
    final total = entries.fold<int>(0, (sum, x) => sum + x.intendedShareBps);
    if (total > 10000) {
      throw ArgumentError('Combined planned allocation exceeds 100%');
    }
    _state = _replace(beneficiaries: entries);
    await _save();
    await _recordOutbox(
      payloadType: 'beneficiary_batch',
      payload: {'beneficiaries': entries.map((e) => e.toJson()).toList()},
      integrity: {'combined_bps': total},
    );
  }

  Future<void> deleteBeneficiary(String id) async {
    final remaining =
        _state.beneficiaries.where((x) => x.id != id).toList();
    _state = _replace(beneficiaries: remaining);
    await _save();
    // Beneficiaries sync as a full batch so a second device sees the
    // deletion as the absence of an id — not emitting here would leave
    // the deleted person alive on every other install.
    final total = remaining.fold<int>(0, (sum, x) => sum + x.intendedShareBps);
    await _recordOutbox(
      payloadType: 'beneficiary_batch',
      payload: {'beneficiaries': remaining.map((e) => e.toJson()).toList()},
      integrity: {'combined_bps': total},
    );
  }

  Future<void> recordValuation(
      String assetId, int fullValueUgx, DateTime asOf, String source,
      {String notes = '', String? id}) async {
    if (fullValueUgx < 0 || source.trim().isEmpty) {
      throw ArgumentError('Invalid valuation');
    }
    final index =
        _state.assets.indexWhere((x) => x.id == assetId && !x.archived);
    if (index < 0) throw ArgumentError('Asset not found');
    final asset = _state.assets[index];
    if (DateTime(asOf.year, asOf.month, asOf.day).isBefore(
        DateTime(asset.valuedAt.year, asset.valuedAt.month,
            asset.valuedAt.day))) {
      throw ArgumentError(
          'Use a valuation date on or after the current valuation');
    }
    final updated = [..._state.assets];
    updated[index] = asset.copyWith(
        valueUgx: fullValueUgx, valuedAt: asOf, status: RecordStatus.userEntered);
    // The id is passed through from the sync reducer so a cross-device
    // replay keeps the same primary key; otherwise mint a fresh one so
    // the local write stays stable.
    final record = ValuationRecord(
        id: id ?? makeId(),
        assetId: assetId,
        fullValueUgx: fullValueUgx,
        asOf: asOf,
        source: source.trim(),
        notes: notes.trim());
    final history = [..._state.valuations, record];
    _state = _replace(assets: updated, valuations: history);
    await _save();
    // Push both the asset mutation (new current valuedAt/valueUgx) and
    // the valuation history row. Without this, a peer device's hydrate
    // misses every revaluation.
    await _recordOutbox(
        payloadType: 'asset', payload: updated[index].toJson(), integrity: {
      'ownership_bps': updated[index].ownershipBps,
    });
    await _recordOutbox(payloadType: 'valuation', payload: record.toJson());
  }

  Future<void> updateNotificationOptions(NotificationOptions options) async {
    _state = _replace(notificationOptions: options);
    await _save();
    // Notification preferences are singleton per account; publish as
    // kind `notification_options` with id "all". A peer device's
    // hydrate replays the full options map.
    await _recordOutbox(
      payloadType: 'notification_options',
      payload: {'id': 'all', ...options.toJson()},
    );
  }

  /// Composite resource id for an FxRate. The REST layer wants a single
  /// string key per row; we synthesise it deterministically from the
  /// currency code plus the ISO as-of date so a conflict only happens
  /// when both devices truly wrote the same cell.
  static String _fxId(String currency, DateTime asOf) =>
      '${currency.toUpperCase()}:${asOf.toUtc().toIso8601String()}';

  Future<void> upsertFxRate(FxRate rate) async {
    if (rate.currency.trim().length != 3 || rate.ugxPerUnit <= 0) {
      throw ArgumentError('FX rate must have a 3-letter currency and positive quote');
    }
    final rates = [..._state.fxRates];
    final i = rates.indexWhere((r) =>
        r.currency == rate.currency && r.asOf.isAtSameMomentAs(rate.asOf));
    if (i < 0) {
      rates.add(rate);
    } else {
      rates[i] = rate;
    }
    _state = _replace(fxRates: rates);
    await _save();
    await _recordOutbox(
      payloadType: 'fx_rate',
      payload: {
        ...rate.toJson(),
        'id': _fxId(rate.currency, rate.asOf),
      },
      integrity: {'ugx_per_unit': rate.ugxPerUnit},
    );
  }

  Future<void> removeFxRate(String currency, DateTime asOf) async {
    _state = _replace(
        fxRates: _state.fxRates
            .where((r) => r.currency != currency || !r.asOf.isAtSameMomentAs(asOf))
            .toList());
    await _save();
    await _recordOutbox(
      payloadType: 'fx_rate_delete',
      payload: {'id': _fxId(currency, asOf)},
    );
  }

  Future<void> upsertSchedule(ScheduledContribution schedule) async {
    if (schedule.name.trim().isEmpty || schedule.amountUgx <= 0) {
      throw ArgumentError('Schedule needs a name and positive amount');
    }
    final list = [..._state.scheduled];
    final i = list.indexWhere((s) => s.id == schedule.id);
    if (i < 0) {
      list.add(schedule);
    } else {
      list[i] = schedule;
    }
    _state = _replace(scheduled: list);
    await _save();
    await _recordOutbox(payloadType: 'schedule', payload: schedule.toJson());
  }

  Future<void> pauseSchedule(String id, {required bool active}) async {
    final updated = _state.scheduled
        .map((s) => s.id == id ? s.withActive(active) : s)
        .toList();
    _state = _replace(scheduled: updated);
    await _save();
    for (final s in updated) {
      if (s.id == id) {
        await _recordOutbox(payloadType: 'schedule', payload: s.toJson());
        return;
      }
    }
  }

  Future<void> deleteSchedule(String id) async {
    _state = _replace(
        scheduled: _state.scheduled.where((s) => s.id != id).toList());
    await _save();
    await _recordOutbox(payloadType: 'schedule_delete', payload: {'id': id});
  }

  /// Posts a ledger event for the scheduled contribution and advances its
  /// next-fire date. The entry remains a regular, reversible LedgerEvent.
  Future<void> fireSchedule(ScheduledContribution schedule,
      {DateTime? at}) async {
    final when = at ?? DateTime.now();
    await postEvent(LedgerEvent(
        id: makeId(),
        description: 'Scheduled: ${schedule.name}',
        kind: EventKind.contribution,
        amountUgx: schedule.amountUgx,
        assetId: schedule.assetId,
        occurredAt: when));
    final advanced = schedule.advance(firedAt: when);
    await upsertSchedule(advanced);
  }

  /// Replaces the full target-weight map in one shot. Used by the sync
  /// reducer when a peer device publishes a new allocation plan.
  Future<void> replaceTargetWeights(Map<String, int> weights) async {
    final sanitised = <String, int>{};
    weights.forEach((k, v) {
      if (v > 0 && v <= 10000) sanitised[k] = v;
    });
    _state = _replace(targetWeightsBps: sanitised);
    await _save();
  }

  Future<void> setTargetWeight(String assetId, int bps) async {
    if (bps < 0 || bps > 10000) {
      throw ArgumentError('Target weight must be between 0 and 100%');
    }
    final weights = Map<String, int>.from(_state.targetWeightsBps);
    if (bps == 0) {
      weights.remove(assetId);
    } else {
      weights[assetId] = bps;
    }
    _state = _replace(targetWeightsBps: weights);
    await _save();
    // Sync the whole map as one row — target weights only make sense as
    // a coherent allocation, mirroring the beneficiary_batch shape.
    final combined = weights.values.fold<int>(0, (acc, v) => acc + v);
    await _recordOutbox(
      payloadType: 'target_weights',
      payload: {'id': 'all', 'weights': weights},
      integrity: {'combined_bps': combined},
    );
  }

  /// Portable JSON export is intentionally user-initiated and clearly warns
  /// that exported content is unencrypted. Never export passwords or tokens.
  String exportJson() => const JsonEncoder.withIndent('  ').convert(_state.toJson());

  Future<void> importJson(String raw) async {
    final parsed = PortfolioState.fromJson(jsonDecode(raw) as Json);
    if (parsed.assets.any((x) =>
            x.valueUgx < 0 || x.ownershipBps < 0 || x.ownershipBps > 10000) ||
        parsed.liabilities.any((x) => x.outstandingUgx < 0) ||
        parsed.events.any((x) => x.amountUgx < 0) ||
        parsed.valuations.any((x) => x.fullValueUgx < 0) ||
        parsed.beneficiaries
                .fold<int>(0, (n, x) => n + x.intendedShareBps) >
            10000) {
      throw const FormatException('Negative or invalid financial amount');
    }
    _state = parsed;
    await _save();
  }

  /// Explicit test fixture only; never silently generate fabricated balances.
  Future<void> loadDemo() async {
    if (!_loaded) await vault.load();
    _loaded = true;
    final now = DateTime.now();
    isDemo = true;
    _state = PortfolioState(ownerName: 'Demo portfolio', onboardingDone: true, assets: [
      WealthAsset(id: 'investment-unit-trust', name: 'Unit Trust', kind: AssetKind.investment,
          category: 'Unit trust', valueUgx: 70000000, costUgx: 65000000,
          valuedAt: now, status: RecordStatus.estimated),
      WealthAsset(id: 'investment-securities', name: 'Government Securities',
          kind: AssetKind.investment, category: 'Treasury bonds', valueUgx: 35000000,
          valuedAt: now),
      WealthAsset(id: 'savings-bank', name: 'Bank and NSSF Savings',
          kind: AssetKind.savings, valueUgx: 45000000, valuedAt: now),
      WealthAsset(id: 'property-rental', name: 'Rental Property',
          kind: AssetKind.property, location: 'Uganda', valueUgx: 300000000,
          ownershipBps: 8000, valuedAt: now, status: RecordStatus.estimated),
    ], liabilities: [
      Liability(id: 'mortgage', name: 'Property Mortgage',
          outstandingUgx: 60000000, asOf: now, propertyId: 'property-rental'),
      Liability(id: 'sacco-loan', name: 'SACCO Loan',
          outstandingUgx: 10000000, asOf: now)
    ]);
    await _save();
  }

  PortfolioState _replace({
    String? ownerName,
    bool? onboardingDone,
    List<WealthAsset>? assets,
    List<Liability>? liabilities,
    List<LedgerEvent>? events,
    List<WealthGoal>? goals,
    List<LegacyContact>? contacts,
    List<ReminderRecord>? reminders,
    List<DocumentRecord>? documents,
    List<BeneficiaryRecord>? beneficiaries,
    List<ValuationRecord>? valuations,
    NotificationOptions? notificationOptions,
    List<FxRate>? fxRates,
    List<ScheduledContribution>? scheduled,
    Map<String, int>? targetWeightsBps,
    Set<String>? dismissedAlertKeys,
    Set<String>? knownInstitutions,
  }) =>
      PortfolioState(
          ownerName: ownerName ?? _state.ownerName,
          onboardingDone: onboardingDone ?? _state.onboardingDone,
          assets: assets ?? _state.assets,
          liabilities: liabilities ?? _state.liabilities,
          events: events ?? _state.events,
          goals: goals ?? _state.goals,
          contacts: contacts ?? _state.contacts,
          reminders: reminders ?? _state.reminders,
          documents: documents ?? _state.documents,
          beneficiaries: beneficiaries ?? _state.beneficiaries,
          valuations: valuations ?? _state.valuations,
          notificationOptions:
              notificationOptions ?? _state.notificationOptions,
          fxRates: fxRates ?? _state.fxRates,
          scheduled: scheduled ?? _state.scheduled,
          targetWeightsBps:
              targetWeightsBps ?? _state.targetWeightsBps,
          dismissedAlertKeys:
              dismissedAlertKeys ?? _state.dismissedAlertKeys,
          knownInstitutions:
              knownInstitutions ?? _state.knownInstitutions);

  /// Hides a single alert from the notification centre until the underlying
  /// record moves to a later occurrence. Persists through sync so a
  /// dismissal on one device sticks on the next.
  Future<void> dismissAlert(String key) async {
    if (_state.dismissedAlertKeys.contains(key)) return;
    _state = _replace(
        dismissedAlertKeys: {..._state.dismissedAlertKeys, key});
    await _save();
    await _recordOutbox(
        payloadType: 'alert_dismissal', payload: {'key': key});
  }

  /// Clears every suppression. Exposed on the notification-preferences
  /// screen so a user who dismissed a reminder too eagerly can get it back.
  Future<void> clearDismissedAlerts() async {
    if (_state.dismissedAlertKeys.isEmpty) return;
    _state = _replace(dismissedAlertKeys: const <String>{});
    await _save();
    await _recordOutbox(
        payloadType: 'alert_dismissal_clear', payload: const <String, dynamic>{});
  }
}
