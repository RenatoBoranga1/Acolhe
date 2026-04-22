"""initial schema

Revision ID: 20260420_0001
Revises:
Create Date: 2026-04-20
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "20260420_0001"
down_revision = None
branch_labels = None
depends_on = None


def _pk_table(
    name: str,
    *columns: sa.Column,
) -> None:
    op.create_table(
        name,
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        *columns,
    )


def upgrade() -> None:
    _pk_table(
        "users",
        sa.Column("display_name", sa.String(length=120), nullable=False),
        sa.Column("hashed_pin", sa.String(length=255), nullable=False),
        sa.Column("biometrics_enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("discreet_mode", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("notifications_hidden", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("auto_lock_minutes", sa.Integer(), nullable=False, server_default="5"),
        sa.Column("locale", sa.String(length=12), nullable=False, server_default="pt-BR"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
    )
    _pk_table(
        "conversations",
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="active"),
        sa.Column("discreet_mode", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("last_risk_level", sa.String(length=20), nullable=False, server_default="low"),
    )
    _pk_table(
        "messages",
        sa.Column("conversation_id", sa.String(length=36), sa.ForeignKey("conversations.id"), nullable=False),
        sa.Column("role", sa.String(length=20), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("risk_level", sa.String(length=20), nullable=False, server_default="low"),
        sa.Column("message_metadata", sa.JSON(), nullable=False, server_default="{}"),
    )
    _pk_table(
        "incident_records",
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("occurred_on", sa.Date(), nullable=True),
        sa.Column("occurred_at", sa.String(length=20), nullable=True),
        sa.Column("location", sa.String(length=255), nullable=True),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("people_involved", sa.JSON(), nullable=False, server_default="[]"),
        sa.Column("witnesses", sa.JSON(), nullable=False, server_default="[]"),
        sa.Column("attachments", sa.JSON(), nullable=False, server_default="[]"),
        sa.Column("observations", sa.Text(), nullable=True),
        sa.Column("perceived_impacts", sa.JSON(), nullable=False, server_default="[]"),
        sa.Column("chronological_summary", sa.Text(), nullable=True),
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    _pk_table(
        "safety_plans",
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False, unique=True),
        sa.Column("safe_locations", sa.JSON(), nullable=False, server_default="[]"),
        sa.Column("warning_signs", sa.JSON(), nullable=False, server_default="[]"),
        sa.Column("immediate_steps", sa.JSON(), nullable=False, server_default="[]"),
        sa.Column("priority_contacts", sa.JSON(), nullable=False, server_default="[]"),
        sa.Column("personal_notes", sa.Text(), nullable=True),
        sa.Column("emergency_checklist", sa.JSON(), nullable=False, server_default="[]"),
    )
    _pk_table(
        "trusted_contacts",
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("relationship", sa.String(length=120), nullable=False),
        sa.Column("phone", sa.String(length=40), nullable=True),
        sa.Column("email", sa.String(length=120), nullable=True),
        sa.Column("priority", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("ready_message", sa.Text(), nullable=False),
    )
    _pk_table(
        "resource_articles",
        sa.Column("slug", sa.String(length=120), nullable=False, unique=True),
        sa.Column("locale", sa.String(length=12), nullable=False, server_default="pt-BR"),
        sa.Column("category", sa.String(length=80), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("cta_label", sa.String(length=120), nullable=True),
        sa.Column("cta_kind", sa.String(length=40), nullable=True),
        sa.Column("is_published", sa.Boolean(), nullable=False, server_default=sa.true()),
    )
    _pk_table(
        "app_settings",
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False, unique=True),
        sa.Column("quick_exit_enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("notifications_hidden", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("discreet_mode", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("discreet_app_name", sa.String(length=120), nullable=False, server_default="Aurora"),
        sa.Column("notification_title", sa.String(length=120), nullable=False, server_default="Nova atualizacao"),
        sa.Column("export_format", sa.String(length=20), nullable=False, server_default="json"),
    )
    _pk_table(
        "risk_assessments",
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("conversation_id", sa.String(length=36), sa.ForeignKey("conversations.id"), nullable=True),
        sa.Column("message_id", sa.String(length=36), sa.ForeignKey("messages.id"), nullable=True),
        sa.Column("level", sa.String(length=20), nullable=False),
        sa.Column("score", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("reasons", sa.JSON(), nullable=False, server_default="[]"),
        sa.Column("recommended_actions", sa.JSON(), nullable=False, server_default="[]"),
        sa.Column("requires_immediate_action", sa.Boolean(), nullable=False, server_default=sa.false()),
    )


def downgrade() -> None:
    for table in [
        "risk_assessments",
        "app_settings",
        "resource_articles",
        "trusted_contacts",
        "safety_plans",
        "incident_records",
        "messages",
        "conversations",
        "users",
    ]:
        op.drop_table(table)
