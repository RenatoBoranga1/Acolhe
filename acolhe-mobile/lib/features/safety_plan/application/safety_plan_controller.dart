import 'dart:async';

import 'package:acolhe_mobile/core/storage/secure_storage_service.dart';
import 'package:acolhe_mobile/core/storage/storage_keys.dart';
import 'package:acolhe_mobile/features/auth/application/auth_controller.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final safetyPlanControllerProvider =
    StateNotifierProvider<SafetyPlanController, SafetyPlanModel>((ref) {
  return SafetyPlanController(ref.read(secureStorageProvider));
});

class SafetyPlanController extends StateNotifier<SafetyPlanModel> {
  SafetyPlanController(this._storage)
      : super(
          const SafetyPlanModel(
            safeLocations: ['Casa da Camila', 'Recepcao do predio'],
            warningSigns: ['Mensagens insistentes', 'Esperar na saida'],
            immediateSteps: [
              'Ir para um local movimentado',
              'Ligar para uma pessoa de confianca'
            ],
            priorityContacts: ['Camila Andrade', 'Luciana Reis'],
            personalNotes:
                'Se eu travar, posso enviar a mensagem pronta sem explicar tudo.',
            emergencyChecklist: ['Celular carregado', 'Rota alternativa salva'],
          ),
        ) {
    unawaited(load());
  }

  final SecureStorageService _storage;

  Future<void> load() async {
    final stored = await _storage.readMap(StorageKeys.safetyPlan);
    if (stored != null) {
      state = SafetyPlanModel.fromJson(stored);
    }
  }

  Future<void> save(SafetyPlanModel value) async {
    state = value;
    await _storage.writeMap(StorageKeys.safetyPlan, value.toJson());
  }
}
