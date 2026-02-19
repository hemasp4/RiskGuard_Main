"""
video.py — Video Analysis Router  RiskGuard v3
================================================
POST /api/v1/analyze/video

2-signal ensemble:
  Signal 1 — Per-frame image detection (reuses image.py pipeline)  [60%]
              Samples 3 frames/sec, analyses every other frame via
              cloud + DCT + ELA ensemble. Capped at 30 frames.

  Signal 2 — Temporal optical flow consistency                      [40%]
              Deepfakes flicker — optical flow variance is abnormally
              high between consecutive frames.
              Real video has smooth, consistent motion fields.

Fixes over v2:
  - No more mock_local lambda inside a loop (was creating closure bugs)
  - Temporal consistency is now a real feature, not just frame variance
  - Frame scoring reuses full image pipeline instead of SigLIP-only
  - Confidence formula is based on actual evidence, not arbitrary math
"""

from fastapi import APIRouter, UploadFile, File, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import tempfile, os, io, asyncio
import numpy as np
from PIL import Image

from ..hf_client import is_hf_configured
from .image import _analyze_image   # reuse full image pipeline

router = APIRouter()

MAX_BYTES    = 100 * 1024 * 1024
SAMPLE_FPS   = 3
MAX_FRAMES   = 30


class VideoAnalysisResponse(BaseModel):
    deepfakeProbability: float
    confidence: float
    analyzedFrames: int
    frameResults: List[dict]
    detectedPatterns: List[str]
    explanation: str
    isDeepfake: bool
    analysisMethod: str
    subScores: Optional[dict] = None


# ══════════════════════════════════════════════════════════════════════════════
# FRAME EXTRACTION
# ══════════════════════════════════════════════════════════════════════════════

def _extract_frames(path: str) -> tuple[List[Image.Image], float, float]:
    """Returns (pil_frames, duration_seconds, fps)."""
    try:
        import cv2
    except ImportError:
        raise RuntimeError("opencv-python required. pip install opencv-python-headless")

    cap    = cv2.VideoCapture(path)
    fps    = cap.get(cv2.CAP_PROP_FPS) or 25.0
    total  = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    dur    = total / fps if fps > 0 else 0.0
    step   = max(1, int(fps / SAMPLE_FPS))
    frames = []
    fc     = 0

    while len(frames) < MAX_FRAMES:
        ret, frame = cap.read()
        if not ret: break
        if fc % step == 0:
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            frames.append(Image.fromarray(rgb))
        fc += 1

    cap.release()
    return frames, dur, fps


# ══════════════════════════════════════════════════════════════════════════════
# SIGNAL 1 — PER-FRAME IMAGE SCORING
# ══════════════════════════════════════════════════════════════════════════════

async def _score_frames(frames: List[Image.Image]) -> List[dict]:
    """Run full image pipeline on every other frame (speed optimisation)."""
    results = []
    for i, frame in enumerate(frames):
        if i % 2 != 0:
            continue
        try:
            buf = io.BytesIO()
            frame.save(buf, format="JPEG", quality=85)
            result = await _analyze_image(buf.getvalue())
            results.append({
                "frame":          i,
                "aiProbability":  result["aiGeneratedProbability"],
                "dct_prob":       result["subScores"].get("dct_prob", 0.0) if result.get("subScores") else 0.0,
                "status":         "analyzed",
            })
        except Exception as e:
            results.append({"frame": i, "aiProbability": 0.0, "status": "error", "error": str(e)})

    return results


# ══════════════════════════════════════════════════════════════════════════════
# SIGNAL 2 — TEMPORAL OPTICAL FLOW CONSISTENCY
# ══════════════════════════════════════════════════════════════════════════════

def _temporal_score(frames: List[Image.Image]) -> tuple[float, float]:
    """
    Compute optical flow between consecutive frames.
    Deepfakes show abrupt flow variance; real video is smooth.
    Returns (0-1 AI probability, raw inconsistency value).
    """
    if len(frames) < 3:
        return 0.5, 0.0

    try:
        import cv2

        flow_stds = []
        for i in range(1, len(frames)):
            prev = np.array(frames[i-1].convert("L").resize((128, 128)), dtype=np.float32)
            curr = np.array(frames[i].convert("L").resize((128, 128)),   dtype=np.float32)
            flow = cv2.calcOpticalFlowFarneback(
                prev, curr, None,
                pyr_scale=0.5, levels=3, winsize=15,
                iterations=3, poly_n=5, poly_sigma=1.2, flags=0,
            )
            mag = np.sqrt(flow[..., 0] ** 2 + flow[..., 1] ** 2)
            flow_stds.append(float(np.std(mag)))

        if not flow_stds:
            return 0.5, 0.0

        inconsistency = float(np.var(flow_stds))
        # Natural video: inconsistency ~0.5–5.0; deepfakes > 8.0
        prob = float(min(max((inconsistency - 0.5) / 10.0, 0.0), 1.0))
        return round(prob, 4), round(inconsistency, 4)

    except ImportError:
        # OpenCV not available — neutral
        return 0.5, 0.0
    except Exception:
        return 0.5, 0.0


