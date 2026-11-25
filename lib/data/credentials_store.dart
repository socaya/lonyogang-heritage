import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'remote_sync.dart';

/// Session secrets are persisted only through the native secure storage channel.
class CredentialsStore {
  static const _secure=MethodChannel('lonyogang/secure_session');
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
    final prefs=await SharedPreferences.getInstance();
    // Do not migrate previously exposed refresh tokens: require fresh sign-in.
    if(prefs.containsKey(_prefsKey)&&!await prefs.remove(_prefsKey)){
      throw StateError('Could not remove legacy session credentials');
    }
    try{
      final raw=await _secure.invokeMethod<String>('read');
      if(raw==null)return null;
      return RemoteSyncCredentials.fromJson(jsonDecode(raw) as Map<String,dynamic>);
    }on MissingPluginException{return null;}
  }

  Future<void> save(RemoteSyncCredentials credentials) async {
    final prefs=await SharedPreferences.getInstance();
    if(prefs.containsKey(_prefsKey)&&!await prefs.remove(_prefsKey)){
      throw StateError('Could not remove legacy session credentials');
    }
    await _secure.invokeMethod<void>('write',{'value':jsonEncode(credentials.toJson())});
  }

  Future<void> clear() async {
    final prefs=await SharedPreferences.getInstance();
    if(prefs.containsKey(_prefsKey)&&!await prefs.remove(_prefsKey)){
      throw StateError('Could not remove legacy session credentials');
    }
    try{await _secure.invokeMethod<void>('clear');}on MissingPluginException{ }
  }
}
