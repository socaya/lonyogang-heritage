import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../domain/models.dart';

/// An offline-only SQLCipher vault. No data is sent to a server.
/// The random SQLCipher key is stored in Android Keystore / iOS Keychain.
/// The local PIN gate is not a replacement for hardware-backed full-device protection.
class VaultRepository {
  VaultRepository({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  }) : _secure = storage ?? const FlutterSecureStorage(),
       _localAuth = localAuth ?? LocalAuthentication();

  final FlutterSecureStorage _secure;
  final LocalAuthentication _localAuth;
  Database? _db;

  bool get isOpen => _db?.isOpen ?? false;
  Database get db {
    final value = _db;
    if (value == null || !value.isOpen) {
      throw StateError('Unlock your personal vault first.');
    }
    return value;
  }

  Future<bool> hasVault() async => (await _secure.read(key: 'vault_secret')) != null;
  Future<bool> isBiometricEnabled() async =>
      (await _secure.read(key: 'biometric_enabled')) == 'yes';

  String _randomSecret(int length) {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(length, (_) => random.nextInt(256)));
  }

  /// PBKDF2-HMAC-SHA256; local unlock gate with 150000 iterations and random salt.
  String _derivePin(String pin, String saltBase64) {
    final salt = base64Url.decode(saltBase64);
    final password = utf8.encode(pin);
    final hmac = Hmac(sha256, password);
    final input = <int>[...salt, 0, 0, 0, 1];
    var block = hmac.convert(input).bytes;
    final output = List<int>.from(block);
    for (var round = 1; round < 150000; round++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < output.length; j++) {
        output[j] ^= block[j];
      }
    }
    return base64UrlEncode(output);
  }

  bool _constantTimeEqual(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<void> createVault({required String name, required String email,
      required String pin}) async {
    if (await hasVault()) throw StateError('A vault already exists on this device.');
    if (name.trim().length < 2) throw ArgumentError('Enter your full name.');
    if (pin.length < 6 || !RegExp(r'^\d+$').hasMatch(pin)) {
      throw ArgumentError('Use a 6-digit or longer numeric access PIN.');
    }
    final key = _randomSecret(32);
    final salt = _randomSecret(16);
    final verifier = _derivePin(pin, salt);
    await _secure.write(key: 'vault_secret', value: key);
    await _secure.write(key: 'pin_salt', value: salt);
    await _secure.write(key: 'pin_verifier', value: verifier);
    try {
      await _open(key);
      await db.insert('profile', {
        'id': 1, 'name': name.trim(), 'email': email.trim(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      await _db?.close();
      _db = null;
      await _secure.delete(key: 'vault_secret');
      await _secure.delete(key: 'pin_salt');
      await _secure.delete(key: 'pin_verifier');
      rethrow;
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    final salt = await _secure.read(key: 'pin_salt');
    final expected = await _secure.read(key: 'pin_verifier');
    if (salt == null || expected == null) return false;
    if (!_constantTimeEqual(_derivePin(pin, salt), expected)) return false;
    final key = await _secure.read(key: 'vault_secret');
    if (key == null) return false;
    await _open(key);
    return true;
  }

  Future<bool> canUseBiometrics() async {
    try {
      return (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometrics(bool enabled) async {
    if (!isOpen) throw StateError('Unlock vault first.');
    if (enabled && !await canUseBiometrics()) {
      throw StateError('Biometrics are unavailable or not enrolled on this device.');
    }
    await _secure.write(key: 'biometric_enabled', value: enabled ? 'yes' : 'no');
  }

  Future<bool> unlockWithBiometrics() async {
    if (!await isBiometricEnabled()) return false;
    try {
      if (!await _localAuth.authenticate(
          localizedReason: 'Unlock your private LonyoGang portfolio',
          biometricOnly: true)) {
        return false;
      }
      final key = await _secure.read(key: 'vault_secret');
      if (key == null) return false;
      await _open(key);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _open(String key) async {
    if (isOpen) return;
    final dir = await getApplicationSupportDirectory();
    final folder = Directory(p.join(dir.path, 'vault'));
    await folder.create(recursive: true);
    _db = await openDatabase(
      p.join(folder.path, 'heritage.db'),
      password: key,
      version: 1,
      onConfigure: (d) async { await d.execute('PRAGMA foreign_keys = ON'); },
      onCreate: _createSchema,
    );
  }

  Future<void> _createSchema(Database d, int version) async {
    await d.execute('''
CREATE TABLE profile (
  id INTEGER PRIMARY KEY CHECK(id=1), name TEXT NOT NULL, email TEXT NOT NULL,
  created_at TEXT NOT NULL
)''');
    await d.execute('''
CREATE TABLE assets (
  id TEXT PRIMARY KEY, kind TEXT NOT NULL, name TEXT NOT NULL,
  value_ugx INTEGER NOT NULL CHECK(value_ugx >= 0),
  cost_ugx INTEGER NOT NULL CHECK(cost_ugx >= 0),
  ownership_bps INTEGER NOT NULL CHECK(ownership_bps BETWEEN 1 AND 10000),
  valued_at TEXT NOT NULL, source TEXT NOT NULL, acquired_at TEXT NOT NULL,
  institution TEXT NOT NULL, location TEXT NOT NULL, notes TEXT NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0
)''');
    await d.execute('''
CREATE TABLE debts (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, lender TEXT NOT NULL,
  balance_ugx INTEGER NOT NULL CHECK(balance_ugx >= 0),
  linked_asset_id TEXT NOT NULL DEFAULT '', interest_bps INTEGER NOT NULL DEFAULT 0,
  due_at TEXT, notes TEXT NOT NULL
)''');
    await d.execute('''
CREATE TABLE entries (
  id TEXT PRIMARY KEY, kind TEXT NOT NULL, amount_ugx INTEGER NOT NULL CHECK(amount_ugx > 0),
  category TEXT NOT NULL, occurred_at TEXT NOT NULL,
  asset_id TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL
)''');
    await d.execute('''
CREATE TABLE valuations (
  id TEXT PRIMARY KEY, asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  value_ugx INTEGER NOT NULL, source TEXT NOT NULL,
  recorded_at TEXT NOT NULL, note TEXT NOT NULL
)''');
    await d.execute('''
CREATE TABLE beneficiaries (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, relationship TEXT NOT NULL,
  contact TEXT NOT NULL, notes TEXT NOT NULL, nomination_confirmed INTEGER NOT NULL DEFAULT 0
)''');
    await d.execute('''
CREATE TABLE reminders (
  id TEXT PRIMARY KEY, title TEXT NOT NULL, due_at TEXT NOT NULL,
  asset_id TEXT NOT NULL DEFAULT '', details TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0
)''');
    await d.execute('''
CREATE TABLE documents (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, mime TEXT NOT NULL,
  asset_id TEXT NOT NULL DEFAULT '', added_at TEXT NOT NULL,
  byte_count INTEGER NOT NULL, payload BLOB NOT NULL
)''');
    await d.execute('CREATE INDEX idx_entries_date ON entries(occurred_at DESC)');
    await d.execute('CREATE INDEX idx_valuations_asset_date ON valuations(asset_id, recorded_at DESC)');
    await d.execute('CREATE INDEX idx_reminders_due ON reminders(due_at)');
  }

  Future<WealthProfile> readProfile() async {
    final rows = await db.query('profile', limit: 1);
    if (rows.isEmpty) throw StateError('Vault profile is unavailable.');
    final m = rows.first;
    return WealthProfile(
      name: m['name'] as String, email: m['email'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  Future<void> updateProfile(String name, String email) async {
    if (name.trim().length < 2) throw ArgumentError('Name is required.');
    await db.update('profile', {'name': name.trim(), 'email': email.trim()}, where: 'id=?', whereArgs: [1]);
  }

  Future<List<WealthAsset>> assets() async => (await db.query('assets', orderBy: 'name COLLATE NOCASE'))
      .map(WealthAsset.fromDb).toList();
  Future<List<WealthDebt>> debts() async => (await db.query('debts', orderBy: 'name COLLATE NOCASE'))
      .map(WealthDebt.fromDb).toList();
  Future<List<WealthEntry>> entries() async => (await db.query('entries', orderBy: 'occurred_at DESC'))
      .map(WealthEntry.fromDb).toList();
  Future<List<WealthValuation>> valuations() async => (await db.query('valuations', orderBy: 'recorded_at DESC'))
      .map(WealthValuation.fromDb).toList();
  Future<List<WealthBeneficiary>> beneficiaries() async => (await db.query('beneficiaries', orderBy: 'name COLLATE NOCASE'))
      .map(WealthBeneficiary.fromDb).toList();
  Future<List<WealthReminder>> reminders() async => (await db.query('reminders', orderBy: 'due_at ASC'))
      .map(WealthReminder.fromDb).toList();
  Future<List<WealthDocument>> documents() async {
    // NEVER read the full BLOB payload just to render the documents list.
    return (await db.query('documents',
      columns: ['id','name','mime','asset_id','added_at','byte_count'],
      orderBy: 'added_at DESC')).map(WealthDocument.fromDb).toList();
  }

  Future<void> saveAsset(WealthAsset asset, {String valuationNote = ''}) async {
    if (asset.name.trim().isEmpty || asset.valueUgx < 0 || asset.costUgx < 0 ||
        asset.ownershipBps < 1 || asset.ownershipBps > 10000) {
      throw ArgumentError('Invalid asset name, amount or ownership.');
    }
    await db.transaction((txn) async {
      final old = await txn.query('assets', where: 'id=?', whereArgs: [asset.id]);
      await txn.insert('assets', asset.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
      if (old.isEmpty ||
          (old.first['value_ugx'] as int) != asset.valueUgx ||
          old.first['valued_at'] != asset.valuedAt.toUtc().toIso8601String()) {
        await txn.insert('valuations',
          WealthValuation(id: _randomSecret(16), assetId: asset.id,
            valueUgx: asset.valueUgx, source: asset.valuationSource,
            recordedAt: asset.valuedAt, note: valuationNote).toDb());
      }
    });
  }

  Future<void> archiveAsset(String id) async =>
      db.update('assets', {'archived': 1}, where: 'id=?', whereArgs: [id]);

  Future<void> deleteAsset(String id) async {
    final linked = await db.query('debts', where: 'linked_asset_id=?', whereArgs: [id]);
    if (linked.isNotEmpty) throw StateError('Unlink mortgages or debts before deleting this asset.');
    await db.delete('assets', where: 'id=?', whereArgs: [id]);
  }

  Future<void> saveDebt(WealthDebt debt) async {
    if (debt.name.trim().isEmpty || debt.balanceUgx < 0) throw ArgumentError('Invalid debt.');
    await db.insert('debts', debt.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<void> deleteDebt(String id) async => db.delete('debts', where: 'id=?', whereArgs: [id]);

  Future<void> saveEntry(WealthEntry entry) async {
    if (entry.amountUgx <= 0 || entry.category.trim().isEmpty) throw ArgumentError('Invalid entry.');
    await db.insert('entries', entry.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<void> deleteEntry(String id) async => db.delete('entries', where: 'id=?', whereArgs: [id]);

  Future<void> saveBeneficiary(WealthBeneficiary item) async {
    if (item.name.trim().isEmpty) throw ArgumentError('Name required.');
    await db.insert('beneficiaries', item.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<void> deleteBeneficiary(String id) async => db.delete('beneficiaries', where: 'id=?', whereArgs: [id]);

  Future<void> saveReminder(WealthReminder item) async {
    if (item.title.trim().isEmpty) throw ArgumentError('Reminder title required.');
    await db.insert('reminders', item.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<void> deleteReminder(String id) async => db.delete('reminders', where: 'id=?', whereArgs: [id]);

  Future<void> addDocument(WealthDocument item, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.lengthInBytes > 12 * 1024 * 1024) {
      throw ArgumentError('Choose a document under 12 MB.');
    }
    await db.insert('documents', {...item.toDb(), 'payload': bytes},
      conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<Uint8List> documentBytes(String id) async {
    final rows = await db.query('documents', columns: ['payload'],
      where: 'id=?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw StateError('Document not found.');
    return rows.first['payload'] as Uint8List;
  }
  Future<void> deleteDocument(String id) async =>
      db.delete('documents', where: 'id=?', whereArgs: [id]);

  Future<void> lock() async {
    await _db?.close();
    _db = null;
  }

  Future<void> eraseVault() async {
    await lock();
    final dir = await getApplicationSupportDirectory();
    final folder = Directory(p.join(dir.path, 'vault'));
    if (await folder.exists()) await folder.delete(recursive: true);
    for (final key in ['vault_secret','pin_salt','pin_verifier','biometric_enabled']) {
      await _secure.delete(key: key);
    }
  }
}
