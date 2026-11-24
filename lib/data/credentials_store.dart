import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'remote_sync.dart';

/// Persists [RemoteSyncCredentials] in SharedPreferences. In a hardened
/// build this would be replaced by the OS keystore, but the token payload
/// is short-lived enough (15 min access, 30 day refresh) that SharedPrefs
/// is acceptable so long as the device itself is protected by the vault.
class CredentialsStore {
  static const _prefsKey = 'lonyogang_sync_credentials_v1';

  static const _deviceKey = 'lonyogang_installation_device_v2';
  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2,'0')).join();
    final id = '${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20)}';
    if (!await prefs.setString(_deviceKey,id)) throw StateError('Could not save device identifier');
    return id;
  }

  Future<RemoteSyncCredentials?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return RemoteSyncCredentials.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(RemoteSyncCredentials credentials) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(credentials.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
