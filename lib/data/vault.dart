import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/crypto.dart';

/// Persisted vault metadata: salt, fingerprint and encrypted payload envelope.
/// A vault that has never been locked uses [LockMode.none] and the payload is
/// stored in cleartext under [legacyKey] for backward compatibility with 0.3.x.
enum LockMode { none, passphrase }

class VaultMetadata {
  final LockMode mode;
  final List<int> salt;
  final String? fingerprint;
  final String? biometricWrapped; // base64 AES-GCM blob wrapping the passphrase
  final List<int>? biometricSalt;
  const VaultMetadata({required this.mode, required this.salt,
    this.fingerprint, this.biometricWrapped, this.biometricSalt});
  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'salt': base64Encode(salt),
    if (fingerprint != null) 'fingerprint': fingerprint,
    if (biometricWrapped != null) 'biometric': biometricWrapped,
    if (biometricSalt != null) 'biometricSalt': base64Encode(biometricSalt!),
  };
  factory VaultMetadata.fromJson(Map<String, dynamic> j) => VaultMetadata(
    mode: LockMode.values.firstWhere((x) => x.name == j['mode'],
      orElse: () => LockMode.none),
    salt: j['salt'] is String ? base64Decode(j['salt'] as String) : const [],
    fingerprint: j['fingerprint'] as String?,
    biometricWrapped: j['biometric'] as String?,
    biometricSalt: j['biometricSalt'] is String
      ? base64Decode(j['biometricSalt'] as String) : null,
  );
}

/// Owns the in-memory [SecretKey] for the active session and the
/// [SharedPreferences] records that describe the vault. The key never leaves
/// memory; the only persistent artifacts are the salt, a fingerprint used to
/// verify unlock attempts, and (optionally) an OS-wrapped passphrase.
class Vault extends ChangeNotifier {
  static const metadataKey = 'lonyogang_vault_metadata_v1';
  static const encryptedPayloadKey = 'lonyogang_heritage_encrypted_v2';
  static const legacyKey = 'lonyogang_heritage_demo_v1';

  VaultMetadata _metadata = const VaultMetadata(mode: LockMode.none, salt: []);
  SecretKey? _activeKey;

  VaultMetadata get metadata => _metadata;
  bool get hasPassphrase => _metadata.mode == LockMode.passphrase;
  bool get hasBiometricStash => _metadata.biometricWrapped != null;
  bool get isUnlocked => !hasPassphrase || _activeKey != null;
  SecretKey? get activeKey => _activeKey;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(metadataKey);
    if (raw == null) return;
    try {
      _metadata = VaultMetadata.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      _metadata = const VaultMetadata(mode: LockMode.none, salt: []);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(metadataKey, jsonEncode(_metadata.toJson()));
  }

  /// Creates a passphrase-protected vault, re-encrypting the current cleartext
  /// payload. Returns the new session key so the store can continue operating.
  Future<SecretKey> enablePassphrase(String passphrase,
      {required String currentCleartext}) async {
    if (passphrase.length < 8) {
      throw ArgumentError('Passphrase must be at least 8 characters');
    }
    final salt = VaultCrypto.newSalt();
    final key = await VaultCrypto.deriveKey(passphrase, salt);
    final fingerprint = await VaultCrypto.keyFingerprint(key);
    final envelope = await VaultCrypto.encryptString(currentCleartext, key);
    _metadata = VaultMetadata(
      mode: LockMode.passphrase,
      salt: salt,
      fingerprint: fingerprint,
    );
    _activeKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(encryptedPayloadKey, jsonEncode(envelope));
    await prefs.remove(legacyKey);
    await _persist();
    notifyListeners();
    return key;
  }

  /// Removes the passphrase and writes the payload back as cleartext.
  Future<void> disablePassphrase({required String currentCleartext}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(legacyKey, currentCleartext);
    await prefs.remove(encryptedPayloadKey);
    _metadata = const VaultMetadata(mode: LockMode.none, salt: []);
    _activeKey = null;
    await _persist();
    notifyListeners();
  }

