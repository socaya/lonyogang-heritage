import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Wrapper around `local_auth` that degrades to "unavailable" instead of
/// throwing when the platform has no biometric hardware (web, test, some
/// emulators). All UI paths check [isAvailable] before offering biometrics.
class BiometricGateway {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
            stickyAuth: true, biometricOnly: true),
      );
    } on PlatformException {
      return false;
    }
  }
}
