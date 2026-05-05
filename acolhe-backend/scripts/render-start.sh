#!/usr/bin/env bash
set -euo pipefail

echo "Starting Acolhe API on Render..."
echo "Environment: ${ENVIRONMENT:-production}"

alembic upgrade head

exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-10000}"
