import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/data/attachment_syncer.dart';
import 'package:lonyogang_heritage/data/credentials_store.dart';
import 'package:lonyogang_heritage/data/remote_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny mock backend: matches the shape AttachmentSyncer expects.
/// Stores uploaded ciphertext in memory and hands it back on download.
class _FakeBackend {
  final Map<String, List<int>> _blobs = {};
  int _nextId = 1;
  late final HttpServer server;

  static Future<_FakeBackend> start() async {
    final backend = _FakeBackend._();
    backend.server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(backend.server.forEach(backend._handle));
    return backend;
  }

  _FakeBackend._();

  Future<void> close() => server.close(force: true);

  Uri get baseUri =>
      Uri.parse('http://${server.address.host}:${server.port}');

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    final method = req.method;
    try {
      if (method == 'POST' && path == '/sync/attachments') {
        req.response.statusCode = 201;
        final id = 'blob-${_nextId++}';
        final uploadPath = '/_upload/$id';
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({
          'attachmentId': id,
          'uploadUrl': '${baseUri.replace(path: uploadPath)}',
          'bucketKey': uploadPath,
        }));
        await req.response.close();
        return;
      }
      if (method == 'PUT' && path.startsWith('/_upload/')) {
        final id = path.substring('/_upload/'.length);
        final bytes = <int>[];
        await for (final chunk in req) {
          bytes.addAll(chunk);
        }
        _blobs[id] = bytes;
        req.response.statusCode = 200;
        await req.response.close();
        return;
      }
      final commitMatch =
          RegExp(r'^/sync/attachments/([^/]+)/commit$').firstMatch(path);
      if (method == 'POST' && commitMatch != null) {
        req.response.statusCode = 204;
        await req.response.close();
        return;
      }
      final idMatch =
          RegExp(r'^/sync/attachments/([^/]+)$').firstMatch(path);
      if (method == 'GET' && idMatch != null) {
        final id = idMatch.group(1)!;
        if (!_blobs.containsKey(id)) {
          req.response.statusCode = 404;
          await req.response.close();
          return;
        }
        final downloadPath = '/_download/$id';
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode(
            {'downloadUrl': '${baseUri.replace(path: downloadPath)}'}));
        await req.response.close();
        return;
      }
      if (method == 'GET' && path.startsWith('/_download/')) {
        final id = path.substring('/_download/'.length);
        final bytes = _blobs[id];
        if (bytes == null) {
          req.response.statusCode = 404;
          await req.response.close();
          return;
        }
        req.response.statusCode = 200;
        req.response.add(bytes);
        await req.response.close();
        return;
      }
      if (method == 'DELETE' && idMatch != null) {
        _blobs.remove(idMatch.group(1));
        req.response.statusCode = 204;
        await req.response.close();
        return;
      }
      req.response.statusCode = 404;
      await req.response.close();
    } catch (e) {
      req.response.statusCode = 500;
      req.response.write('$e');
      await req.response.close();
    }
  }
}

void main() {
  setUp(() async {
    // flutter_test shims HttpClient to return 400 by default after
    // ensureInitialized runs. Re-install a passthrough override *after* the
    // binding has set up SharedPreferences's platform channel so real HTTP
    // works again against the loopback fake backend.
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _PassthroughHttpOverrides();
    SharedPreferences.setMockInitialValues({});
    final store = CredentialsStore();
    await store.save(const RemoteSyncCredentials(
      accessToken: 'test-access-token',
      refreshToken: 'test-refresh-token',
      deviceId: '00000000-0000-0000-0000-000000000080',
    ));
  });

  test('uploadCiphertext drives the three-phase presign dance and returns the id',
      () async {
    final backend = await _FakeBackend.start();
    try {
      final syncer = AttachmentSyncer(
        baseUri: backend.baseUri,
        credentials: CredentialsStore(),
      );
      final bytes = Uint8List.fromList(List.generate(64, (i) => i));
      final sha = List<int>.filled(32, 0x55);
      final id = await syncer.uploadCiphertext(
        bytes: bytes,
        sha256: sha,
        mimeType: 'application/octet-stream',
      );
      expect(id, matches(RegExp(r'^blob-\d+$')));
      syncer.close();
    } finally {
      await backend.close();
    }
  });

  test('downloadCiphertext round-trips the bytes we uploaded', () async {
    final backend = await _FakeBackend.start();
    try {
      final syncer = AttachmentSyncer(
        baseUri: backend.baseUri,
        credentials: CredentialsStore(),
      );
      final bytes = Uint8List.fromList([9, 8, 7, 6, 5, 4, 3, 2, 1, 0]);
      final id = await syncer.uploadCiphertext(
        bytes: bytes,
        sha256: List<int>.filled(32, 0x11),
        mimeType: 'application/octet-stream',
      );
      final fetched = await syncer.downloadCiphertext(id);
      expect(fetched, bytes);
      await syncer.deleteRemote(id);
      await expectLater(
        syncer.downloadCiphertext(id),
        throwsA(isA<HttpException>()),
      );
      syncer.close();
    } finally {
      await backend.close();
    }
  });

  test('refuses to upload without stored credentials', () async {
    final backend = await _FakeBackend.start();
    try {
      // Fresh prefs → no saved credentials.
      SharedPreferences.setMockInitialValues({});
      final syncer = AttachmentSyncer(
        baseUri: backend.baseUri,
        credentials: CredentialsStore(),
      );
      await expectLater(
        syncer.uploadCiphertext(
          bytes: Uint8List(1),
          sha256: List<int>.filled(32, 0),
          mimeType: 'application/octet-stream',
        ),
        throwsA(isA<StateError>()),
      );
      syncer.close();
    } finally {
      await backend.close();
    }
  });
}

/// HttpOverrides that returns a plain HttpClient — bypasses the default
/// flutter_test override which returns an HTTP 400 for every request.
class _PassthroughHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}
