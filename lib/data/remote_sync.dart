import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'sync.dart';

/// Minimal credentials + cursor state the remote sync service persists.
/// Returned by [RemoteSyncService.wipeLocalCredentials] so callers can
/// decide where to store them (SharedPreferences, secure storage, etc.).
class RemoteSyncCredentials {
  final String accessToken;
  final String refreshToken;
  final String deviceId;
  final DateTime? cursor;
  const RemoteSyncCredentials({
    required this.accessToken,
    required this.refreshToken,
    required this.deviceId,
    this.cursor,
  });

  RemoteSyncCredentials copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? cursor,
  }) =>
      RemoteSyncCredentials(
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        deviceId: deviceId,
        cursor: cursor ?? this.cursor,
      );

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'deviceId': deviceId,
        if (cursor != null) 'cursor': cursor!.toIso8601String(),
      };

  factory RemoteSyncCredentials.fromJson(Map<String, dynamic> j) =>
      RemoteSyncCredentials(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        deviceId: j['deviceId'] as String,
        cursor: j['cursor'] == null ? null : DateTime.parse(j['cursor'] as String),
      );
}

/// An event the client ships to the server. Payload is already AES-GCM
/// encrypted on the device; the server never sees the plaintext.
class RemoteSyncEvent {
  final String id;
  final String deviceId;
  final String payloadType;
  final Uint8List payload;
  final Uint8List? prevHash;
  final Map<String, dynamic>? integrity;
  final DateTime createdAt;
  const RemoteSyncEvent({
    required this.id,
    required this.deviceId,
    required this.payloadType,
    required this.payload,
    this.prevHash,
    this.integrity,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceId': deviceId,
        'payloadType': payloadType,
        'payload': base64Encode(payload),
        'prevHash': prevHash == null ? null : base64Encode(prevHash!),
        if (integrity != null) 'integrity': integrity,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// An event pulled back from the server.
class RemoteSyncEventRecord {
  final String id;
  final String deviceId;
  final String payloadType;
  final Uint8List payload;
  final Uint8List? prevHash;
  final Uint8List hash;
  final Map<String, dynamic>? integrity;
  final DateTime receivedAt;
  final DateTime createdAt;
  const RemoteSyncEventRecord({
    required this.id,
    required this.deviceId,
    required this.payloadType,
    required this.payload,
    required this.prevHash,
    required this.hash,
    required this.integrity,
    required this.receivedAt,
    required this.createdAt,
  });

  factory RemoteSyncEventRecord.fromJson(Map<String, dynamic> j) {
    return RemoteSyncEventRecord(
      id: j['id'] as String,
      deviceId: j['deviceId'] as String,
      payloadType: j['payloadType'] as String,
      payload: base64Decode(j['payload'] as String),
      prevHash: j['prevHash'] == null ? null : base64Decode(j['prevHash'] as String),
      hash: base64Decode(j['hash'] as String),
      integrity: j['integrity'] as Map<String, dynamic>?,
      receivedAt: DateTime.parse(j['receivedAt'] as String),
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }
}

/// A caller-supplied source of outbound events. The store builds this from
/// its own outbox; tests can supply a static list.
typedef OutboxLoader = Future<List<RemoteSyncEvent>> Function();

/// Callback invoked for each pulled event so the store can decrypt and
/// merge it into local state.
typedef PullHandler = Future<void> Function(RemoteSyncEventRecord record);

/// Real implementation of [SyncService] that talks to the LonyoGang backend
/// described in docs/ONLINE_SERVICE_PLAN.md. Posts the outbox, pulls new
/// events since a server-side cursor, refreshes tokens when they expire.
class RemoteSyncService implements SyncService {
  RemoteSyncService({
    required Uri baseUri,
    required this.credentialsLoader,
    required this.credentialsSaver,
    required this.outboxLoader,
    required this.pullHandler,
    HttpClient? httpClient,
  })  : _baseUri = baseUri,
        _http = httpClient ?? HttpClient();

  final Uri _baseUri;
  Uri get baseUri => _baseUri;
  final HttpClient _http;
  final Future<RemoteSyncCredentials?> Function() credentialsLoader;
  final Future<void> Function(RemoteSyncCredentials) credentialsSaver;
  final OutboxLoader outboxLoader;
  final PullHandler pullHandler;

  final ValueNotifier<SyncStatus> _status =
      ValueNotifier<SyncStatus>(SyncStatus.disconnected);
  String? _lastError;

  @override
  ValueListenable<SyncStatus> get status => _status;

  @override
  String? get lastError => _lastError;

  @override
  Future<void> sync() async {
    final creds = await credentialsLoader();
    if (creds == null) {
      _status.value = SyncStatus.disconnected;
      return;
    }
    _status.value = SyncStatus.syncing;
    try {
      final after = await _refreshIfNeeded(creds);
      final outbox = await outboxLoader();
      if (outbox.isNotEmpty) {
        await _postEvents(after, outbox);
      }
      final latestCursor = await _pullEvents(after);
      if (latestCursor != null) {
        await credentialsSaver(after.copyWith(cursor: latestCursor));
      }
      _lastError = null;
      _status.value = SyncStatus.ready;
    } on SocketException catch (e) {
      _lastError = 'Network unavailable: ${e.message}';
      _status.value = SyncStatus.offline;
    } catch (e) {
      _lastError = '$e';
      _status.value = SyncStatus.error;
      rethrow;
    }
  }

  @override
  Future<void> wipeLocalCredentials() async {
    _status.value = SyncStatus.disconnected;
    _lastError = null;
  }

  Future<DateTime?> _pullEvents(RemoteSyncCredentials creds) async {
    DateTime? cursor = creds.cursor;
    while (true) {
      final uri = _baseUri.resolve('/sync/events').replace(queryParameters: {
        if (cursor != null) 'since': cursor.toIso8601String(),
        'limit': '500',
      });
      final raw = await _request('GET', uri, creds);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final events = (decoded['events'] as List<dynamic>? ?? const [])
          .map((e) => RemoteSyncEventRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      if (events.isEmpty) break;
      for (final event in events) {
        await pullHandler(event);
        cursor = event.receivedAt;
      }
      if (events.length < 500) break;
    }
    return cursor;
  }

  Future<void> _postEvents(
      RemoteSyncCredentials creds, List<RemoteSyncEvent> events) async {
    final uri = _baseUri.resolve('/sync/events');
    final body = jsonEncode({'events': events.map((e) => e.toJson()).toList()});
    await _request('POST', uri, creds, body: body);
  }

  Future<RemoteSyncCredentials> _refreshIfNeeded(
      RemoteSyncCredentials creds) async {
    // Lazy refresh: only refresh when a request returns 401. The first sync
    // call optimistically uses the current access token. See [_request].
    return creds;
  }

  Future<String> _request(
    String method,
    Uri uri,
    RemoteSyncCredentials creds, {
    String? body,
    bool allowRefresh = true,
  }) async {
    final request = await _http.openUrl(method, uri);
    request.headers.set('authorization', 'Bearer ${creds.accessToken}');
    request.headers.contentType = ContentType.json;
    if (body != null) request.write(body);
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode == 401 && allowRefresh) {
      final refreshed = await _refreshTokens(creds);
      await credentialsSaver(refreshed);
      return _request(method, uri, refreshed, body: body, allowRefresh: false);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Sync HTTP ${response.statusCode}: $text', uri: uri);
    }
    return text;
  }

  Future<RemoteSyncCredentials> _refreshTokens(RemoteSyncCredentials creds) async {
    final uri = _baseUri.resolve('/identity/sessions/refresh');
    final request = await _http.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'refreshToken': creds.refreshToken}));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Refresh failed: $text', uri: uri);
    }
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    return creds.copyWith(
      accessToken: decoded['accessToken'] as String,
      refreshToken: decoded['refreshToken'] as String,
    );
  }

