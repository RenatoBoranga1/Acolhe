import 'dart:async';

import 'package:acolhe_mobile/core/storage/secure_storage_service.dart';
import 'package:acolhe_mobile/core/storage/storage_keys.dart';
import 'package:acolhe_mobile/features/auth/application/auth_controller.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedIncidentSummaryProvider = StateProvider<IncidentRecordModel?>((ref) => null);

final journalControllerProvider =
    StateNotifierProvider<JournalController, List<IncidentRecordModel>>((ref) {
  return JournalController(ref.read(secureStorageProvider));
});

class JournalController extends StateNotifier<List<IncidentRecordModel>> {
  JournalController(this._storage) : super(const []) {
    unawaited(load());
  }

  final SecureStorageService _storage;

  Future<void> load() async {
    final stored = await _storage.readList(StorageKeys.journalState);
    state = stored.map((item) => IncidentRecordModel.fromJson(item)).toList();
  }

  Future<void> persist() =>
      _storage.writeList(StorageKeys.journalState, state.map((item) => item.toJson()).toList());

  Future<void> saveRecord(IncidentRecordModel record) async {
    state = [record, ...state];
    await persist();
  }

  Future<IncidentRecordModel> generateSummary(IncidentRecordModel record) async {
    final summary = [
      if (record.occurredOn.isNotEmpty) 'Data aproximada: ${record.occurredOn}.',
      if (record.occurredAt.isNotEmpty) 'Horario aproximado: ${record.occurredAt}.',
      if (record.location.isNotEmpty) 'Local: ${record.location}.',
      'Descricao principal: ${record.description}.',
      if (record.peopleInvolved.isNotEmpty) 'Pessoas envolvidas: ${prettyJoin(record.peopleInvolved)}.',
      if (record.witnesses.isNotEmpty) 'Testemunhas: ${prettyJoin(record.witnesses)}.',
      if (record.perceivedImpacts.isNotEmpty)
        'Impactos percebidos: ${prettyJoin(record.perceivedImpacts)}.',
      if (record.observations.isNotEmpty) 'Observacoes: ${record.observations}.',
    ].join(' ');

    final updated = record.copyWith(summary: summary);
    state = [
      updated,
      ...state.where((item) => item.id != record.id),
    ];
    await persist();
    return updated;
  }
}
