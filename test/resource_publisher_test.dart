import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/data/credentials_store.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/data/remote_sync.dart';
import 'package:lonyogang_heritage/data/resource_publisher.dart';
import 'package:lonyogang_heritage/data/sync_outbox.dart';
import 'package:lonyogang_heritage/domain/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loopback backend that records every PUT /resources/:kind/:id it
/// sees and every DELETE, so we can assert that a local mutation
/// actually fans out to the REST surface via the publisher.
class _RecordingBackend {
  final List<_Call> puts = [];
  final List<_Call> deletes = [];
  final List<String> clears = [];
  late final HttpServer server;

  static Future<_RecordingBackend> start() async {
    final b = _RecordingBackend._();
    b.server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(b.server.forEach(b._handle));
    return b;
  }

  _RecordingBackend._();

  Future<void> close() => server.close(force: true);
  Uri get baseUri => Uri.parse('http://${server.address.host}:${server.port}');

  Future<void> _handle(HttpRequest req) async {
    // Kind-wide clear (DELETE /resources/:kind, no id).
    final kindOnly = RegExp(r'^/resources/([^/]+)$').firstMatch(req.uri.path);
    if (kindOnly != null && req.method == 'DELETE') {
      await utf8.decoder.bind(req).join();
      clears.add(kindOnly.group(1)!);
      req.response.statusCode = 200;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({'cleared': 1}));
      await req.response.close();
      return;
    }
    final m = RegExp(r'^/resources/([^/]+)/([^/]+)$').firstMatch(req.uri.path);
    if (m == null) {
      req.response.statusCode = 404;
      await req.response.close();
      return;
    }
    final kind = m.group(1)!;
    final id = m.group(2)!;
    if (req.method == 'PUT') {
      final body = await utf8.decoder.bind(req).join();
      puts.add(_Call(kind: kind, id: id, body: jsonDecode(body) as Map));
      req.response.statusCode = 200;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({
        'kind': kind,
        'id': id,
        'ciphertext': (jsonDecode(body) as Map)['ciphertext'],
        'integrity': (jsonDecode(body) as Map)['integrity'],
        'prevHash': null,
        'deviceId': (jsonDecode(body) as Map)['deviceId'],
        'version': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'deletedAt': null,
      }));
      await req.response.close();
      return;
    }
    if (req.method == 'DELETE') {
      await utf8.decoder.bind(req).join();
      deletes.add(_Call(kind: kind, id: id, body: const {}));
      req.response.statusCode = 204;
      await req.response.close();
      return;
    }
    req.response.statusCode = 405;
    await req.response.close();
  }
}

class _Call {
  final String kind;
  final String id;
  final Map body;
  _Call({required this.kind, required this.id, required this.body});
}

void main() {
  late _RecordingBackend backend;
  late RemoteSyncService remote;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _PassthroughHttpOverrides();
    SharedPreferences.setMockInitialValues({});
    await CredentialsStore().save(const RemoteSyncCredentials(
      accessToken: 'test-access',
      refreshToken: 'test-refresh',
      deviceId: '00000000-0000-0000-0000-000000000070',
    ));
    backend = await _RecordingBackend.start();
    final creds = CredentialsStore();
    remote = RemoteSyncService(
      baseUri: backend.baseUri,
      credentialsLoader: creds.load,
      credentialsSaver: creds.save,
      outboxLoader: () async => const [],
      pullHandler: (_) async {},
    );
  });

  tearDown(() async {
    await backend.close();
  });

  test('upsertAsset fans out to PUT /resources/asset/:id', () async {
    final outbox = SyncOutbox();
    final store = PortfolioStore(
      outbox: outbox,
      resourcePublisher: ResourcePublisher(remote: remote),
    );
    await store.load();
    await store.setOwner('Owner');
    await store.enablePassphrase('passphrase-of-length-12');
    await store.upsertAsset(WealthAsset(
      id: 'asset-1',
      name: 'Plot',
      kind: AssetKind.property,
      valueUgx: 10000000,
      valuedAt: DateTime(2026, 11, 1),
    ));
    // Publisher is fire-and-forget; give it a moment.
    for (var i = 0; i < 20 && backend.puts.isEmpty; i += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    expect(backend.puts, hasLength(1));
    expect(backend.puts.first.kind, 'asset');
    expect(backend.puts.first.id, 'asset-1');
    expect(backend.puts.first.body['integrity']?['ownership_bps'], 10000);
  });

  test('clearDismissedAlerts fans out to DELETE /resources/alert_dismissal (kind-wide)',
      () async {
    final outbox = SyncOutbox();
    final store = PortfolioStore(
      outbox: outbox,
      resourcePublisher: ResourcePublisher(remote: remote),
    );
    await store.load();
    await store.setOwner('Owner');
    await store.enablePassphrase('passphrase-of-length-12');
    await store.dismissAlert('reminder:r1:2026-11-10T00:00:00.000');
    await store.clearDismissedAlerts();
    for (var i = 0; i < 20 && backend.clears.isEmpty; i += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    expect(backend.clears, contains('alert_dismissal'));
  });

  test('deleteGoal fans out to DELETE /resources/goal/:id', () async {
    final outbox = SyncOutbox();
    final store = PortfolioStore(
      outbox: outbox,
      resourcePublisher: ResourcePublisher(remote: remote),
    );
    await store.load();
    await store.setOwner('Owner');
    await store.enablePassphrase('passphrase-of-length-12');
    await store.upsertGoal(const WealthGoal(
      id: 'g1',
      name: 'Rainy day',
      targetUgx: 1000000,
      savedUgx: 0,
    ));
    await store.deleteGoal('g1');
    for (var i = 0; i < 20 && backend.deletes.isEmpty; i += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    expect(backend.deletes, hasLength(1));
    expect(backend.deletes.first.kind, 'goal');
    expect(backend.deletes.first.id, 'g1');
  });
}

class _PassthroughHttpOverrides extends HttpOverrides {}
