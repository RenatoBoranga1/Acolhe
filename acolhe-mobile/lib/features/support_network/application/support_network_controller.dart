import 'dart:async';

import 'package:acolhe_mobile/core/storage/secure_storage_service.dart';
import 'package:acolhe_mobile/core/storage/storage_keys.dart';
import 'package:acolhe_mobile/features/auth/application/auth_controller.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supportNetworkControllerProvider =
    StateNotifierProvider<SupportNetworkController, List<TrustedContactModel>>(
        (ref) {
  return SupportNetworkController(ref.read(secureStorageProvider));
});

class SupportNetworkController
    extends StateNotifier<List<TrustedContactModel>> {
  SupportNetworkController(this._storage)
      : super(
          const [
            TrustedContactModel(
              id: 'camila',
              name: 'Camila Andrade',
              relationship: 'Amiga',
              phone: '+55 11 99999-1001',
              email: 'camila@example.com',
              priority: 1,
              readyMessage:
                  'Oi, preciso do seu apoio. Passei por uma situacao dificil e gostaria de conversar com voce.',
            ),
            TrustedContactModel(
              id: 'luciana',
              name: 'Luciana Reis',
              relationship: 'Irma',
              phone: '+55 11 98888-2211',
              email: 'luciana@example.com',
              priority: 2,
              readyMessage:
                  'Oi, queria te pedir ajuda hoje. Estou abalada e gostaria de ficar perto de alguem de confianca.',
            ),
          ],
        ) {
    unawaited(load());
  }

  final SecureStorageService _storage;

  Future<void> load() async {
    final stored = await _storage.readList(StorageKeys.contacts);
    if (stored.isNotEmpty) {
      state = stored.map((item) => TrustedContactModel.fromJson(item)).toList();
    }
  }

  Future<void> addContact(TrustedContactModel value) async {
    state = [...state, value];
    await _storage.writeList(
        StorageKeys.contacts, state.map((item) => item.toJson()).toList());
  }
}
