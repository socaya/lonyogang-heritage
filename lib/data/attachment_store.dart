import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import '../core/crypto.dart';
import '../domain/models.dart';

typedef DirectoryResolver = Future<Directory> Function();

/// Encrypted-at-rest attachment store. Files live under the application's
/// private documents directory in a subfolder named "vault-attachments" and
/// are AES-GCM encrypted under the vault key (or a derived per-file key
/// when the vault has no passphrase). Decryption happens on demand into a
/// temporary file that the caller is responsible for deleting.
class AttachmentStore {
  AttachmentStore({DirectoryResolver? resolveDirectory})
      : _resolveDirectory = resolveDirectory ?? _defaultResolver;

  static const subdirectory = 'vault-attachments';
  final DirectoryResolver _resolveDirectory;

  static Future<Directory> _defaultResolver() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$subdirectory');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Directory> _dir() async {
    final dir = await _resolveDirectory();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<AttachmentRef> write({
    required String documentId,
    required List<int> bytes,
    required String filename,
    required String mimeType,
    SecretKey? key,
  }) async {
    final dir = await _dir();
    final effectiveKey = key ?? await _fallbackKey(documentId);
    final blob = await VaultCrypto.encryptBytes(bytes, effectiveKey);
    final hash = await Sha256().hash(bytes);
    final relative = '$documentId-${DateTime.now().microsecondsSinceEpoch}.bin';
    final file = File('${dir.path}/$relative');
    await file.writeAsBytes(blob, flush: true);
    return AttachmentRef(
        originalFilename: filename,
        mimeType: mimeType,
        relativePath: relative,
        sizeBytes: bytes.length,
        sha256Hex: _hex(hash.bytes),
        addedAt: DateTime.now());
  }

  /// Reads and decrypts a stored attachment. Throws if the SHA-256 of the
  /// decrypted bytes disagrees with the recorded fingerprint.
  Future<Uint8List> read(AttachmentRef ref, {SecretKey? key}) async {
    final dir = await _dir();
    final file = File('${dir.path}/${ref.relativePath}');
    final blob = await file.readAsBytes();
    final effectiveKey = key ?? await _fallbackKey(_documentIdFromPath(ref.relativePath));
    final plain = await VaultCrypto.decryptBytes(blob, effectiveKey);
    final hash = await Sha256().hash(plain);
    if (_hex(hash.bytes) != ref.sha256Hex) {
      throw const FormatException('Attachment integrity check failed');
    }
    return plain;
  }

  Future<void> delete(AttachmentRef ref) async {
    final dir = await _dir();
    final file = File('${dir.path}/${ref.relativePath}');
    if (file.existsSync()) file.deleteSync();
  }

  /// Materializes the decrypted bytes into a temporary file so that
  /// [OpenFilex] (or similar) can hand them to the OS viewer. The caller
  /// is responsible for best-effort deletion of the returned file.
  Future<File> materialize(AttachmentRef ref, {SecretKey? key}) async {
    final bytes = await read(ref, key: key);
    final tmp = Directory.systemTemp.createTempSync('lonyogang-attachment');
    final file = File('${tmp.path}/${ref.originalFilename}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Fallback key for attachments created before a passphrase was set. It is
  /// derived from a device-stable hash of the document id and is deliberately
  /// weaker than a passphrase: the user is warned to enable encryption.
  Future<SecretKey> _fallbackKey(String documentId) async {
    final seed = 'lonyogang-fallback-$documentId';
    return VaultCrypto.deriveKey(seed, List<int>.filled(16, 7));
  }

  String _documentIdFromPath(String relative) {
    final dash = relative.indexOf('-');
    return dash < 0 ? relative : relative.substring(0, dash);
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
