import 'package:acolhe_mobile/main.dart';
import 'package:acolhe_mobile/core/storage/secure_storage_service.dart';
import 'package:acolhe_mobile/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app bootstraps', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorageService()),
        ],
        child: const AcolheApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.textContaining('Acolhe'), findsAny);
  });
}

class _FakeSecureStorageService extends SecureStorageService {
  _FakeSecureStorageService();

  @override
  Future<String?> readString(String key) async => null;

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => null;

  @override
  Future<List<Map<String, dynamic>>> readList(String key) async => [];

  @override
  Future<void> writeString(String key, String value) async {}

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {}

  @override
  Future<void> writeList(String key, List<Map<String, dynamic>> value) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}
}
