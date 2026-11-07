import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static const String _pinHashKey = 'user_pin_hash';
  static const String _biometricsKey = 'biometrics_enabled';
  static const String _securitySetupCompletedKey = 'security_setup_completed';

  static final LocalAuthentication _auth = LocalAuthentication();

  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  /// Güvenlik kurulumu yapıldı mı kontrol et
  static Future<bool> isSetupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_securitySetupCompletedKey) ?? false;
  }

  /// Kayıtlı bir PIN var mı?
  static Future<bool> isPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    final hash = prefs.getString(_pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  /// Yeni PIN kaydet
  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinHashKey, _hashPin(pin));
    await prefs.setBool(_securitySetupCompletedKey, true);
  }

  /// Girilen PIN'i doğrula
  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_pinHashKey);
    if (storedHash == null) return false;
    return storedHash == _hashPin(pin);
  }

  /// Kilidi sıfırla / kapat
  static Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinHashKey);
    await prefs.remove(_biometricsKey);
    await prefs.setBool(_securitySetupCompletedKey, false);
  }

  /// Cihazda parmak izi / biyometrik sensör var mı?
  static Future<bool> isBiometricsAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Parmak izi kullanımı kullanıcı tarafından açılmış mı?
  static Future<bool> isBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricsKey) ?? false;
  }

  /// Parmak izi kullanım tercihini kaydet
  static Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricsKey, enabled);
  }

  /// Parmak iziyle kimlik doğrula
  static Future<bool> authenticateWithBiometrics() async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: 'Fotoğraflı Notlar uygulamasını açmak için parmak izinizi doğrulayın',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
