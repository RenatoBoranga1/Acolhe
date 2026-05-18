# Acolhe

Aplicativo mobile e backend de apoio inicial seguro para pessoas que possam estar vivendo ou tenham vivido situacoes de assedio. O projeto combina um app Flutter com um backend FastAPI e uma pipeline conversacional orientada por risco, memoria contextual e principios trauma-informed.

## Visao do produto

O Acolhe foi desenhado para oferecer:

- acolhimento inicial sem julgamento;
- organizacao segura de fatos e proximos passos;
- triagem de risco com priorizacao de seguranca;
- historico privado com cache local seguro;
- UX discreta, responsiva e preparada para celular, tablet e web.

Importante:

- a assistente virtual nao substitui apoio psicologico, juridico, medico, social ou policial;
- o produto nao deve ser usado como fonte unica em situacoes de risco iminente;
- em emergencia, a orientacao correta e procurar ajuda humana imediata e servicos locais.

## Stack

### Mobile

- Flutter
- Dart
- Riverpod
- go_router
- flutter_secure_storage
- local_auth

### Backend

- Python 3.11+
- FastAPI
- Pydantic
- SQLAlchemy
- Alembic
- PostgreSQL

### IA e seguranca conversacional

- orquestracao isolada de LLM
- memoria conversacional estruturada
- classificacao de situacao e risco
- validacao de resposta
- fallback deterministico seguro

### Infra

- Docker
- docker-compose
- Render-ready deployment
- testes automatizados para backend e mobile

## Estrutura do repositorio

```text
Acolhe/
|-- acolhe-backend/
|   |-- app/
|   |-- alembic/
|   |-- scripts/
|   |-- tests/
|   `-- pyproject.toml
|-- acolhe-mobile/
|   |-- lib/
|   |-- test/
|   `-- pubspec.yaml
|-- docs/
|   |-- architecture.md
|   |-- chat-intelligence.md
|   |-- android-studio-run.md
|   |-- render-deploy.md
|   `-- roadmap.md
|-- .env.example
|-- docker-compose.yml
|-- setup-mobile.ps1
|-- start-backend.ps1
`-- run-tablet.ps1
```

## Funcionalidades principais

- autenticacao local por PIN com suporte a biometria;
- chat principal com historico, retry e fallback seguro;
- classificacao de risco em baixo, moderado, alto e critico;
- CTAs dinamicos para ajuda urgente, plano de seguranca e rede de apoio;
- registro privado do ocorrido com resumo cronologico;
- plano de seguranca e contatos confiaveis;
- conteudo educativo em formato pronto para evolucao por pais/regiao;
- configuracoes de privacidade, limpeza local e modo discreto.

## Arquitetura em alto nivel

### Mobile

- `core/`: configuracao, tema, storage e utilitarios globais;
- `shared/`: modelos, design system e componentes responsivos;
- `features/auth/`: PIN, biometria e fluxo de acesso;
- `features/chat/`: controller, repository, API client, widgets e experiencia principal;
- `features/journal/`, `safety_plan/`, `support_network/`, `resources/`, `settings/`: modulos auxiliares.

### Backend

- `app/api/`: agregacao de rotas;
- `app/modules/`: dominio por funcionalidade;
- `app/repositories/`: acesso a dados;
- `app/integrations/llm/`: gateway para modelo;
- `app/core/`: config, banco, logging e rate limiting;
- `app/services/`: seed e servicos transversais.

Mais detalhes em [docs/architecture.md](./docs/architecture.md) e [docs/chat-intelligence.md](./docs/chat-intelligence.md).

## API principal

### Autenticacao

- `POST /api/v1/auth/pin/setup`
- `POST /api/v1/auth/pin/verify`
- `GET /api/v1/auth/status`

### Chat

- `GET /api/v1/chat/conversations`
- `GET /api/v1/chat/conversations/{id}`
- `POST /api/v1/chat/conversations`
- `PATCH /api/v1/chat/conversations/{id}`
- `DELETE /api/v1/chat/conversations/{id}`
- `GET /api/v1/chat/conversations/{id}/messages?page=1&page_size=40`
- `POST /api/v1/chat/message`
- `POST /api/v1/chat/messages/{id}/feedback`

### Outros modulos

- `POST /api/v1/incident-records`
- `POST /api/v1/incident-records/{id}/summary`
- `GET /api/v1/trusted-contacts`
- `POST /api/v1/trusted-contacts`
- `GET /api/v1/resources`
- `GET /api/v1/safety-plan`
- `POST /api/v1/safety-plan`
- `GET /api/v1/settings`
- `POST /api/v1/settings`

## Variaveis de ambiente

Use [`.env.example`](./.env.example) como base.

Chaves importantes:

- `DATABASE_URL`
- `CORS_ORIGINS`
- `PRIMARY_USER_PIN`
- `LLM_ENABLED`
- `LLM_API_KEY`
- `LLM_MODEL`
- `LLM_TEMPERATURE_DEFAULT`
- `LLM_TEMPERATURE_MODERATE`
- `LLM_TEMPERATURE_HIGH`
- `LLM_TEMPERATURE_CRITICAL`

## Como rodar

### Windows: backend local

```powershell
cd acolhe-backend
Copy-Item ..\.env.example .env
powershell -ExecutionPolicy Bypass -File ..\start-backend.ps1
```

API esperada em:

```text
http://127.0.0.1:8000
```

Healthcheck:

```text
http://127.0.0.1:8000/health
```

### Docker: backend + Postgres

```powershell
docker compose up --build
```

Nesse modo, o `docker-compose.yml` ja injeta a configuracao de banco adequada.

### Flutter: dependencias e execucao

Preparacao do workspace:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-mobile.ps1
```

Listar dispositivos:

```powershell
powershell -ExecutionPolicy Bypass -File .\flutter-local.ps1 devices
```

Rodar no Android:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-tablet.ps1 -DeviceId SEU_DEVICE_ID
```

Rodar apontando para backend local na mesma rede:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-tablet.ps1 -DeviceId SEU_DEVICE_ID -ApiBaseUrl http://SEU_IP_LOCAL:8000
```

Observacoes:

- nao use `localhost` dentro do celular fisico;
- use o IP local do computador na mesma rede Wi-Fi;
- para Android Studio com botao `Run`, veja [docs/android-studio-run.md](./docs/android-studio-run.md).

## Integracao mobile com backend

Quando `API_BASE_URL` estiver configurado, o app passa a usar o backend real como fluxo principal para:

- listar conversas;
- obter conversa individual;
- criar, renomear e excluir conversa;
- enviar mensagem;
- paginar historico;
- receber risco, CTAs, tipo de situacao, modo de resposta e contexto.

Se a API estiver indisponivel:

- o app mantem cache local seguro;
- o chat usa fallback local seguro apenas quando necessario;
- o controller expõe status de sincronizacao e retry amigavel.

## Qualidade e validacao

### Backend

```powershell
cd acolhe-backend
python -m pytest -q
```

### Mobile

```powershell
cd acolhe-mobile
flutter test
```

### Formatacao

Backend:

```powershell
cd acolhe-backend
python -m black .
python -m ruff check . --fix
```

Mobile:

```powershell
cd acolhe-mobile
dart format .
```

## Seguranca e privacidade

- cache local sensivel protegido por `flutter_secure_storage`;
- PIN armazenado como hash no backend;
- modo discreto e controles de exposicao na interface;
- ownership de conversas garantido no backend pelo usuario corrente;
- preparacao para autenticacao real por usuario via camada de contexto;
- rate limiting aplicado no backend;
- logs tecnicos sem payload integral de mensagens sensiveis;
- feedback de respostas armazenado sem expor conteudo da conversa em logs.

## Deploy

O backend esta preparado para Render.

Arquivos relevantes:

- [render.yaml](./render.yaml)
- [docs/render-deploy.md](./docs/render-deploy.md)
- [acolhe-backend/scripts/render-start.sh](./acolhe-backend/scripts/render-start.sh)

## Como contribuir

1. Abra uma issue com contexto claro do problema ou melhoria.
2. Trabalhe em branch propria.
3. Mantenha mudancas pequenas e com testes quando possivel.
4. Rode formatacao e testes antes de abrir PR.
5. Evite incluir dados sensiveis, chaves reais ou caminhos locais da sua maquina.

Boas praticas esperadas:

- commits objetivos;
- codigo legivel e modular;
- textos responsaveis do ponto de vista etico;
- nenhuma funcionalidade deve incentivar exposicao desnecessaria de relatos.

## Limitacoes e responsabilidade etica

Este repositorio nao deve ser interpretado como ferramenta clinica, juridica ou policial.

Limitacoes atuais:

- nao substitui atendimento humano especializado;
- a autenticacao ainda esta em transicao para um modelo completo por usuario;
- o produto depende de configuracao responsavel de infraestrutura, TLS e segredo de ambiente para uso publico;
- respostas de IA continuam sujeitas a validacao, fallback e supervisao de produto.

Responsabilidade etica:

- nao usar o sistema para extrair relatos sensiveis sem consentimento;
- nao prometer sigilo absoluto em cenarios de risco de vida;
- sempre priorizar seguranca fisica e emocional acima de completude conversacional;
- revisar qualquer expansao de produto com enfoque de privacidade por padrao.

## Roadmap

Resumo do proximo ciclo:

- autenticacao real por usuario e sessao;
- deploy publico estavel com Postgres dedicado;
- multilanguage e conteudo por regiao;
- voz e acessibilidade ampliada;
- exportacao segura de relato;
- painel administrativo para conteudo educativo;
- observabilidade privacy-first.

Detalhes em [docs/roadmap.md](./docs/roadmap.md).
