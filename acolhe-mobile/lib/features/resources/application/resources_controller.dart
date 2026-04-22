import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final resourcesProvider = Provider<List<ResourceArticleModel>>((ref) {
  return const [
    ResourceArticleModel(
      id: '1',
      slug: 'o-que-pode-caracterizar-assedio',
      category: 'Informacao geral',
      title: 'O que pode caracterizar assedio sexual',
      summary: 'Sinais gerais para refletir sobre comportamentos invasivos, insistentes ou coercitivos.',
      body:
          'Assedio pode envolver comentarios sexuais insistentes, constrangimento, perseguicao, chantagem ou toques sem consentimento. As situacoes variam conforme o contexto e a localidade.',
      ctaLabel: 'Registrar com calma',
    ),
    ResourceArticleModel(
      id: '2',
      slug: 'preservar-evidencias',
      category: 'Protecao',
      title: 'Preservar evidencias com cuidado',
      summary: 'Mensagens, prints, datas, locais e nomes podem ajudar voce a manter um registro pessoal.',
      body:
          'Se for seguro, pode ser util guardar prints, mensagens, datas aproximadas, locais e efeitos percebidos. Isso nao obriga nenhuma denuncia: e um apoio para a sua organizacao pessoal.',
      ctaLabel: 'Abrir registro',
    ),
    ResourceArticleModel(
      id: '3',
      slug: 'apoio-humano',
      category: 'Apoio',
      title: 'Buscar apoio humano qualificado',
      summary: 'Acolhimento inicial nao substitui atendimento psicologico, juridico, medico ou policial.',
      body:
          'Dependendo da sua necessidade, voce pode considerar apoio psicologico, juridico, institucional, medico ou policial. Em risco imediato, procure emergencia local ou uma pessoa de confianca.',
      ctaLabel: 'Ver rede de apoio',
    ),
  ];
});
