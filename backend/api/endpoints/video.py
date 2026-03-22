"""
video.py — Video Analysis Router  RiskGuard v4  (Parallel + Timeout Edition)
=============================================================================
POST /api/v1/analyze/video

Key improvements over v3:
  - Frame scoring is now FULLY PARALLEL (asyncio.gather over all frames)
    Previously sequential: 15 frames × 500ms = 7.5s+. Now: ~1–2s wall-clock.
  - Per-frame timeout: 8s. Falls back to neutral score if HF is slow.
  - Hard overall analysis timeout: 30s (returns partial result if hit).
  - Adaptive sampling: 1 FPS, capped at 10 frames → covers 10s of video.
  - Frames downscaled to 480px wide before sending to reduce payload.
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

MAX_BYTES         = 100 * 1024 * 1024
MAX_FRAMES        = 6        # max frames to score (reduced for cloud model throughput)
SAMPLE_FPS        = 1        # one frame per second
PER_FRAME_TIMEOUT = 25.0     # seconds per frame (cloud models need 10-20s on cold start)
OVERALL_TIMEOUT   = 90.0     # hard wall-clock cap for the whole pipeline


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
    """Extract evenly-spaced frames. Adaptive target based on duration."""
    try:
        import cv2
    except ImportError:
        raise RuntimeError("opencv-python required. pip install opencv-python-headless")

    cap   = cv2.VideoCapture(path)
    fps   = cap.get(cv2.CAP_PROP_FPS) or 25.0
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    dur   = total / fps if fps > 0 else 0.0

    # Sample evenly across video, capped at MAX_FRAMES
    target = min(MAX_FRAMES, max(3, int(dur * SAMPLE_FPS)))
    step   = max(1, total // target)

    frames = []
    fc     = 0

    while len(frames) < target:
        ret, frame = cap.read()
        if not ret:
            break
        if fc % step == 0:
            # Downscale wide frames to 480px to reduce upload payload
            h, w = frame.shape[:2]
            if w > 480:
                scale = 480 / w
                frame = cv2.resize(frame, (480, int(h * scale)))
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            frames.append(Image.fromarray(rgb))
        fc += 1

    cap.release()
    return frames, dur, fps


# ══════════════════════════════════════════════════════════════════════════════
# SIGNAL 1 — PER-FRAME IMAGE SCORING (FULLY PARALLEL)
# ══════════════════════════════════════════════════════════════════════════════

async def _score_single_frame(frame: Image.Image, idx: int) -> dict:
    """Score one frame using the full image analysis pipeline.
    If that times out, fall back to a quick local-only analysis."""
    try:
        buf = io.BytesIO()
        frame.save(buf, format="JPEG", quality=80)
        image_bytes = buf.getvalue()
        result = await asyncio.wait_for(
            _analyze_image(image_bytes),
            timeout=PER_FRAME_TIMEOUT,
        )
        return {
            "frame":         idx,
            "aiProbability": result["aiGeneratedProbability"],
            "dct_prob":      (result["subScores"].get("dct_prob", 0.0)
                              if result.get("subScores") else 0.0),
            "status":        "analyzed",
        }
    except asyncio.TimeoutError:
        # Cloud timed out — run quick local-only signals so we still get data
        try:
            local_prob = await asyncio.to_thread(_quick_local_score, frame)
            return {"frame": idx, "aiProbability": local_prob, "status": "local_fallback"}
        except Exception:
            return {"frame": idx, "aiProbability": 0.5, "status": "timeout"}
    except Exception as e:
        err_msg = str(e)
        return {"frame": idx, "aiProbability": 0.0, "status": "error", "error": err_msg[:80]}


def _quick_local_score(frame: Image.Image) -> float:
    """Fast local-only scoring using NPR + DCT (no cloud, <50ms)."""
    from .image import _npr_score, _dct_spectral_score
    try:
        npr_prob, npr_detail = _npr_score(frame)
        npr_colors = npr_detail.get("npr_unique_colors", 9999)
        dct_prob, _ = _dct_spectral_score(frame)
        # Simple 50/50 blend of local signals
        return round(npr_prob * 0.45 + dct_prob * 0.55, 4)
    except Exception:
        return 0.5


async def _score_frames(frames: List[Image.Image]) -> List[dict]:
    """Launch ALL frame tasks at once — parallel, not sequential."""
    tasks = [_score_single_frame(frame, i) for i, frame in enumerate(frames)]
    return list(await asyncio.gather(*tasks))


# ══════════════════════════════════════════════════════════════════════════════
# SIGNAL 2 — TEMPORAL OPTICAL FLOW CONSISTENCY
# ══════════════════════════════════════════════════════════════════════════════

def _temporal_score(frames: List[Image.Image]) -> tuple[float, float]:
    """
    Optical flow variance between consecutive frames.
    Deepfakes show abrupt flow spikes; real video is consistent.
    Returns (0–1 AI probability, raw inconsistency value).
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
        # Natural video: inconsistency ~0.5–5; deepfakes typically >8
        prob = float(min(max((inconsistency - 0.5) / 10.0, 0.0), 1.0))
        return float(round(prob, 4)), float(round(inconsistency, 4))

    except Exception:
        return 0.5, 0.0


