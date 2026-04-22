import 'package:acolhe_mobile/features/chat/data/chat_dtos.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat response dto maps backend payload into domain models', () {
    final dto = ChatMessageResponseDto.fromJson({
      'conversation_id': 'conversation-1',
      'assistant_message': {
        'id': 'message-2',
        'role': 'assistant',
        'content': 'Vamos por partes, com cuidado.',
        'risk_level': 'moderate',
        'created_at': '2026-04-22T12:00:00Z',
      },
      'risk': {
        'level': 'moderate',
        'score': 3,
        'reasons': ['medo imediato'],
        'recommended_actions': ['Organizar fatos'],
        'requires_immediate_action': false,
      },
      'ctas': ['Registrar o que aconteceu'],
      'suggestions': ['Quero pensar nos proximos passos'],
      'response_mode': 'structured_guidance',
      'situation_type': 'duvida_se_foi_assedio',
      'conversation_context': {'emotional_state': 'confusa'},
    });

    final result = dto.toDomain();

    expect(result.conversationId, 'conversation-1');
    expect(result.assistantMessage.role, MessageRole.assistant);
    expect(result.assistantMessage.riskLevel, RiskLevel.moderate);
    expect(result.risk.level, RiskLevel.moderate);
    expect(result.ctas, contains('Registrar o que aconteceu'));
    expect(result.responseMode, 'structured_guidance');
    expect(result.situationType, 'duvida_se_foi_assedio');
    expect(result.conversationContext?['emotional_state'], 'confusa');
  });
}
