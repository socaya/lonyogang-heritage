import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-GCM 256-bit authenticated encryption with a per-passphrase PBKDF2-HMAC-SHA-256
/// derived key. All byte buffers are returned as base64 strings so they can be
/// persisted alongside the existing JSON portfolio blob without a binary
/// migration step.
class VaultCrypto {
  VaultCrypto._();
  static const kdfIterations = 120000;
  static const keyLength = 32;
  static const nonceLength = 12;
  static const saltLength = 16;

  static final _aesGcm = AesGcm.with256bits();
  static final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: kdfIterations,
    bits: keyLength * 8,
  );
  static final _random = Random.secure();

  static Uint8List _randomBytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _random.nextInt(256);
    }
    return out;
  }

  /// Derives a 256-bit key from the passphrase and a stable per-vault salt.
  /// Callers MUST reuse the same salt they first generated for a vault.
  static Future<SecretKey> deriveKey(String passphrase, List<int> salt) async {
    if (passphrase.isEmpty) {
      throw ArgumentError('Passphrase cannot be empty');
    }
    return _pbkdf2.deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  static List<int> newSalt() => _randomBytes(saltLength);

  /// Encrypts [plaintext] with AES-GCM. Returns a map that can be JSON-encoded
  /// and later decoded with [decryptString]. The nonce is unique per call.
  static Future<Map<String, String>> encryptString(
      String plaintext, SecretKey key) async {
    final nonce = _randomBytes(nonceLength);
    final box = await _aesGcm.encrypt(utf8.encode(plaintext),
        secretKey: key, nonce: nonce);
    return {
      'n': base64Encode(box.nonce),
      'c': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
    };
  }

  static Future<String> decryptString(
      Map<String, String> envelope, SecretKey key) async {
    final box = SecretBox(base64Decode(envelope['c']!),
        nonce: base64Decode(envelope['n']!),
        mac: Mac(base64Decode(envelope['m']!)));
    final clear = await _aesGcm.decrypt(box, secretKey: key);
    return utf8.decode(clear);
  }

  /// Encrypts arbitrary bytes (used by the attachment store).
  static Future<Uint8List> encryptBytes(
      List<int> plaintext, SecretKey key) async {
    final nonce = _randomBytes(nonceLength);
    final box = await _aesGcm.encrypt(plaintext,
        secretKey: key, nonce: nonce);
    final mac = box.mac.bytes;
    final out = BytesBuilder(copy: false)
      ..add(nonce)
      ..add(mac)
      ..add(box.cipherText);
    return out.toBytes();
  }

  static Future<Uint8List> decryptBytes(
      List<int> blob, SecretKey key) async {
    if (blob.length < nonceLength + 16) {
      throw const FormatException('Encrypted blob is too short');
    }
    final nonce = blob.sublist(0, nonceLength);
    final mac = blob.sublist(nonceLength, nonceLength + 16);
    final cipher = blob.sublist(nonceLength + 16);
    final clear = await _aesGcm.decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
      secretKey: key,
    );
    return Uint8List.fromList(clear);
  }

  /// A stable, non-reversible fingerprint used to verify an unlock attempt
  /// without exposing the key. Equal to HMAC-SHA-256(key, "lonyogang-check").
  static Future<String> keyFingerprint(SecretKey key) async {
    final hmac = Hmac.sha256();
    final raw = await hmac.calculateMac(utf8.encode('lonyogang-check'),
        secretKey: key);
    return base64Encode(raw.bytes);
  }
}
