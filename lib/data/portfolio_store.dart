import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../domain/models.dart';
import '../domain/finance.dart';
import 'vault.dart';
import 'attachment_store.dart';

/// Local, offline-first repository. In 0.3 this wrote cleartext to
/// SharedPreferences; 0.4 can transparently keep the same payload on disk, or
/// — when a passphrase is set — persist an AES-GCM envelope and mediate all
/// reads and writes through [Vault]. Nothing is pushed to a server.
class PortfolioStore extends ChangeNotifier {
  PortfolioStore({Vault? vault, AttachmentStore? attachments})
      : vault = vault ?? Vault(),
        attachments = attachments ?? AttachmentStore();

  final Vault vault;
  final AttachmentStore attachments;

  PortfolioState _state = const PortfolioState();
  PortfolioState get state => _state;
  WealthTotals get totals => computeTotals(_state.assets, _state.liabilities);
  String? loadError;
  bool isDemo = false;
  bool get isUnlocked => vault.isUnlocked;

  Future<void> load() async {
    await vault.load();
    vault.addListener(notifyListeners);
    try {
      final raw = await vault.readPayload();
      if (raw != null) {
        _state = PortfolioState.fromJson(jsonDecode(raw) as Json);
      }
    } on StateError {
      // Vault is locked; wait for an unlock call.
    } catch (e) {
      loadError = 'Saved local data could not be loaded. Nothing was deleted.';
    }
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
    } catch (_) {
      loadError = 'The last change may not be saved. Storage is unavailable.';
      notifyListeners();
    }
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
    _state = _replace(assets: list, valuations: history);
    await _save();
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
    _state = _replace(liabilities: list);
    await _save();
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
  }

  Future<void> deleteGoal(String id) async {
    _state = _replace(goals: _state.goals.where((x) => x.id != id).toList());
    await _save();
  }

  Future<void> addContact(LegacyContact contact) async {
    _state = _replace(contacts: [..._state.contacts, contact]);
    await _save();
  }

  Future<void> removeContact(String id) async {
    _state = _replace(
        contacts: _state.contacts.where((x) => x.id != id).toList());
    await _save();
  }

  Future<void> addReminder(ReminderRecord reminder) async {
    _state = _replace(reminders: [..._state.reminders, reminder]);
    await _save();
  }

  Future<void> removeReminder(String id) async {
    _state = _replace(
        reminders: _state.reminders.where((x) => x.id != id).toList());
    await _save();
  }

  Future<void> toggleReminder(String id) async {
    _state = _replace(
        reminders:
            _state.reminders.map((r) => r.id == id ? r.toggle() : r).toList());
    await _save();
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
  }

  Future<void> archiveDocument(DocumentRecord document) async =>
      upsertDocument(document.copyWith(archived: true));
  Future<void> restoreDocument(DocumentRecord document) async =>
      upsertDocument(document.copyWith(archived: false));

  /// Attaches raw [bytes] to [document], encrypts them under the vault key and
  /// writes the AttachmentRef back into the record. Requires an unlocked vault
  /// when a passphrase is set; otherwise falls back to an unprotected on-disk
  /// write but with the same encrypted-at-rest file format (random fingerprint
  /// key) so file bytes are never readable to other apps.
  Future<DocumentRecord> attachFile(DocumentRecord document, List<int> bytes,
      {required String filename, required String mimeType}) async {
    final key = vault.activeKey;
    final ref = await attachments.write(
        documentId: document.id,
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
        key: key);
    final updated = document.copyWith(attachment: ref);
    await upsertDocument(updated);
    return updated;
  }

  Future<void> removeAttachment(DocumentRecord document) async {
    final ref = document.attachment;
    if (ref == null) return;
    await attachments.delete(ref);
    await upsertDocument(document.copyWith(clearAttachment: true));
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
  }

  Future<void> deleteBeneficiary(String id) async {
    _state = _replace(
        beneficiaries:
            _state.beneficiaries.where((x) => x.id != id).toList());
    await _save();
  }

  Future<void> recordValuation(
      String assetId, int fullValueUgx, DateTime asOf, String source,
      {String notes = ''}) async {
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
    final history = [
      ..._state.valuations,
      ValuationRecord(
          id: makeId(),
          assetId: assetId,
          fullValueUgx: fullValueUgx,
          asOf: asOf,
          source: source.trim(),
          notes: notes.trim())
    ];
    _state = _replace(assets: updated, valuations: history);
    await _save();
  }

  Future<void> updateNotificationOptions(NotificationOptions options) async {
    _state = _replace(notificationOptions: options);
    await _save();
  }

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
  }

  Future<void> removeFxRate(String currency, DateTime asOf) async {
    _state = _replace(
        fxRates: _state.fxRates
            .where((r) => r.currency != currency || !r.asOf.isAtSameMomentAs(asOf))
            .toList());
    await _save();
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
  }

  Future<void> pauseSchedule(String id, {required bool active}) async {
    _state = _replace(
        scheduled: _state.scheduled
            .map((s) => s.id == id ? s.withActive(active) : s)
            .toList());
    await _save();
  }

  Future<void> deleteSchedule(String id) async {
    _state = _replace(
        scheduled: _state.scheduled.where((s) => s.id != id).toList());
    await _save();
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
              targetWeightsBps ?? _state.targetWeightsBps);
}
