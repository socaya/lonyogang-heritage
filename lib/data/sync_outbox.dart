import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/crypto.dart';
import 'remote_sync.dart';

/// Persisted outbox of mutations that still need to be pushed to the
/// online backend. Every entry carries an already-encrypted payload so the
/// server never sees plaintext — the content key is derived from the vault
/// session key the device already holds.
///
/// The outbox is append-only on write; entries are removed only after
/// [RemoteSyncService.sync] confirms the server accepted them.
class SyncOutbox extends ChangeNotifier {
  static const _prefsKey = 'lonyogang_sync_outbox_v1';
  static const contentKeyInfo = 'content-key-v1';

  final List<_OutboxEntry> _entries = [];
  bool _loaded = false;

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;

  /// Loads the current outbox contents from persistent storage.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final item in list) {
          _entries.add(_OutboxEntry.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {
        // Corrupted cache — drop and move on. The server pull will re-hydrate.
      }
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  /// Records a new mutation. The payload is encrypted under the content key
  /// derived from [vaultKey] and queued for the next sync run. Callers
  /// must pass a non-empty [payloadType] matching the server's registry
  /// (asset, liability, ledger_event, valuation, etc.).
  Future<void> record({
    required String payloadType,
    required Map<String, dynamic> payload,
    required Map<String, dynamic>? integrity,
    required SecretKey vaultKey,
    required String deviceId,
  }) async {
    await load();
    final contentKey = await deriveContentKey(vaultKey);
    final bytes = utf8.encode(jsonEncode(payload));
    final ciphertext = await VaultCrypto.encryptBytes(bytes, contentKey);
    final entry = _OutboxEntry(
      id: _ulid(),
      payloadType: payloadType,
      ciphertext: ciphertext,
      integrity: integrity,
      createdAt: DateTime.now().toUtc(),
      deviceId: deviceId,
    );
    _entries.add(entry);
    await _persist();
    notifyListeners();
  }

  /// Returns a snapshot of pending events for [RemoteSyncService]. The
  /// outbox is not yet mutated; call [markAccepted] after a successful push.
  Future<List<RemoteSyncEvent>> snapshot() async {
    await load();
    return _entries
        .map((e) => RemoteSyncEvent(
              id: e.id,
              deviceId: e.deviceId,
              payloadType: e.payloadType,
              payload: e.ciphertext,
              integrity: e.integrity,
              createdAt: e.createdAt,
            ))
        .toList(growable: false);
  }

  /// Drops [ids] from the outbox after the server has acknowledged them.
  Future<void> markAccepted(Iterable<String> ids) async {
    await load();
    if (ids.isEmpty) return;
    final set = ids.toSet();
    _entries.removeWhere((e) => set.contains(e.id));
    await _persist();
    notifyListeners();
  }

  /// Wipes the outbox. Used by the local reset flow and when a new account
  /// signs in so stale events from a previous owner never leak.
  Future<void> clear() async {
    _entries.clear();
    await _persist();
    notifyListeners();
  }

  /// Derives a 32-byte content key from the vault session key using HKDF
  /// (HMAC-SHA-256) with a stable info string. The caller guarantees that
  /// [vaultKey] is a 32-byte secret.
  static Future<SecretKey> deriveContentKey(SecretKey vaultKey) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: vaultKey,
      info: utf8.encode(contentKeyInfo),
      nonce: Uint8List(0),
    );
  }

  static int _counter = 0;
  static String _ulid() {
    _counter = (_counter + 1) & 0xffff;
    final ms = DateTime.now().millisecondsSinceEpoch;
    return '${ms.toRadixString(32)}-${_counter.toRadixString(32).padLeft(4, '0')}';
  }
}

class _OutboxEntry {
  final String id;
  final String payloadType;
  final Uint8List ciphertext;
  final Map<String, dynamic>? integrity;
  final DateTime createdAt;
  final String deviceId;
  const _OutboxEntry({
    required this.id,
    required this.payloadType,
    required this.ciphertext,
    required this.integrity,
    required this.createdAt,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'payloadType': payloadType,
        'ciphertext': base64Encode(ciphertext),
        if (integrity != null) 'integrity': integrity,
        'createdAt': createdAt.toIso8601String(),
        'deviceId': deviceId,
      };

  factory _OutboxEntry.fromJson(Map<String, dynamic> j) => _OutboxEntry(
        id: j['id'] as String,
        payloadType: j['payloadType'] as String,
        ciphertext: base64Decode(j['ciphertext'] as String),
        integrity: j['integrity'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        deviceId: j['deviceId'] as String,
      );
}
