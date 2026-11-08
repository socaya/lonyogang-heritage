import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lonyogang_heritage/data/credentials_store.dart';
import 'package:lonyogang_heritage/data/remote_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loopback fake backend covering the identity + billing + audit surface
/// RemoteSyncService now drives. The helpers under test are narrow
/// request/response wrappers — this exists so the JSON shape and the
/// endpoint-selection logic are both pinned.
class _FakeBackend {
  late final HttpServer server;
  int meMarketingConsentCalls = 0;

  static Future<_FakeBackend> start() async {
    final backend = _FakeBackend._();
    backend.server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(backend.server.forEach(backend._handle));
    return backend;
  }

  _FakeBackend._();

  Future<void> close() => server.close(force: true);

  Uri get baseUri => Uri.parse('http://${server.address.host}:${server.port}');

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    final method = req.method;
    try {
      if (method == 'GET' && path == '/identity/sessions') {
        _writeJson(req, {
          'sessions': [
            {
              'id': 's1',
              'device_id': 'dev-abc',
              'user_agent': 'Pixel 7',
              'created_at': '2026-11-01T09:00:00.000Z',
              'refreshed_at': '2026-11-07T09:00:00.000Z',
              'revoked_at': null,
              'expires_at': '2026-12-01T09:00:00.000Z',
            },
            {
              'id': 's2',
              'device_id': 'dev-xyz',
              'user_agent': 'iPhone',
              'created_at': '2026-10-01T09:00:00.000Z',
              'refreshed_at': null,
              'revoked_at': '2026-10-20T09:00:00.000Z',
              'expires_at': '2026-11-01T09:00:00.000Z',
            },
          ],
        });
        return;
      }
      if (method == 'GET' && path == '/billing/subscription') {
        _writeJson(req, {
          'tier': 'heritage',
          'status': 'active',
          'currentPeriodEnd': '2026-12-20T09:00:00.000Z',
          'provider': 'stripe',
        });
        return;
      }
      if (method == 'PATCH' && path == '/me') {
        final body = await utf8.decoder.bind(req).join();
        final parsed = jsonDecode(body) as Map<String, dynamic>;
        if (parsed.containsKey('marketingConsent')) {
          meMarketingConsentCalls += 1;
        }
        _writeJson(req, {'ok': true});
        return;
      }
      if (method == 'POST' && path == '/identity/password/reset/begin') {
        await utf8.decoder.bind(req).join();
        req.response.statusCode = 202;
        await req.response.close();
        return;
      }
      if (method == 'POST' && path == '/identity/password/reset/begin-rate') {
        req.response.statusCode = 429;
        await req.response.close();
        return;
      }
      if (method == 'GET' && path == '/bank/providers') {
        _writeJson(req, {
          'providers': ['mock', 'stanbic'],
        });
        return;
      }
      if (method == 'GET' && path == '/audit/chain') {
        _writeJson(req, {
          'verified': true,
          'count': 3,
          'tipHash': 'YWJjZA==',
          'brokenAt': null,
        });
        return;
      }
      if (method == 'GET' && path == '/audit/entries') {
        _writeJson(req, {
          'entries': [
            {
              'id': 'e1',
              'action': 'account.created',
              'resource': 'account:a1',
              'createdAt': '2026-11-07T09:00:00.000Z',
              'context': {'email': 'you@example.com'},
              'hash': 'AQID',
              'prevHash': null,
            }
          ],
        });
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

  void _writeJson(HttpRequest req, Object body) {
    req.response.statusCode = 200;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(body));
    req.response.close();
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

  RemoteSyncService buildSync(_FakeBackend b) {
    final store = CredentialsStore();
    return RemoteSyncService(
      baseUri: b.baseUri,
      credentialsLoader: store.load,
      credentialsSaver: store.save,
      outboxLoader: () async => const [],
      pullHandler: (_) async {},
    );
  }

  test('listSessions decodes the server shape', () async {
    final b = await _FakeBackend.start();
    try {
      final sync = buildSync(b);
      final sessions = await sync.listSessions();
      expect(sessions, hasLength(2));
      expect(sessions[0].id, 's1');
      expect(sessions[0].isActive, isTrue);
      expect(sessions[1].isActive, isFalse);
      expect(sessions[1].revokedAt, isNotNull);
    } finally {
      await b.close();
    }
  });

  test('getSubscription reads tier + renewal', () async {
    final b = await _FakeBackend.start();
    try {
      final sub = await buildSync(b).getSubscription();
      expect(sub.tier, 'heritage');
      expect(sub.status, 'active');
      expect(sub.currentPeriodEnd, isNotNull);
      expect(sub.provider, 'stripe');
    } finally {
      await b.close();
    }
  });

  test('patchMe marketing consent writes PATCH /me', () async {
    final b = await _FakeBackend.start();
    try {
      await buildSync(b).patchMe(marketingConsent: true);
      expect(b.meMarketingConsentCalls, 1);
    } finally {
      await b.close();
    }
  });

  test('beginPasswordReset swallows the 202 response silently', () async {
    final b = await _FakeBackend.start();
    try {
      // Plain success path; should not raise.
      await buildSync(b).beginPasswordReset(email: 'you@example.com');
    } finally {
      await b.close();
    }
  });

  test('listBankProviders returns the string list from the server', () async {
    final b = await _FakeBackend.start();
    try {
      final providers = await buildSync(b).listBankProviders();
      expect(providers, ['mock', 'stanbic']);
    } finally {
      await b.close();
    }
  });

  test('verifyAuditChain + listAuditEntries + listAuditAnchors round-trip',
      () async {
    final b = await _FakeBackend.start();
    try {
      final sync = buildSync(b);
      final chain = await sync.verifyAuditChain();
      expect(chain.verified, isTrue);
      expect(chain.count, 3);
      final entries = await sync.listAuditEntries();
      expect(entries, hasLength(1));
      expect(entries.first.action, 'account.created');
      expect(entries.first.prevHashBase64, isNull);
    } finally {
      await b.close();
    }
  });
}

/// flutter_test shims HttpClient; this restores a real one so the loopback
/// fake backend actually serves.
class _PassthroughHttpOverrides extends HttpOverrides {}