  /// Convenience: creates an account on the backend. Intended for the real
  /// sign-up flow once the UI replaces its design-preview labels.
  Future<RemoteSyncAccount> signUp({
    required String email,
    required String password,
    String? phone,
    String? displayName,
  }) async {
    final uri = _baseUri.resolve('/identity/accounts');
    final request = await _http.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({
      'email': email,
      'password': password,
      if (phone != null) 'phone': phone,
      if (displayName != null) 'displayName': displayName,
    }));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Sign-up failed: $text', uri: uri);
    }
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    return RemoteSyncAccount(
      accountId: decoded['accountId'] as String,
      emailCode: decoded['emailCode'] as String?,
      phoneCode: decoded['phoneCode'] as String?,
    );
  }

  /// Convenience: verifies an OTP code for the given channel.
  Future<void> verify({
    required String accountId,
    required String channel,
    required String code,
  }) async {
    final uri = _baseUri.resolve('/identity/accounts/verify');
    final request = await _http.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'accountId': accountId, 'channel': channel, 'code': code}));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Verify failed: $text', uri: uri);
    }
  }

  /// Requests a fresh OTP code for a channel while the account is still
  /// pending verification. The server enforces a 60-second cooldown.
  Future<void> resendOtp({
    required String accountId,
    required String channel,
  }) async {
    final uri = _baseUri.resolve('/identity/accounts/verify/resend');
    final request = await _http.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'accountId': accountId, 'channel': channel}));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode != 202 && response.statusCode != 200) {
      throw HttpException('Resend failed: $text', uri: uri);
    }
  }

  /// Convenience: signs in with email + password (+ optional TOTP) and
  /// persists the resulting credentials.
  Future<RemoteSyncCredentials> signIn({
    required String email,
    required String password,
    required String deviceId,
    String? totpCode,
  }) async {
    final uri = _baseUri.resolve('/identity/sessions');
    final request = await _http.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({
      'email': email,
      'password': password,
      'deviceId': deviceId,
      if (totpCode != null) 'totpCode': totpCode,
    }));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Sign-in failed: $text', uri: uri);
    }
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    final creds = RemoteSyncCredentials(
      accessToken: decoded['accessToken'] as String,
      refreshToken: decoded['refreshToken'] as String,
      deviceId: deviceId,
    );
    await credentialsSaver(creds);
    _status.value = SyncStatus.ready;
    return creds;
  }
}

/// Result of [RemoteSyncService.signUp] handed back to the UI so it can
/// surface the dev-mode OTP codes for the integration tests.
class RemoteSyncAccount {
  final String accountId;
  final String? emailCode;
  final String? phoneCode;
  const RemoteSyncAccount({
    required this.accountId,
    this.emailCode,
    this.phoneCode,
  });
}
