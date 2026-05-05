# Deploy no Render

Este projeto foi preparado para subir o backend do `Acolhe` no Render com:

- `FastAPI` como `Web Service`;
- `Render Postgres` como banco gerenciado;
- `render.yaml` na raiz do repositorio;
- migracoes executadas no startup via `alembic upgrade head`;
- `health check` em `/health`.

## Arquivos usados no deploy

- [render.yaml](../render.yaml)
- [acolhe-backend/scripts/render-start.sh](../acolhe-backend/scripts/render-start.sh)
- [acolhe-backend/.python-version](../acolhe-backend/.python-version)

## Antes de criar o deploy

1. Suba este repositorio no GitHub.
2. Entre no Render Dashboard.
3. Escolha `New` > `Blueprint`.
4. Selecione o repositorio `Acolhe`.

O Render vai ler o `render.yaml` e propor:

- um web service chamado `acolhe-api`;
- um Postgres chamado `acolhe-db`.

## Variaveis importantes

Durante a criacao do Blueprint, preencha com cuidado:

- `PRIMARY_USER_PIN`
- `CORS_ORIGINS`
- `LLM_API_KEY`:
  Preencha apenas se voce realmente for habilitar `LLM_ENABLED=true`.

Valores ja definidos no Blueprint:

- `ENVIRONMENT=production`
- `DEBUG=false`
- `SEED_DEMO_DATA=false`
- `DATABASE_URL` vindo automaticamente do `acolhe-db`

## CORS

Para app Flutter Android/iOS, `CORS` nao afeta o app nativo.

Ele importa principalmente se voce for expor uma versao web do cliente.

Exemplo:

```text
http://localhost:3000,https://seu-frontend.onrender.com
```

## Planos

O `render.yaml` usa `free` por padrao para facilitar teste inicial.

Importante:

- o proprio Render informa que instancias `free` nao sao adequadas para producao;
- para um uso serio do `Acolhe`, troque depois para pelo menos:
  - web service: `starter`
  - postgres: `basic-256mb`

## Fluxo de start

O backend sobe assim no Render:

```bash
bash ./scripts/render-start.sh
```

Esse script faz:

1. `alembic upgrade head`
2. `uvicorn app.main:app --host 0.0.0.0 --port $PORT`

## Endpoint de verificacao

Depois do deploy, teste:

```text
https://SEU-SERVICO.onrender.com/health
```

E tambem:

```text
https://SEU-SERVICO.onrender.com/api/v1/chat/conversations
```

## Como apontar o mobile para o Render

No app:

1. abra `Configuracoes e privacidade`
2. toque em `Configurar backend do celular`
3. informe a URL publica do Render, por exemplo:

```text
https://acolhe-api.onrender.com
```

Ou rode o app com:

```bash
powershell -ExecutionPolicy Bypass -File .\run-tablet.ps1 -DeviceId SEU_DEVICE_ID -ApiBaseUrl https://acolhe-api.onrender.com
```

## Observacao sobre frio inicial

Se voce mantiver o plano `free`, o Render pode demorar mais para responder apos inatividade.

Para reduzir esse efeito, use um plano pago no backend.
