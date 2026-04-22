from fastapi import APIRouter

from app.modules.auth.router import router as auth_router
from app.modules.chat.router import router as chat_router
from app.modules.journal.router import router as journal_router
from app.modules.resources.router import router as resources_router
from app.modules.risk.router import router as risk_router
from app.modules.safety_plan.router import router as safety_plan_router
from app.modules.settings.router import router as settings_router
from app.modules.support_network.router import router as support_router

api_router = APIRouter()
api_router.include_router(auth_router, prefix="/auth", tags=["auth"])
api_router.include_router(chat_router, prefix="/chat", tags=["chat"])
api_router.include_router(risk_router, prefix="/chat", tags=["risk"])
api_router.include_router(journal_router, prefix="/incident-records", tags=["incident-records"])
api_router.include_router(safety_plan_router, prefix="/safety-plan", tags=["safety-plan"])
api_router.include_router(support_router, prefix="/trusted-contacts", tags=["trusted-contacts"])
api_router.include_router(resources_router, prefix="/resources", tags=["resources"])
api_router.include_router(settings_router, prefix="/settings", tags=["settings"])
