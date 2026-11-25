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
  // Legacy wrapping was derived from public metadata, not an OS-protected key.
  bool get hasBiometricStash => false;
  bool get isUnlocked => !hasPassphrase || _activeKey != null;
  SecretKey? get activeKey => _activeKey;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(metadataKey);
    if (raw == null) {
      if(prefs.containsKey(encryptedPayloadKey))throw const FormatException('Encrypted vault metadata is missing');
      _metadata=const VaultMetadata(mode:LockMode.none,salt:[]);
      _activeKey=null;
      return;
    }
    try {
      final decoded=jsonDecode(raw) as Map<String,dynamic>;
      if(!LockMode.values.any((mode)=>mode.name==decoded['mode']))throw const FormatException('Invalid vault mode');
      final metadata=VaultMetadata.fromJson(decoded);
      if(metadata.mode==LockMode.passphrase&&(metadata.salt.isEmpty||metadata.fingerprint==null||!prefs.containsKey(encryptedPayloadKey)))throw const FormatException('Incomplete encrypted vault');
      if(metadata.mode==LockMode.none&&prefs.containsKey(encryptedPayloadKey))throw const FormatException('Conflicting vault storage');
      if(metadata.biometricWrapped!=null||metadata.biometricSalt!=null){
        final cleaned=VaultMetadata(mode:metadata.mode,salt:metadata.salt,fingerprint:metadata.fingerprint);
        if(!await prefs.setString(metadataKey,jsonEncode(cleaned.toJson())))throw StateError('Could not remove legacy biometric credential');
        _metadata=cleaned;
      }else{_metadata=metadata;}
      _activeKey=null;
    } catch (_) {
      throw const FormatException('Vault metadata could not be read');
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

  Future<bool> verifyPassphrase(String passphrase) async {
    if (!hasPassphrase) return false;
    final key = await VaultCrypto.deriveKey(passphrase, _metadata.salt);
    final fingerprint = await VaultCrypto.keyFingerprint(key);
    return fingerprint == _metadata.fingerprint;
  }

  /// Disabled until a native authentication-bound keystore implementation
  /// is available. Never persist the vault passphrase using public metadata.
  Future<void> enableBiometricStash(String passphrase) async {
    throw UnsupportedError('Secure biometric vault unlocking is unavailable');
  }

  Future<void> clearBiometricStash() async {
    if(_metadata.biometricWrapped==null&&_metadata.biometricSalt==null)return;
    _metadata=VaultMetadata(mode:_metadata.mode,salt:_metadata.salt,fingerprint:_metadata.fingerprint);
    await _persist();
    notifyListeners();
  }

  Future<String> unlockWithBiometricStash() async {
    throw UnsupportedError('Use your vault passphrase');
  }
}