# ══════════════════════════════════════════════════════════════════════════════
# FULL VIDEO ANALYSIS
# ══════════════════════════════════════════════════════════════════════════════

async def _analyze_video(video_bytes: bytes) -> dict:
    patterns: List[str] = []
    tmp_path = None

    try:
        suffix = ".mp4"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(video_bytes)
            tmp_path = tmp.name

        try:
            frames, duration, fps = _extract_frames(tmp_path)
        except RuntimeError as e:
            return {
                "deepfakeProbability": 0.0, "confidence": 0.0,
                "analyzedFrames": 0, "frameResults": [],
                "detectedPatterns": [str(e)], "explanation": str(e),
                "isDeepfake": False, "analysisMethod": "error",
            }

        if not frames:
            return {
                "deepfakeProbability": 0.0, "confidence": 0.0,
                "analyzedFrames": 0, "frameResults": [],
                "detectedPatterns": ["No frames extracted"],
                "explanation": "Could not extract frames from video.",
                "isDeepfake": False, "analysisMethod": "failed",
            }

        patterns.append(f"Extracted {len(frames)} frames at {SAMPLE_FPS} fps")

        # Signal 1 + 2 run in parallel
        frame_results, (temporal_prob, inconsistency) = await asyncio.gather(
            _score_frames(frames),
            asyncio.to_thread(_temporal_score, frames),
        )

        # Frame average
        probs     = [r.get("aiProbability", 0.0) for r in frame_results]
        frame_avg = round(float(np.mean(probs)), 4) if probs else 0.5

        # Fusion
        final = round(frame_avg * 0.60 + temporal_prob * 0.40, 4)

        # Confidence scales with number of frames analysed
        confidence = round(min(0.92, 0.55 + len(frame_results) * 0.02), 4)

        # Patterns
        if frame_avg > 0.65:
            patterns.append(f"Frame classifier avg: {round(frame_avg*100,1)}% AI")
        if temporal_prob > 0.60:
            patterns.append(f"Temporal flickering detected (inconsistency: {inconsistency})")
        if len(frame_results) < 5:
            patterns.append("Short clip — low confidence (fewer than 5 frames analysed)")
        if not any("AI" in p or "flickering" in p for p in patterns):
            patterns.append("No strong deepfake signals detected")

        is_deepfake = final >= 0.55
        method = ("frame_cloud+dct+ela+temporal"
                  if is_hf_configured() else "frame_dct+ela+temporal_local")

        if final >= 0.70:
            explanation = f"High likelihood of deepfake/AI-generated video ({round(final*100,1)}%)."
        elif final >= 0.55:
            explanation = f"Possible deepfake detected ({round(final*100,1)}%). Manual review recommended."
        else:
            explanation = f"Video appears authentic ({round((1-final)*100,1)}% confidence)."

        return {
            "deepfakeProbability": final,
            "confidence":          confidence,
            "analyzedFrames":      len(frames),
            "frameResults":        frame_results,
            "detectedPatterns":    patterns,
            "explanation":         explanation,
            "isDeepfake":          is_deepfake,
            "analysisMethod":      method,
            "subScores": {
                "frame_avg_prob":    frame_avg,
                "temporal_prob":     temporal_prob,
                "temporal_inconsistency": inconsistency,
                "duration_seconds":  round(duration, 2),
                "fps":               round(fps, 1),
            },
        }

    finally:
        if tmp_path and os.path.exists(tmp_path):
            try: os.unlink(tmp_path)
            except Exception: pass


# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT
# ══════════════════════════════════════════════════════════════════════════════

_ALLOWED_TYPES = {"video/mp4","video/quicktime","video/x-msvideo",
                  "video/x-matroska","video/webm","video/avi"}
_ALLOWED_EXT   = {".mp4",".mov",".avi",".mkv",".webm"}


@router.post("/video", response_model=VideoAnalysisResponse)
async def analyze_video(video: UploadFile = File(...)):
    ct_ok  = video.content_type in _ALLOWED_TYPES
    ext_ok = (any(video.filename.lower().endswith(e) for e in _ALLOWED_EXT)
              if video.filename else False)
    if not ct_ok and not ext_ok:
        raise HTTPException(400, f"Unsupported video type: {video.content_type}")

    raw = await video.read()
    if len(raw) < 10_000:
        raise HTTPException(400, "Video file too small.")
    if len(raw) > MAX_BYTES:
        raise HTTPException(413, f"File too large. Max {MAX_BYTES//1024//1024} MB.")

    try:
        result = await _analyze_video(raw)
        return VideoAnalysisResponse(**result)
    except HTTPException: raise
    except Exception as e:
        raise HTTPException(500, f"Video analysis failed: {str(e)}")