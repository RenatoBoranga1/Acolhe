# Acolhe Backend

API em `FastAPI` para autenticação local, chat com IA, classificação de risco, registros privados, plano de segurança, rede de apoio e conteúdos informativos.

## Principais características

- arquitetura modular por domínio;
- `SQLAlchemy` + `Alembic`;
- pronta para PostgreSQL em ambiente real;
- fallback local com `SQLite` para desenvolvimento rápido e testes;
- classificação híbrida de risco antes da resposta da IA;
- integração LLM isolada e opcional;
- logs seguros, sem conteúdo sensível.

## Executar localmente

```bash
copy ..\\.env.example .env
powershell -ExecutionPolicy Bypass -File ..\\start-backend.ps1
```

Por padrao, o script agora sobe o backend em `0.0.0.0:8000`, o que permite acesso por celular ou tablet na mesma rede local.

Comando direto equivalente:

```bash
& "C:\Users\USER\Documents\Playground\tools\python-3.11.9-embed-amd64\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## Rodar com Docker

```bash
docker compose up --build
```

## Deploy no Render

Este backend ja esta preparado para Render com:

- `render.yaml` na raiz do repositorio;
- `rootDir` apontando para `acolhe-backend`;
- start command via `bash ./scripts/render-start.sh`;
- migracoes automaticas com `alembic upgrade head`;
- health check em `/health`.

Guia completo:

- [../docs/render-deploy.md](../docs/render-deploy.md)

Observacoes:

- o Blueprint usa `free` por padrao para facilitar teste inicial;
- para ambiente serio, troque depois o web service para `starter` e o banco para `basic-256mb` ou acima.

## Testes

```bash
powershell -ExecutionPolicy Bypass -File ..\\test-backend.ps1
```
