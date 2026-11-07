import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'remote_sync.dart';

/// Persists [RemoteSyncCredentials] in SharedPreferences. In a hardened
/// build this would be replaced by the OS keystore, but the token payload
/// is short-lived enough (15 min access, 30 day refresh) that SharedPrefs
/// is acceptable so long as the device itself is protected by the vault.
class CredentialsStore {
  static const _prefsKey = 'lonyogang_sync_credentials_v1';

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
