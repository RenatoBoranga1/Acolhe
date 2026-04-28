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

## Testes

```bash
powershell -ExecutionPolicy Bypass -File ..\\test-backend.ps1
```
