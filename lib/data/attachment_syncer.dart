import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'credentials_store.dart';
import 'remote_sync.dart';

/// Drives the three-phase upload against the backend's `/sync/attachments`
/// endpoint: presign → PUT ciphertext to the signed URL → commit. The
/// server only sees opaque bytes plus the SHA-256 the client declares.
///
/// Also owns the download path for records pulled from another device:
/// `GET /sync/attachments/{id}` returns a presigned GET URL; the caller
/// fetches it and decrypts locally with the shared vault/content key.
class AttachmentSyncer {
  AttachmentSyncer({
    required Uri baseUri,
    required this.credentials,
    HttpClient? httpClient,
  })  : _baseUri = baseUri,
        _http = httpClient ?? HttpClient();

  final Uri _baseUri;
  final CredentialsStore credentials;
  final HttpClient _http;

  /// Uploads [bytes] (already AES-GCM encrypted by the vault) and returns
  /// the server-assigned attachment id. The caller is expected to persist
  /// that id alongside the local [AttachmentRef].
  Future<String> uploadCiphertext({
    required List<int> bytes,
    required List<int> sha256,
    required String mimeType,
  }) async {
    final creds = await _requireCreds();
    final presignUri = _baseUri.resolve('/sync/attachments');
    final presignReq = await _http.postUrl(presignUri);
    _applyAuth(presignReq, creds);
    presignReq.headers.contentType = ContentType.json;
    presignReq.write(jsonEncode({
      'sizeBytes': bytes.length,
      'sha256': base64Encode(sha256),
      'mimeType': mimeType,
    }));
    final presignRes = await presignReq.close();
    final presignBody = await presignRes.transform(utf8.decoder).join();
    if (presignRes.statusCode < 200 || presignRes.statusCode >= 300) {
      throw HttpException(
          'presign HTTP ${presignRes.statusCode}: $presignBody',
          uri: presignUri);
    }
    final presign = jsonDecode(presignBody) as Map<String, dynamic>;
    final attachmentId = presign['attachmentId'] as String;
    final uploadUrl = Uri.parse(presign['uploadUrl'] as String);

    // PUT ciphertext bytes to the signed URL.
    final putReq = await _http.putUrl(uploadUrl);
    putReq.headers.contentType = ContentType.parse(mimeType);
    putReq.headers.set('content-length', bytes.length.toString());
    putReq.add(bytes);
    final putRes = await putReq.close();
    await putRes.drain<void>();
    if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
      throw HttpException('upload HTTP ${putRes.statusCode}', uri: uploadUrl);
    }

    // Commit the attachment so the server flips its uploaded_at marker.
    final commitUri = _baseUri.resolve('/sync/attachments/$attachmentId/commit');
    final commitReq = await _http.postUrl(commitUri);
    _applyAuth(commitReq, creds);
    final commitRes = await commitReq.close();
    await commitRes.drain<void>();
    if (commitRes.statusCode != 204 && commitRes.statusCode != 200) {
      throw HttpException('commit HTTP ${commitRes.statusCode}', uri: commitUri);
    }
    return attachmentId;
  }

  /// Downloads the ciphertext for [serverId] via the signed-URL dance and
  /// returns the raw encrypted bytes. The caller decrypts with the vault
  /// content key.
  Future<Uint8List> downloadCiphertext(String serverId) async {
    final creds = await _requireCreds();
    final presignUri = _baseUri.resolve('/sync/attachments/$serverId');
    final presignReq = await _http.getUrl(presignUri);
    _applyAuth(presignReq, creds);
    final presignRes = await presignReq.close();
    final presignBody = await presignRes.transform(utf8.decoder).join();
    if (presignRes.statusCode < 200 || presignRes.statusCode >= 300) {
      throw HttpException(
          'presign HTTP ${presignRes.statusCode}: $presignBody',
          uri: presignUri);
    }
    final presign = jsonDecode(presignBody) as Map<String, dynamic>;
    final downloadUrl = Uri.parse(presign['downloadUrl'] as String);
    final getReq = await _http.getUrl(downloadUrl);
    final getRes = await getReq.close();
    if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
      throw HttpException('download HTTP ${getRes.statusCode}', uri: downloadUrl);
    }
    final chunks = <int>[];
    await for (final chunk in getRes) {
      chunks.addAll(chunk);
    }
    return Uint8List.fromList(chunks);
  }

  /// Deletes the server-side object. The local file stays until the
  /// owning AttachmentStore is told to delete it.
  Future<void> deleteRemote(String serverId) async {
    final creds = await _requireCreds();
    final uri = _baseUri.resolve('/sync/attachments/$serverId');
    final req = await _http.deleteUrl(uri);
    _applyAuth(req, creds);
    final res = await req.close();
    await res.drain<void>();
  }

  Future<RemoteSyncCredentials> _requireCreds() async {
    final creds = await credentials.load();
    if (creds == null) {
      throw StateError('No online credentials; connect account first');
    }
    return creds;
  }

  void _applyAuth(HttpClientRequest req, RemoteSyncCredentials creds) {
    req.headers.set('authorization', 'Bearer ${creds.accessToken}');
  }

  void close() => _http.close(force: true);
}