# ══════════════════════════════════════════════════════════════════════════════
# FULL VIDEO ANALYSIS WITH HARD TIMEOUT WRAPPER
# ══════════════════════════════════════════════════════════════════════════════

async def _analyze_video(video_bytes: bytes) -> dict:
    """Wraps inner analysis with a 30-second hard timeout."""
    try:
        return await asyncio.wait_for(
            _analyze_video_inner(video_bytes),
            timeout=OVERALL_TIMEOUT,
        )
    except asyncio.TimeoutError:
        return {
            "deepfakeProbability": 0.5,
            "confidence":          0.3,
            "analyzedFrames":      0,
            "frameResults":        [],
            "detectedPatterns":    ["Analysis timed out — try a shorter clip (under 30 seconds)"],
            "explanation":         "Video analysis exceeded the 30s time limit. Please upload a shorter clip.",
            "isDeepfake":          False,
            "analysisMethod":      "timeout",
        }


async def _analyze_video_inner(video_bytes: bytes) -> dict:
    patterns: List[str] = []
    tmp_path = None

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as tmp:
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

        patterns.append(f"Sampled {len(frames)} frames from {round(duration, 1)}s video")

        # Signal 1 (parallel frames) + Signal 2 (optical flow)
        frame_results, (temporal_prob, inconsistency) = await asyncio.gather(
            _score_frames(frames),
            asyncio.to_thread(_temporal_score, frames),
        )

        # Signal 3 — Audio Tracking (VOICE ANALYSIS)
        voice_prob = 0.0
        voice_conf = 0.0
        has_voice  = False
        try:
            from .voice import _analyze_audio
            # Extract audio to buffer
            from moviepy.editor import VideoFileClip
            import pydub

            clip = VideoFileClip(tmp_path)
            if clip.audio is not None:
                audio_path = tmp_path + ".wav"
                clip.audio.write_audiofile(audio_path, fps=16000, verbose=False, logger=None)
                with open(audio_path, "rb") as af:
                    audio_bytes = af.read()
                
                # Close clip to release file handles
                clip.close()
                if os.path.exists(audio_path): os.unlink(audio_path)

                if len(audio_bytes) > 2000:
                    voice_result = await _analyze_audio(audio_bytes)
                    voice_prob = voice_result["syntheticProbability"]
                    voice_conf = voice_result["confidence"]
                    # Low voice check: If confidence is very low, we treat it as "no voice"
                    if voice_conf > 0.15:
                        has_voice = True
                        patterns.append(f"Voice analysis: {round(voice_prob*100,1)}% synthetic probability")
                    else:
                        patterns.append("Audio track detected but voice is too low for reliable analysis")
        except Exception as e:
            debug_err = str(e)[:50]
            patterns.append(f"Audio analysis skipped: {debug_err}")

        # ── FUSION LOGIC ──────────────────────────────────────────────────────
        # Optimized for "Low Voice": 
        # If no voice, result is 100% Visual.
        # If voice exists, result is 50/50 blend (Weighted by confidence).
        
        # Average over frames
        good = [r for r in frame_results if r["status"] in ("analyzed", "local_fallback")]
        probs = [float(r["aiProbability"]) for r in good]
        visual_prob = float(round(float(np.mean(probs)), 4)) if probs else 0.5
        
        # Temporal consistency (Visual)
        visual_ensemble = visual_prob * 0.60 + temporal_prob * 0.40

        if has_voice:
            # Weighted average based on confidence
            # If visual conf is high and voice conf is high, 50/50
            # If voice is low (0.2), it only contributes 20% to the final score
            final = float(round((visual_ensemble * 0.7) + (voice_prob * 0.3), 4))
            # Boost if either is VERY high (Deepfake detected in one modality is enough)
            if voice_prob > 0.85 or visual_ensemble > 0.85:
                final = max(final, voice_prob, visual_ensemble)
            
            total_conf = float(round(min(0.95, 0.5 + voice_conf * 0.3), 4))
        else:
            final = float(round(visual_ensemble, 4))
            total_conf = float(round(min(0.90, 0.45 + (len(good)*0.05)), 4))

        if visual_ensemble > 0.65:
            patterns.append(f"Visual artifacts detected (avg: {round(visual_ensemble*100, 1)}% AI)")
        if temporal_prob > 0.60:
            patterns.append(f"Temporal flickering detected (inconsistency: {inconsistency})")
        if not has_voice and visual_ensemble < 0.45:
            patterns.append("Analysis based on visuals only (no clear speech detected)")

        is_deepfake = final >= 0.45 # Lowered slightly for multi-modal sensitivity
        method = "fusion_audio_visual_ensemble" if has_voice else "visual_only_ensemble"

        if final >= 0.70:
            explanation = f"High likelihood of deepfake/AI-generated production ({round(final*100,1)}%). Both visual and audio signals were evaluated." if has_voice else f"Visual analysis indicates AI generation ({round(final*100,1)}%)."
        elif final >= 0.45:
            explanation = f"Possible deepfake detected ({round(final*100,1)}%). Manual review recommended."
        else:
            explanation = f"Video appears authentic ({round((1-final)*100,1)}% confidence)."

        return {
            "deepfakeProbability": final,
            "confidence":          total_conf,
            "analyzedFrames":      len(frames),
            "frameResults":        frame_results,
            "detectedPatterns":    patterns,
            "explanation":         explanation,
            "isDeepfake":          is_deepfake,
            "analysisMethod":      method,
            "subScores": {
                "visual_prob":            visual_ensemble,
                "voice_prob":             voice_prob if has_voice else None,
                "has_voice":              has_voice,
                "temporal_prob":          temporal_prob,
                "temporal_inconsistency": inconsistency,
                "duration_seconds":       round(duration, 2),
                "frames_analyzed":        len(good),
            },
        }

    finally:
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except Exception:
                pass


# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT
# ══════════════════════════════════════════════════════════════════════════════

_ALLOWED_TYPES = {"video/mp4", "video/quicktime", "video/x-msvideo",
                  "video/x-matroska", "video/webm", "video/avi"}
_ALLOWED_EXT   = {".mp4", ".mov", ".avi", ".mkv", ".webm"}


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
        # Feed into Intelligence Center
        try:
            from .intel import log_analysis
            log_analysis("video", result)
        except Exception:
            pass
        return VideoAnalysisResponse(**result)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(500, f"Video analysis failed: {str(e)}")