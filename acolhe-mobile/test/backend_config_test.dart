import 'package:acolhe_mobile/core/config/api_config.dart';
import 'package:acolhe_mobile/core/config/environment_service.dart';
import 'package:acolhe_mobile/core/storage/secure_storage_service.dart';
import 'package:acolhe_mobile/core/storage/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('manual override is validated and activated automatically', () async {
    final storage = _MemorySecureStorage(
      strings: {StorageKeys.apiBaseUrl: 'http://192.168.0.15:8000'},
    );
    final client = MockClient((request) async {
      if (request.url.toString() == 'http://192.168.0.15:8000/health') {
        return http.Response('{"status":"ok"}', 200);
      }
      return http.Response('{"status":"unavailable"}', 503);
    });

    final controller = BackendConfigController(
      storage,
      client,
      allowLocalNetworkScan: false,
    );
    addTearDown(controller.dispose);

    await _waitForDiscovery(controller);

    expect(controller.state.usesRemoteApi, isTrue);
    expect(controller.state.effectiveBaseUrl, 'http://192.168.0.15:8000');
    expect(controller.state.source, ApiEndpointSource.manualOverride);
    expect(
      controller.state.connectionState,
      BackendConnectionState.connected,
    );
  });

  test('cached discovery is reused when still healthy', () async {
    final storage = _MemorySecureStorage(
      strings: {
        StorageKeys.apiDiscoveredBaseUrl: 'http://192.168.0.44:8000',
        StorageKeys.apiLastSubnetPrefix: '192.168.0',
      },
    );
    final client = MockClient((request) async {
      if (request.url.toString() == 'http://192.168.0.44:8000/health') {
        return http.Response('{"status":"ok"}', 200);
      }
      return http.Response('{"status":"unavailable"}', 503);
    });

    final controller = BackendConfigController(
      storage,
      client,
      allowLocalNetworkScan: false,
    );
    addTearDown(controller.dispose);

    await _waitForDiscovery(controller);

    expect(controller.state.usesRemoteApi, isTrue);
    expect(controller.state.effectiveBaseUrl, 'http://192.168.0.44:8000');
    expect(controller.state.source, ApiEndpointSource.cachedDiscovery);
    expect(controller.state.lastSubnetPrefix, '192.168.0');
  });
}

Future<void> _waitForDiscovery(BackendConfigController controller) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    if (!controller.state.isLoading && !controller.state.isDiscovering) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  fail('Backend discovery did not finish within the expected time.');
}

class _MemorySecureStorage extends SecureStorageService {
  _MemorySecureStorage({
    Map<String, String>? strings,
  }) : _strings = Map<String, String>.from(strings ?? const {});

  final Map<String, String> _strings;

  @override
  Future<String?> readString(String key) async => _strings[key];

  @override
  Future<void> writeString(String key, String value) async {
    _strings[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _strings.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _strings.clear();
  }
}
