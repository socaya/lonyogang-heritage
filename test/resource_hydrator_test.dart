import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/core/crypto.dart';
import 'package:lonyogang_heritage/data/credentials_store.dart';
import 'package:lonyogang_heritage/data/portfolio_store.dart';
import 'package:lonyogang_heritage/data/remote_sync.dart';
import 'package:lonyogang_heritage/data/resource_hydrator.dart';
import 'package:lonyogang_heritage/data/sync_outbox.dart';
import 'package:lonyogang_heritage/data/sync_reducer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A loopback backend that serves a canned `/resources/:kind` snapshot
/// per kind. The hydrator should walk the list of kinds, pull each,
/// decrypt the ciphertext and merge into the local store.
class _SnapshotBackend {
  late final HttpServer server;
  final Map<String, List<Map<String, dynamic>>> snapshots = {};

  static Future<_SnapshotBackend> start() async {
    final b = _SnapshotBackend._();
    b.server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(b.server.forEach(b._handle));
    return b;
  }

  _SnapshotBackend._();

  Future<void> close() => server.close(force: true);
  Uri get baseUri => Uri.parse('http://${server.address.host}:${server.port}');

  Future<void> _handle(HttpRequest req) async {
    final m = RegExp(r'^/resources/([^/]+)$').firstMatch(req.uri.path);
    if (m == null || req.method != 'GET') {
      req.response.statusCode = 404;
      await req.response.close();
      return;
    }
    final kind = m.group(1)!;
    final rows = snapshots[kind] ?? const [];
    req.response.statusCode = 200;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode({'resources': rows}));
    await req.response.close();
  }
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _PassthroughHttpOverrides();
    SharedPreferences.setMockInitialValues({});
    await CredentialsStore().save(const RemoteSyncCredentials(
      accessToken: 'test-access',
      refreshToken: 'test-refresh',
      deviceId: '00000000-0000-0000-0000-000000000070',
    ));
  });

  test('hydrates assets + goals from /resources into the local store',
      () async {
    final backend = await _SnapshotBackend.start();
    try {
      // Build a store + unlock it so we have a vault content key.
      final outbox = SyncOutbox();
      final store = PortfolioStore(outbox: outbox);
      await store.load();
      await store.setOwner('Owner');
      await store.enablePassphrase('passphrase-of-length-12');

      final vaultKey = store.vault.activeKey!;
      final contentKey = await SyncOutbox.deriveContentKey(vaultKey);

      // Seed a remote asset whose ciphertext decrypts under the SAME
      // content key the hydrator will derive.
      Future<String> encrypted(Map<String, dynamic> plain) async {
        final bytes = await VaultCrypto.encryptBytes(
            utf8.encode(jsonEncode(plain)), contentKey);
        return base64Encode(bytes);
      }

      backend.snapshots['asset'] = [
        {
          'kind': 'asset',
          'id': 'remote-plot',
          'ciphertext': await encrypted({
            'id': 'remote-plot',
            'name': 'Remote plot',
            'kind': 'property',
            'category': '',
            'valueUgx': 50000000,
            'ownershipBps': 10000,
            'costUgx': 0,
            'institution': '',
            'valuedAt': DateTime(2026, 11, 1).toIso8601String(),
            'status': 'userEntered',
          }),
          'integrity': {'ownership_bps': 10000},
          'prevHash': null,
          'deviceId': '00000000-0000-0000-0000-000000000080',
          'version': 1,
          'createdAt': '2026-11-01T09:00:00.000Z',
          'updatedAt': '2026-11-01T09:00:00.000Z',
          'deletedAt': null,
        },
      ];
      backend.snapshots['goal'] = [
        {
          'kind': 'goal',
          'id': 'g-remote',
          'ciphertext': await encrypted({
            'id': 'g-remote',
            'name': 'Server goal',
            'targetUgx': 2000000,
            'savedUgx': 0,
            'targetDate': null,
          }),
          'integrity': null,
          'prevHash': null,
          'deviceId': '00000000-0000-0000-0000-000000000080',
          'version': 1,
          'createdAt': '2026-11-01T09:00:00.000Z',
          'updatedAt': '2026-11-01T09:00:00.000Z',
          'deletedAt': null,
        },
      ];

      final creds = CredentialsStore();
      final remote = RemoteSyncService(
        baseUri: backend.baseUri,
        credentialsLoader: creds.load,
        credentialsSaver: creds.save,
        outboxLoader: () async => const [],
        pullHandler: (_) async {},
      );
      final hydrator = ResourceHydrator(
        remote: remote,
        reducer: SyncReducer(store),
      );
      final progress = await hydrator.hydrate();
      // 2 rows applied (asset + goal), the rest of the kinds were empty.
      expect(progress.applied, 2);
      expect(store.state.assets.any((a) => a.id == 'remote-plot'), isTrue);
      expect(store.state.goals.any((g) => g.id == 'g-remote'), isTrue);
    } finally {
      await backend.close();
    }
  });
}

class _PassthroughHttpOverrides extends HttpOverrides {}
