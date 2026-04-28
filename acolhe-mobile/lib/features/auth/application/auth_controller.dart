import 'dart:async';
import 'dart:convert';

import 'package:acolhe_mobile/core/config/app_identity.dart';
import 'package:acolhe_mobile/core/storage/secure_storage_service.dart';
import 'package:acolhe_mobile/core/storage/storage_keys.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

final localAuthProvider =
    Provider<LocalAuthentication>((ref) => LocalAuthentication());

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthStateModel>((ref) {
  return AuthController(
    ref.read(secureStorageProvider),
    ref.read(localAuthProvider),
  );
});

class AuthController extends StateNotifier<AuthStateModel> {
  AuthController(this._storage, this._localAuth)
      : super(AuthStateModel.initial()) {
    unawaited(load());
  }

  final SecureStorageService _storage;
  final LocalAuthentication _localAuth;

  String _hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

  Future<void> load() async {
    final authMap = await _storage.readMap(StorageKeys.authState);
    final pinHash = await _storage.readString(StorageKeys.pinHash);
    if (authMap == null) {
      state = AuthStateModel.initial()
          .copyWith(isLoading: false, hasPin: pinHash != null);
      return;
    }
    state = AuthStateModel.fromJson(authMap).copyWith(
      isLoading: false,
      hasPin: pinHash != null,
      isUnlocked: false,
    );
  }

  Future<void> _persistState() =>
      _storage.writeMap(StorageKeys.authState, state.toJson());

  Future<void> completeOnboarding({
    required bool discreetMode,
    required bool biometricsEnabled,
  }) async {
    state = state.copyWith(
      isLoading: false,
      onboardingCompleted: true,
      discreetMode: discreetMode,
      biometricsEnabled: biometricsEnabled,
      aliasName: AppIdentity.appName,
    );
    await _persistState();
  }

  Future<void> setupPin(String pin) async {
    await _storage.writeString(StorageKeys.pinHash, _hashPin(pin));
    state = state.copyWith(hasPin: true, isUnlocked: true, isLoading: false);
    await _persistState();
  }

  Future<bool> unlockWithPin(String pin) async {
    final stored = await _storage.readString(StorageKeys.pinHash);
    if (stored == null) {
      return false;
    }
    final valid = stored == _hashPin(pin);
    if (valid) {
      state = state.copyWith(isUnlocked: true, privacyShield: false);
      await _persistState();
    }
    return valid;
  }

  Future<bool> unlockWithBiometrics() async {
    if (!state.biometricsEnabled) {
      return false;
    }
    final available = await _localAuth.canCheckBiometrics ||
        await _localAuth.isDeviceSupported();
    if (!available) {
      return false;
    }
    final valid = await _localAuth.authenticate(
      localizedReason: 'Desbloqueie com biometria para proteger seu conteudo.',
      options:
          const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
    );
    if (valid) {
      state = state.copyWith(isUnlocked: true, privacyShield: false);
      await _persistState();
    }
    return valid;
  }

  Future<void> updateSecurityPreferences({
    bool? biometricsEnabled,
    bool? discreetMode,
    int? autoLockMinutes,
    String? aliasName,
    bool? notificationsHidden,
    bool? quickExitEnabled,
  }) async {
    state = state.copyWith(
      biometricsEnabled: biometricsEnabled,
      discreetMode: discreetMode,
      autoLockMinutes: autoLockMinutes,
      aliasName: aliasName,
      notificationsHidden: notificationsHidden,
      quickExitEnabled: quickExitEnabled,
    );
    await _persistState();
  }

  void lock() {
    state = state.copyWith(isUnlocked: false, privacyShield: true);
  }

  void showPrivacyShield() {
    state = state.copyWith(privacyShield: true);
  }

  void hidePrivacyShield() {
    state = state.copyWith(privacyShield: false);
  }

  Future<void> resetApp() async {
    await _storage.deleteAll();
    state = AuthStateModel.initial().copyWith(isLoading: false);
  }
}
