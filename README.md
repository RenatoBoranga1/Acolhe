# Acolhe

`Acolhe` e um MVP serio de produto social com foco em apoio inicial, organizacao segura de fatos, privacidade e linguagem trauma-informed para pessoas que possam estar vivendo ou tenham vivido assedio sexual.

## Stack

- Mobile: `Flutter`, `Dart`, `Riverpod`, `go_router`, `flutter_secure_storage`, `local_auth`
- Backend: `Python`, `FastAPI`, `Pydantic`, `SQLAlchemy`, `Alembic`
- Banco: `PostgreSQL` em `docker-compose`, com `SQLite` apenas como fallback local para desenvolvimento/testes
- IA: gateway isolado para LLM com system prompt robusto e fallback deterministico seguro
- Infra: `Docker`, `docker-compose`, `.env`, logs seguros e testes basicos

## O que ja esta implementado

- app Flutter com arquitetura por `core`, `shared` e `features`
- onboarding com ativacao de modo discreto e biometria
- autenticacao local por PIN
- chat principal em estilo app de IA com sidebar/drawer, historico persistido, renomear/excluir conversa, sugestoes rapidas, retry e input fixo
- tela de ajuda urgente
- registro privado do ocorrido + resumo cronologico rotulado como rascunho pessoal
- plano de seguranca
- rede de apoio com mensagem pronta
- informacoes e direitos em mock local
- configuracoes de privacidade
- backend funcional com rotas REST, seed mock, risco, PIN, journal, support network, resources e settings
- testes do backend cobrindo autenticacao, chat, risco, journal e contatos

## Estrutura

```text
Acolhe/
├── acolhe-backend/
│   ├── app/
│   │   ├── api/
│   │   ├── core/
│   │   ├── integrations/llm/
│   │   ├── models/
│   │   ├── modules/
│   │   ├── prompts/
│   │   ├── repositories/
│   │   ├── schemas/
│   │   └── services/
│   ├── alembic/
│   ├── tests/
│   ├── Dockerfile
│   └── pyproject.toml
├── acolhe-mobile/
│   ├── lib/
│   │   ├── core/
│   │   ├── features/
│   │   └── shared/
│   ├── test/
│   └── pubspec.yaml
├── docs/
│   ├── architecture.md
│   └── roadmap.md
├── .env.example
└── docker-compose.yml
```

## Arquitetura mobile adotada

O `Acolhe` atual usa `Flutter + Riverpod + go_router`, entao a estrategia adotada foi evoluir a base existente para um fluxo `chat-first`, sem trocar de stack.

Principais decisoes:

- manter a persistencia sensivel no aparelho com `flutter_secure_storage`;
- tratar o chat como workspace principal autenticado;
- salvar a sessao do chat com conversa ativa + historico;
- preservar os modulos existentes como areas auxiliares acessiveis por navegacao lateral;
- reforcar o design system para um visual de aplicativo de IA mais premium e consistente.

## Execucao local

### 1. Backend

Nesta maquina, use o Python embutido do workspace:

```bash
cd acolhe-backend
copy ..\\.env.example .env
..\start-backend.ps1
```

Ou, se preferir o comando direto:

```bash
cd acolhe-backend
& "C:\Users\USER\Documents\Playground\tools\python-3.11.9-embed-amd64\python.exe" -m uvicorn app.main:app --reload
```

Ou pelo script, que neste ambiente sobe sem `reload` por padrao:

```bash
powershell -ExecutionPolicy Bypass -File .\start-backend.ps1
```

Para rodar testes:

```bash
powershell -ExecutionPolicy Bypass -File .\test-backend.ps1
```

### 2. Backend com Docker

```bash
docker compose up --build
```

Observacao: nesta maquina o comando `docker` nao esta instalado no `PATH`. Se quiser, eu posso te ajudar a preparar a instalacao depois.

### 3. Mobile Flutter

O projeto agora usa um `Flutter` local compartilhado no workspace, detectado automaticamente pelos scripts, entao voce nao precisa instalar o comando globalmente para comecar.

