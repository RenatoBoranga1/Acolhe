from __future__ import annotations

import json
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import hash_pin
from app.models import AppSetting, Conversation, Message, ResourceArticle, SafetyPlan, TrustedContact, User


def _load_json(relative_path: str) -> dict:
    base_path = Path(__file__).resolve().parents[1]
    with (base_path / relative_path).open("r", encoding="utf-8") as file:
        return json.load(file)


def ensure_demo_data(session: Session) -> None:
    settings = get_settings()
    user = session.scalar(select(User).limit(1))
    if user is None:
        user = User(
            display_name=settings.primary_user_name,
            hashed_pin=hash_pin(settings.primary_user_pin),
            biometrics_enabled=False,
            discreet_mode=False,
        )
        session.add(user)
        session.flush()
        session.add(
            AppSetting(
                user_id=user.id,
                discreet_mode=False,
                discreet_app_name="Aurora",
                notification_title="Atualizacao segura",
            )
        )

    if session.scalar(select(ResourceArticle).limit(1)) is None:
        resources = _load_json("data/resources.json")["articles"]
        for item in resources:
            session.add(ResourceArticle(**item))

    seed = _load_json("data/mock_seed.json")
    if session.scalar(select(TrustedContact).limit(1)) is None:
        for contact in seed["trusted_contacts"]:
            session.add(TrustedContact(user_id=user.id, **contact))

    if session.scalar(select(SafetyPlan).limit(1)) is None:
        session.add(SafetyPlan(user_id=user.id, **seed["safety_plan"]))

    if session.scalar(select(Conversation).limit(1)) is None:
        conversation = Conversation(
            user_id=user.id,
            title="Primeira conversa",
            discreet_mode=False,
            last_risk_level="moderate",
        )
        session.add(conversation)
        session.flush()
        for item in seed["sample_conversation"]:
            session.add(Message(conversation_id=conversation.id, **item))

    session.commit()
