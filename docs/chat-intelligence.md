# Chat Intelligence Pipeline

O chat do Acolhe agora usa uma pipeline modular antes de gerar qualquer resposta. O objetivo e reduzir respostas genericas, preservar contexto e adaptar tom, risco e estrategia ao que a pessoa esta vivendo.

## Fluxo

1. Recebe a mensagem do usuario.
2. Carrega historico curto e memoria estruturada salva no `message_metadata`.
3. Classifica o tipo de situacao.
4. Classifica risco com regras heuristicas e contexto.
5. Atualiza a memoria estruturada da conversa.
6. Seleciona o modo de resposta.
7. Monta prompts dinamicos por contexto, risco, situacao e tom.
8. Chama o LLM quando configurado.
9. Valida a resposta final.
10. Salva resposta, memoria, risco, tipo de situacao e modo usado.

## Servicos

- `conversation_memory_service.py`: mantem memoria de curto prazo, memoria estruturada e resumo progressivo.
- `situation_classifier_service.py`: identifica tipos como duvida sobre assedio, medo de reencontro, registro, stalking, denuncia ambivalente e crise emocional.
- `risk_assessment_service.py`: calcula risco `low`, `moderate`, `high` ou `critical`, com score, gatilhos e modo recomendado.
- `tone_selector_service.py`: escolhe `calm_support`, `structured_guidance`, `safety_first`, `decision_support` ou `grounding_mode`.
- `prompt_builder_service.py`: compoe prompts dinamicos com memoria, risco, tipo de situacao e modo de resposta.
- `response_validator_service.py`: evita resposta repetitiva, generica, longa demais em risco, falsa autoridade e minimizacao.
- `response_orchestrator_service.py`: coordena toda a pipeline.

## Memoria Estruturada

Campos principais:

- `user_emotional_state`
- `current_risk_level`
- `current_situation_type`
- `aggressor_relation`
- `repeated_behavior`
- `immediate_fear`
- `support_network_status`
- `wants_to_report`
- `evidence_status`
- `conversation_goal`
- `last_summary`
- `response_mode`
- `known_facts`

Hoje a memoria e salva no metadata da mensagem da assistente para evitar migracao de banco no MVP. Em producao, ela pode virar tabela propria ou campo JSON versionado em `Conversation`.

## Response Modes

- `calm_support`: acolhimento calmo para tristeza, duvida, vergonha ou inseguranca.
- `structured_guidance`: orientacao clara para organizar fatos ou entender a situacao.
- `safety_first`: resposta curta e direta quando ha risco alto, critico, reencontro ou perseguicao.
- `decision_support`: suporte sem pressao para decidir sobre denuncia, falar com alguem ou agir.
- `grounding_mode`: frases simples para crise emocional, panico ou desorganizacao.

## Testes

Cobertura adicionada:

- classificacao de situacao com comportamento recorrente;
- escalonamento de risco em medo de reencontro;
- selecao de tom para ambivalencia de denuncia;
- atualizacao de memoria estruturada;
- fluxo principal do chat com campos de contexto.