Da raiz do projeto:

```bash
powershell -ExecutionPolicy Bypass -File .\setup-mobile.ps1
```

Para listar aparelhos:

```bash
powershell -ExecutionPolicy Bypass -File .\flutter-local.ps1 devices
```

Para rodar em um tablet Android fisico:

```bash
powershell -ExecutionPolicy Bypass -File .\run-tablet.ps1 -DeviceId SEU_DEVICE_ID
```

Sem `ApiBaseUrl`, o app sobe em modo demonstracao com dados mock locais.
Se quiser apontar o tablet para o backend rodando no computador, use o IP local da sua maquina na mesma rede:

```bash
powershell -ExecutionPolicy Bypass -File .\run-tablet.ps1 -DeviceId SEU_DEVICE_ID -ApiBaseUrl http://SEU_IP_LOCAL:8000
```

Importante: `SEU_DEVICE_ID` e `SEU_IP_LOCAL` sao exemplos. Nao use os caracteres `<` e `>` no PowerShell.

Para usar especificamente o botao `Run` do Android Studio, veja [docs/android-studio-run.md](./docs/android-studio-run.md).

Para entender a nova pipeline inteligente do chat, veja [docs/chat-intelligence.md](./docs/chat-intelligence.md).

Se quiser checar rapidamente o que falta no ambiente:

```bash
powershell -ExecutionPolicy Bypass -File .\check-prereqs.ps1
```

## Variaveis de ambiente

Veja [`.env.example`](./.env.example).

Principais chaves:

- `DATABASE_URL`
- `LLM_ENABLED`
- `LLM_API_KEY`
- `LLM_BASE_URL`
- `LLM_MODEL`
- `PRIMARY_USER_PIN`

## Rotas principais da API

- `POST /api/v1/auth/pin/setup`
- `POST /api/v1/auth/pin/verify`
- `GET /api/v1/auth/status`
- `POST /api/v1/chat/message`
- `POST /api/v1/chat/risk-assessment`
- `GET /api/v1/chat/conversations`
- `POST /api/v1/incident-records`
- `POST /api/v1/incident-records/{id}/summary`
- `GET /api/v1/trusted-contacts`
- `POST /api/v1/trusted-contacts`
- `GET /api/v1/resources`
- `GET/POST /api/v1/safety-plan`
- `GET/POST /api/v1/settings`
- `GET /api/v1/settings/export`
- `DELETE /api/v1/settings/purge`

## Seguranca e privacidade

- PIN local protegido por hash e armazenamento seguro no mobile
- dados sensiveis armazenados localmente via `flutter_secure_storage`
- biometria opcional
- modo discreto com nome alternativo na interface
- tela neutra de privacidade e saida rapida
- classificador de risco antes da resposta da IA
- logs do backend sem payload sensivel
- sistema preparado para TLS, criptografia em repouso e evolucao com rate limit/cache

## Testes executados

Backend:

```bash
python -m pytest -q
```

Resultado nesta workspace: `5 passed`.

## Limitacoes honestas desta entrega

- o backend foi validado com testes automatizados;
- o app Flutter foi implementado de forma concreta, com SDK local incluido no workspace, mas eu nao consegui validar `flutter run` neste sandbox;
- o projeto mobile esta preparado para bootstrap local com `setup-mobile.ps1` e execucao no tablet com `run-tablet.ps1`.

## Decisoes tecnicas importantes

- risco alto/critico interrompe o fluxo conversacional e prioriza CTAs de seguranca;
- LLM fica atras de uma camada de orquestracao para permitir fallback seguro, auditoria e evolucao;
- conteudos educativos ficam separados e prontos para migrar para CMS/API por regiao;
- `SQLite` existe apenas para desenvolvimento rapido e testes locais; o alvo operacional do backend e `PostgreSQL`.

## Roadmap

Veja [docs/roadmap.md](./docs/roadmap.md).
