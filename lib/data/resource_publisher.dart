import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../core/crypto.dart';
import 'remote_sync.dart';
import 'sync_outbox.dart';

/// Mirrors a plaintext mutation to the server's `/resources/:kind/:id`
/// REST surface in addition to the existing `/sync/events` outbox.
///
/// The publisher re-derives the content key the outbox already uses so a
/// row pushed through REST is bit-identical to the row that would have
/// been pushed through the event stream — a web client fetching through
/// REST and a mobile device replaying the event log land on the same
/// ciphertext and the same integrity hint.
///
/// The publisher is deliberately best-effort: a failure to reach the
/// backend never breaks a local write. The outbox is still the source of
/// truth for cross-device replay; this path just lets a web client see
/// the row before the next pull cycle without having to replay events.
class ResourcePublisher {
  ResourcePublisher({required this.remote});

  final RemoteSyncService remote;

  /// Extracts the resource id from a payload. Most of our entities carry
  /// their id at the top of the map; a few (beneficiary_batch,
  /// trusted_contact_delete) use the kind itself as the id because they
  /// are singletons or deletion tombstones.
  static String? _resolveId(String kind, Map<String, dynamic> payload) {
    switch (kind) {
      case 'beneficiary_batch':
        return 'all';
      case 'goal_delete':
      case 'trusted_contact_delete':
      case 'reminder_delete':
      case 'schedule_delete':
      case 'fx_rate_delete':
      case 'expense_delete':
        return payload['id']?.toString();
      default:
        final id = payload['id']?.toString();
        if (id != null && id.isNotEmpty) return id;
        // `alert_dismissal` carries `key`, not `id`.
        final key = payload['key']?.toString();
        if (key != null && key.isNotEmpty) return key;
        return null;
    }
  }

  /// Which event payload types map to a tombstone on the REST side.
  static const Set<String> _deleteKinds = {
    'goal_delete',
    'trusted_contact_delete',
    'reminder_delete',
    'schedule_delete',
    'fx_rate_delete',
    'expense_delete',
  };

  /// Payload types that clear an entire kind rather than one row.
  static const Set<String> _clearKindKinds = {
    'alert_dismissal_clear',
  };

  /// Our event kinds and the REST kinds live in slightly different
  /// namespaces: an event called `goal_delete` targets the
  /// `/resources/goal/:id` row for a tombstone.
  static String _restKind(String payloadType) {
    switch (payloadType) {
      case 'goal_delete':
        return 'goal';
      case 'trusted_contact_delete':
        return 'trusted_contact';
      case 'reminder_delete':
        return 'reminder';
      case 'schedule_delete':
        return 'schedule';
      case 'fx_rate_delete':
        return 'fx_rate';
      case 'expense_delete':
        return 'expense';
      case 'alert_dismissal_clear':
        return 'alert_dismissal';
      default:
        return payloadType;
    }
  }

  Future<void> publish({
    required String kind,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? integrity,
    required SecretKey vaultKey,
    required String deviceId,
  }) async {
    try {
      final restKind = _restKind(kind);
      if (_clearKindKinds.contains(kind)) {
        await remote.clearResourceKind(kind: restKind, deviceId: deviceId);
        return;
      }
      final id = _resolveId(kind, payload);
      if (id == null) return;
      if (_deleteKinds.contains(kind)) {
        await remote.deleteResource(
            kind: restKind, id: id, deviceId: deviceId);
        return;
      }
      final contentKey = await SyncOutbox.deriveContentKey(vaultKey);
      final ciphertext = await VaultCrypto.encryptBytes(
          utf8.encode(jsonEncode(payload)), contentKey);
      await remote.putResource(
        kind: restKind,
        id: id,
        ciphertext: ciphertext,
        deviceId: deviceId,
        integrity: integrity,
      );
    } on SocketException {
      // Offline: leave it to the outbox / next sync pass.
    } on HttpException {
      // 4xx/5xx from the server — the outbox will retry via /sync/events.
    } catch (err) {
      debugPrint('[resource_publisher] publish failed: $err');
    }
  }
}