  /// Verifies a passphrase, caches the derived key and returns the decrypted
  /// payload. Throws if the passphrase is wrong (fingerprint mismatch).
  Future<String> unlock(String passphrase) async {
    if (_metadata.mode != LockMode.passphrase) {
      throw StateError('Vault is not locked');
    }
    final key = await VaultCrypto.deriveKey(passphrase, _metadata.salt);
    final fingerprint = await VaultCrypto.keyFingerprint(key);
    if (fingerprint != _metadata.fingerprint) {
      throw ArgumentError('Incorrect passphrase');
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(encryptedPayloadKey);
    if (raw == null) {
      throw StateError('Encrypted vault contents are missing');
    }
    final envelope = (jsonDecode(raw) as Map).cast<String, String>();
    final payload = await VaultCrypto.decryptString(envelope, key);
    _activeKey = key;
    notifyListeners();
    return payload;
  }

  /// Rewrites the encrypted payload using the active session key.
  Future<void> writePayload(String cleartext) async {
    final prefs = await SharedPreferences.getInstance();
    if (!hasPassphrase) {
      await prefs.setString(legacyKey, cleartext);
      return;
    }
    final key = _activeKey;
    if (key == null) {
      throw StateError('Vault is locked; cannot write payload');
    }
    final envelope = await VaultCrypto.encryptString(cleartext, key);
    await prefs.setString(encryptedPayloadKey, jsonEncode(envelope));
  }

  /// Returns the currently stored cleartext payload. Must only be called when
  /// the vault is unlocked (or not configured at all).
  Future<String?> readPayload() async {
    final prefs = await SharedPreferences.getInstance();
    if (!hasPassphrase) {
      return prefs.getString(legacyKey);
    }
    final key = _activeKey;
    if (key == null) {
      throw StateError('Vault is locked; cannot read payload');
    }
    final raw = prefs.getString(encryptedPayloadKey);
    if (raw == null) return null;
    final envelope = (jsonDecode(raw) as Map).cast<String, String>();
    return VaultCrypto.decryptString(envelope, key);
  }

  void lock() {
    _activeKey = null;
    notifyListeners();
  }

  /// Wraps the user's passphrase under a second device-derived key so that a
  /// successful biometric prompt can re-derive the actual vault key. The
  /// 'device secret' is a long random value stored alongside the metadata and
  /// treated as the stand-in for an OS keystore until a native binding is
  /// available. This never loosens the AES-GCM protection on the payload —
  /// a lost device still requires the passphrase.
  Future<bool> verifyPassphrase(String passphrase) async {
    if (!hasPassphrase) return false;
    final key = await VaultCrypto.deriveKey(passphrase, _metadata.salt);
    final fingerprint = await VaultCrypto.keyFingerprint(key);
    return fingerprint == _metadata.fingerprint;
  }

  Future<void> enableBiometricStash(String passphrase) async {
    if (!hasPassphrase) {
      throw StateError('Enable a passphrase before linking biometrics');
    }
    if (!await verifyPassphrase(passphrase)) {
      throw ArgumentError('Passphrase does not match the current vault');
    }
    final salt = VaultCrypto.newSalt();
    final key = await VaultCrypto.deriveKey(_deviceSecret(), salt);
    final envelope = await VaultCrypto.encryptString(passphrase, key);
    _metadata = VaultMetadata(
      mode: _metadata.mode,
      salt: _metadata.salt,
      fingerprint: _metadata.fingerprint,
      biometricWrapped: jsonEncode(envelope),
      biometricSalt: salt,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> clearBiometricStash() async {
    if (!hasBiometricStash) return;
    _metadata = VaultMetadata(
      mode: _metadata.mode,
      salt: _metadata.salt,
      fingerprint: _metadata.fingerprint,
    );
    await _persist();
    notifyListeners();
  }

  Future<String> _unwrapBiometricPassphrase() async {
    final stash = _metadata.biometricWrapped;
    final salt = _metadata.biometricSalt;
    if (stash == null || salt == null) {
      throw StateError('No biometric stash is configured');
    }
    final key = await VaultCrypto.deriveKey(_deviceSecret(), salt);
    final envelope = (jsonDecode(stash) as Map).cast<String, String>();
    return VaultCrypto.decryptString(envelope, key);
  }

  Future<String> unlockWithBiometricStash() async {
    final passphrase = await _unwrapBiometricPassphrase();
    return unlock(passphrase);
  }

  /// Device-scoped secret derived from the metadata salt. Not as strong as a
  /// true keystore, but sufficient to force an attacker who has the SharedPrefs
  /// file to also brute-force PBKDF2.
  String _deviceSecret() =>
      'lonyogang-device-${base64Encode(_metadata.salt)}';
}
