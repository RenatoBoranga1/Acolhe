import 'dart:async';

import 'package:acolhe_mobile/core/config/app_environment.dart';
import 'package:acolhe_mobile/core/storage/secure_storage_service.dart';
import 'package:acolhe_mobile/core/storage/storage_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackendConfigState {
  const BackendConfigState({
    required this.isLoading,
    required this.overrideUrl,
  });

  final bool isLoading;
  final String overrideUrl;

  String get customBaseUrl => overrideUrl.trim();

  String get effectiveBaseUrl {
    if (customBaseUrl.isNotEmpty) {
      return customBaseUrl;
    }
    return AppEnvironment.apiBaseUrl.trim();
  }

  bool get usesCustomUrl => customBaseUrl.isNotEmpty;
  bool get usesBundledUrl =>
      !usesCustomUrl && AppEnvironment.apiBaseUrl.trim().isNotEmpty;
  bool get usesRemoteApi => effectiveBaseUrl.isNotEmpty;

  bool get pointsToLoopbackHost {
    final candidate = effectiveBaseUrl;
    if (candidate.isEmpty) {
      return false;
    }
    final normalized =
        candidate.startsWith('http') ? candidate : 'http://$candidate';
    final host = Uri.tryParse(normalized)?.host.toLowerCase() ?? '';
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '0.0.0.0' ||
        host == '::1';
  }

  BackendConfigState copyWith({
    bool? isLoading,
    String? overrideUrl,
  }) {
    return BackendConfigState(
      isLoading: isLoading ?? this.isLoading,
      overrideUrl: overrideUrl ?? this.overrideUrl,
    );
  }

  factory BackendConfigState.initial() =>
      const BackendConfigState(isLoading: true, overrideUrl: '');
}

final backendConfigProvider =
    StateNotifierProvider<BackendConfigController, BackendConfigState>((ref) {
  return BackendConfigController(ref.read(secureStorageProvider));
});

class BackendConfigController extends StateNotifier<BackendConfigState> {
  BackendConfigController(this._storage) : super(BackendConfigState.initial()) {
    unawaited(load());
  }

  final SecureStorageService _storage;

  Future<void> load() async {
    final stored = await _storage.readString(StorageKeys.apiBaseUrl);
    state = state.copyWith(
      isLoading: false,
      overrideUrl: _normalizeUrl(stored ?? ''),
    );
  }

  Future<void> saveOverride(String value) async {
    final normalized = _normalizeUrl(value);
    if (normalized.isEmpty) {
      await _storage.delete(StorageKeys.apiBaseUrl);
    } else {
      await _storage.writeString(StorageKeys.apiBaseUrl, normalized);
    }
    state = state.copyWith(isLoading: false, overrideUrl: normalized);
  }

  Future<void> clearOverride() => saveOverride('');

  static String _normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final withScheme =
        RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed)
            ? trimmed
            : 'http://$trimmed';
    return withScheme.replaceAll(RegExp(r'/+$'), '');
  }
}
