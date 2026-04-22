from __future__ import annotations

from pathlib import Path
import sys

import pytest
from fastapi.testclient import TestClient


BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> TestClient:
    database_url = f"sqlite:///{tmp_path / 'acolhe-test.db'}"
    monkeypatch.setenv("DATABASE_URL", database_url)
    monkeypatch.setenv("SEED_DEMO_DATA", "true")

    from app.core.config import get_settings
    from app.core.database import configure_database, get_engine
    from app.main import create_app
    from app.models import Base

    get_settings.cache_clear()
    configure_database(database_url)
    Base.metadata.drop_all(bind=get_engine())
    Base.metadata.create_all(bind=get_engine())

    app = create_app()
    with TestClient(app) as test_client:
        yield test_client

    get_settings.cache_clear()
