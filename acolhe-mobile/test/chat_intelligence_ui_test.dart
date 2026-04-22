import 'package:acolhe_mobile/features/chat/domain/chat_intelligence_ui.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps backend situation aliases into adaptive UI situations', () {
    expect(
      ChatSituationKindX.fromBackend('incident_record'),
      ChatSituationKind.incidentRecord,
    );
    expect(
      ChatSituationKindX.fromBackend('pedido de apoio'),
      ChatSituationKind.supportRequest,
    );
    expect(
      ChatSituationKindX.fromBackend('medo_de_reencontro'),
      ChatSituationKind.fearOfReencounter,
    );
  });

  test('routes backend ctas to the right product areas', () {
    expect(ChatCtaIntent.fromLabel('Abrir plano de seguranca').route,
        '/safety-plan');
    expect(ChatCtaIntent.fromLabel('Gerar resumo cronologico').route,
        '/incident-record');
    expect(ChatCtaIntent.fromLabel('Contatar pessoa de confianca').route,
        '/support-network');
    expect(
        ChatCtaIntent.fromLabel('Ligar para emergencia').route, '/urgent-help');
  });

  test('high risk receives priority UI treatment', () {
    const risk = RiskAssessment(
      level: RiskLevel.high,
      score: 8,
      reasons: ['ameaca atual'],
      actions: ['buscar local seguro'],
      requiresImmediateAction: true,
    );

    expect(chatRiskNeedsPriority(risk), isTrue);
  });
}
