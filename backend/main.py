"""
main.py — RiskGuard Backend  v3
=================================
FastAPI application entry point.

Run:
    uvicorn main:app --host 0.0.0.0 --port 8000 --reload

ENV setup (backend/.env):
    HF_TOKEN=hf_your_token_here

Endpoints:
    POST /api/v1/analyze/text
    POST /api/v1/analyze/voice
    POST /api/v1/analyze/voice/realtime
    POST /api/v1/analyze/image
    POST /api/v1/analyze/image/batch
    POST /api/v1/analyze/video
    POST /api/v1/score/calculate
    GET  /api/v1/score/weights
    GET  /health
    GET  /api/v1/status
    GET  /docs          ← Swagger UI (auto-generated)
"""

import os
import logging
from contextlib import asynccontextmanager

from dotenv import load_dotenv

# Load .env BEFORE any other import that reads env vars
load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

from api.endpoints import voice, text, risk, image, video
from api.hf_client import is_hf_configured, get_model_info

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger("riskguard")


# ══════════════════════════════════════════════════════════════════════════════
# APP
# ══════════════════════════════════════════════════════════════════════════════

app = FastAPI(
    title="RiskGuard API",
    description="Multi-modal AI & Deepfake Detection — Text · Voice · Image · Video",
    version="3.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],      # Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(text.router,  prefix="/api/v1/analyze", tags=["Text Analysis"])
app.include_router(voice.router, prefix="/api/v1/analyze", tags=["Voice Analysis"])
app.include_router(image.router, prefix="/api/v1/analyze", tags=["Image Analysis"])
app.include_router(video.router, prefix="/api/v1/analyze", tags=["Video Analysis"])
app.include_router(risk.router,  prefix="/api/v1/score",   tags=["Risk Scoring"])


# ══════════════════════════════════════════════════════════════════════════════
# SYSTEM ROUTES
# ══════════════════════════════════════════════════════════════════════════════

@app.get("/", tags=["System"])
async def root():
    return {
        "name":           "RiskGuard API",
        "version":        "3.0.0",
        "status":         "running",
        "hf_configured":  is_hf_configured(),
        "docs":           "/docs",
        "endpoints": {
            "text_analysis":   "/api/v1/analyze/text",
            "voice_analysis":  "/api/v1/analyze/voice",
            "voice_realtime":  "/api/v1/analyze/voice/realtime",
            "image_analysis":  "/api/v1/analyze/image",
            "image_batch":     "/api/v1/analyze/image/batch",
            "video_analysis":  "/api/v1/analyze/video",
            "risk_scoring":    "/api/v1/score/calculate",
            "risk_weights":    "/api/v1/score/weights",
        },
        "models": get_model_info() if is_hf_configured() else {"configured": False},
    }


@app.get("/health", tags=["System"])
async def health():
    return {"status": "healthy", "hf_configured": is_hf_configured()}


@app.get("/api/v1/status", tags=["System"])
async def api_status():
    return {
        "status":  "operational",
        "version": "3.0.0",
        "huggingface": {
            "configured": is_hf_configured(),
            "models":     get_model_info() if is_hf_configured() else None,
        },
        "endpoints": {
            "text":          {"method": "POST", "path": "/api/v1/analyze/text"},
            "voice":         {"method": "POST", "path": "/api/v1/analyze/voice"},
            "voice_realtime":{"method": "POST", "path": "/api/v1/analyze/voice/realtime"},
            "image":         {"method": "POST", "path": "/api/v1/analyze/image"},
            "image_batch":   {"method": "POST", "path": "/api/v1/analyze/image/batch"},
            "video":         {"method": "POST", "path": "/api/v1/analyze/video"},
            "risk":          {"method": "POST", "path": "/api/v1/score/calculate"},
        },
    }


# ══════════════════════════════════════════════════════════════════════════════
# ENTRY POINT
# ══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    if not is_hf_configured():
        logger.warning(
            "\n⚠️  HF_TOKEN not found in environment.\n"
            "   Cloud AI detection will be disabled.\n"
            "   Add HF_TOKEN=hf_... to backend/.env\n"
        )
    else:
        info = get_model_info()
        logger.info(
            f"\n✅ HuggingFace configured.\n"
            f"   Text  : {info['text_detector']}\n"
            f"   Audio : {info['audio_detector']}\n"
            f"   Image : {info['image_detector']}\n"
        )

    logger.info("🚀 Starting RiskGuard v3 on http://localhost:8000")
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True, log_level="info")