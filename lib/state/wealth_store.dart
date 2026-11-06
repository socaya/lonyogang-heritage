import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/vault_repository.dart';
import '../domain/models.dart';
import '../domain/finance.dart';

/// One private portfolio owner, multiple records, no fabricated external data.
class WealthStore extends ChangeNotifier {
  WealthStore(this.repo);
  final VaultRepository repo;
  static const uuid = Uuid();

  bool loading = true;
  bool enrolled = false;
  bool unlocked = false;
  String? lastError;
  WealthProfile? profile;

  List<WealthAsset> assets = [];
  List<WealthDebt> debts = [];
  List<WealthEntry> entries = [];
  List<WealthValuation> valuations = [];
  List<WealthBeneficiary> beneficiaries = [];
  List<WealthReminder> reminders = [];
  List<WealthDocument> documents = [];

  List<WealthAsset> get activeAssets => assets.where((e) => !e.archived).toList();
  int get gross => grossOwnedAssets(activeAssets);
  int get outstanding => totalDebt(debts);
  int get worth => netWorth(activeAssets, debts);
  int get income => amountFor(entries, EntryType.income);
  int get expenses => amountFor(entries, EntryType.expense);
  Map<AssetKind, int> get allocationMap => allocation(activeAssets);

  Future<void> initialize() async {
    try {
      enrolled = await repo.hasVault();
      unlocked = false;
    } catch (e) {
      lastError = 'Unable to access the secure device vault: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> register({required String name, required String email,
      required String pin}) async {
    await repo.createVault(name: name, email: email, pin: pin);
    enrolled = true;
    unlocked = true;
    await refresh();
  }

  Future<bool> loginPin(String pin) async {
    final ok = await repo.unlockWithPin(pin);
    if (ok) {
      unlocked = true;
      await refresh();
    }
    return ok;
  }

  Future<bool> loginBiometric() async {
    final ok = await repo.unlockWithBiometrics();
    if (ok) { unlocked = true; await refresh(); }
    return ok;
  }

  Future<void> refresh() async {
    if (!repo.isOpen) return;
    profile = await repo.readProfile();
    assets = await repo.assets();
    debts = await repo.debts();
    entries = await repo.entries();
    valuations = await repo.valuations();
    beneficiaries = await repo.beneficiaries();
    reminders = await repo.reminders();
    documents = await repo.documents();
    notifyListeners();
  }

  Future<void> saveAsset(WealthAsset a, {String valuationNote = ''}) async {
    await repo.saveAsset(a, valuationNote: valuationNote);
    await refresh();
  }
  Future<void> archiveAsset(String id) async { await repo.archiveAsset(id); await refresh(); }
  Future<void> deleteAsset(String id) async { await repo.deleteAsset(id); await refresh(); }
  Future<void> saveDebt(WealthDebt d) async { await repo.saveDebt(d); await refresh(); }
  Future<void> deleteDebt(String id) async { await repo.deleteDebt(id); await refresh(); }
  Future<void> saveEntry(WealthEntry e) async { await repo.saveEntry(e); await refresh(); }
  Future<void> deleteEntry(String id) async { await repo.deleteEntry(id); await refresh(); }
  Future<void> saveBeneficiary(WealthBeneficiary b) async { await repo.saveBeneficiary(b); await refresh(); }
  Future<void> deleteBeneficiary(String id) async { await repo.deleteBeneficiary(id); await refresh(); }
  Future<void> saveReminder(WealthReminder r) async { await repo.saveReminder(r); await refresh(); }
  Future<void> deleteReminder(String id) async { await repo.deleteReminder(id); await refresh(); }
  Future<void> addDocument(WealthDocument d, Uint8List bytes) async {
    await repo.addDocument(d, bytes); await refresh();
  }
  Future<void> deleteDocument(String id) async { await repo.deleteDocument(id); await refresh(); }
  Future<void> updateProfile(String name, String email) async {
    await repo.updateProfile(name, email); await refresh();
  }

  Future<void> lock() async {
    await repo.lock();
    unlocked = false;
    profile = null;
    assets = []; debts = []; entries = []; valuations = [];
    beneficiaries = []; reminders = []; documents = [];
    notifyListeners();
  }

  Future<void> erase() async {
    await repo.eraseVault();
    unlocked = false; enrolled = false; profile = null;
    assets = []; debts = []; entries = []; valuations = [];
    beneficiaries = []; reminders = []; documents = [];
    notifyListeners();
  }
}
