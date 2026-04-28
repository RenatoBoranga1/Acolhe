# Arquitetura

## Visao geral

O `Acolhe` foi desenhado para separar claramente:

- experiencia mobile e armazenamento local protegido;
- autenticacao local e preferencias de discricao;
- API de dominio e persistencia estruturada;
- orquestracao de IA;
- classificacao de risco deterministica antes da resposta.

## Mobile Flutter

### Camadas

- `core/`
  - configuracao, tema, router e armazenamento seguro
- `shared/`
  - modelos e componentes reutilizaveis
- `features/auth/`
  - onboarding, PIN, biometria, bloqueio e modo discreto
- `features/chat/`
  - chat, historico local, risco e fallback de IA
- `features/journal/`
  - registro privado e resumo cronologico
- `features/safety_plan/`
  - plano de seguranca
- `features/support_network/`
  - contatos confiaveis
- `features/resources/`
  - conteudo educativo
- `features/settings/`
  - privacidade, limpeza rapida, auto-bloqueio

### Decisoes de UX

- cards amplos, poucos elementos por tela e linguagem contida;
- foco em leitura confortavel, contraste e acoes grandes;
- modo discreto mantem a interface mais neutra, sem trocar o nome do app;
- quick exit leva a uma tela neutra e ativa escudo de privacidade.

## Backend FastAPI

### Camadas

- `api/`
  - composicao de rotas
- `core/`
  - configuracao, banco, seguranca, logs e rate limit
- `models/`
  - entidades SQLAlchemy
- `modules/`
  - rotas, schemas e servicos por dominio
- `repositories/`
  - acesso a dados
- `integrations/llm/`
  - cliente LLM isolado
- `services/seed.py`
  - dados mock iniciais

### Dominios

- `auth`
- `chat`
- `risk`
- `journal`
- `safety_plan`
- `support_network`
- `resources`
- `settings`

## Fluxo do chat

1. usuaria envia mensagem
2. backend carrega historico curto e memoria estruturada
3. classificador identifica o tipo de situacao
4. classificador de risco calcula nivel, score e gatilhos
5. memoria da conversa e atualizada
6. seletor de tom define o modo de resposta
7. prompt builder monta prompts dinamicos
8. orquestrador chama LLM ou fallback seguro
9. validador bloqueia resposta generica, repetitiva, insegura ou longa demais
10. resposta, memoria, risco e modo sao salvos

Detalhes da pipeline em [chat-intelligence.md](./chat-intelligence.md).

## Persistencia

### Mobile

- `flutter_secure_storage` para dados sensiveis locais
- pronto para trocar JSON por banco local criptografado se o produto evoluir

### Backend

- `SQLAlchemy` + `Alembic`
- modelo inicial com:
  - `User`
  - `Conversation`
  - `Message`
  - `IncidentRecord`
  - `SafetyPlan`
  - `TrustedContact`
  - `ResourceArticle`
  - `AppSetting`
  - `RiskAssessment`

## Privacidade e seguranca

- nao logar conversa integral no backend
- nao exibir traces sensiveis ao cliente
- preparar criptografia em repouso no banco
- manter conteudo educativo desacoplado da logica de chat
- tratar IA como assistente de acolhimento inicial, nunca como profissional humano
