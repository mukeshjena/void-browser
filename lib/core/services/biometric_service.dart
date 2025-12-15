import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric authentication is available
  Future<bool> isAvailable() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        return false;
      }
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Authenticate using biometrics
  Future<bool> authenticate({String reason = 'Authenticate to unlock Vex Fast Privacy Browser'}) async {
    try {
      // Check if device supports biometrics
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) {
        debugPrint('Device does not support biometrics');
        return false;
      }

      // Get available biometrics
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        debugPrint('No biometrics available on device');
        return false;
      }

      debugPrint('Available biometrics: $availableBiometrics');
      debugPrint('Starting authentication...');

      // Authenticate - this will show the system biometric dialog
      // Use biometricOnly: false to allow device credentials as fallback
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow device PIN/pattern/password as fallback
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      debugPrint('Authentication result: $didAuthenticate');
      return didAuthenticate;
    } catch (e) {
      // Log error for debugging
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }

  /// Stop authentication (if in progress)
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      // Ignore errors
    }
  }
}

