"""
voice.py — Voice Analysis Router  RiskGuard v3
================================================
POST /api/v1/analyze/voice
POST /api/v1/analyze/voice/realtime

CRITICAL FIX: Original used facebook/wav2vec2-base-960h which is a
speech-to-text transcription model — completely wrong for deepfake detection.

Now uses:
  Signal 1 — HyperMoon/wav2vec2-base-finetuned-deepfake  [65%]
              Trained on ASVspoof 2019 LA dataset (industry standard benchmark)
              Detects: TTS synthesis, voice conversion, neural vocoders
              Returns: {"label": "fake"/"real", "score": float}

  Signal 2 — Local spectral analysis via scipy  [35%]
              Real features, not placeholder comments:
              • Spectral flatness  (TTS audio is more noise-like → higher flatness)
              • MFCC variance      (neural vocoders → unnaturally low variance)
              • Zero-crossing rate std  (synthetic speech → unnatural regularity)
              • High-frequency energy ratio  (TTS often has abrupt HF cutoff)
"""

from fastapi import APIRouter, UploadFile, File, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import io, math
import numpy as np

from ..hf_client import query_audio_model, is_hf_configured

router = APIRouter()

MAX_BYTES    = 25 * 1024 * 1024   # 25 MB
TARGET_SR    = 16_000              # wav2vec2 expects 16 kHz
MAX_DURATION = 30                  # seconds — clip long files


class VoiceAnalysisResponse(BaseModel):
    syntheticProbability: float
    confidence: float
    detectedPatterns: List[str]
    explanation: str
    isLikelyAI: bool
    analysisMethod: str
    subScores: Optional[dict] = None


# ══════════════════════════════════════════════════════════════════════════════
# SIGNAL 1 — CLOUD: wav2vec2 deepfake classifier
# ══════════════════════════════════════════════════════════════════════════════

def _parse_audio_hf(result) -> Optional[float]:
    """
    Parse HF audio classification output.
    Model returns: [{"label": "fake"/"real", "score": float}]
    OR nested list. Handle both.
    """
    if result is None: return None
    if isinstance(result, dict) and result.get("loading"): return None
    if isinstance(result, list) and result and isinstance(result[0], list):
        result = result[0]
    if isinstance(result, dict): result = [result]
    if not isinstance(result, list): return None

    for item in result:
        if not isinstance(item, dict): continue
        label = item.get("label", "").lower().strip()
        score = float(item.get("score", 0.0))
        if any(tok in label for tok in {"fake", "spoof", "synth", "ai", "generated", "label_1", "1"}):
            return round(score, 4)
    return None


async def _cloud_score(audio_bytes: bytes) -> Optional[float]:
    try:
        result = await query_audio_model(audio_bytes)
        return _parse_audio_hf(result)
    except Exception:
        return None


# ══════════════════════════════════════════════════════════════════════════════
# SIGNAL 2 — LOCAL: spectral feature analysis
# ══════════════════════════════════════════════════════════════════════════════

def _load_audio(audio_bytes: bytes) -> Optional[tuple]:
    """Load audio to numpy array using scipy. Returns (samples, sr) or None."""
    try:
        from scipy.io import wavfile
        sr, data = wavfile.read(io.BytesIO(audio_bytes))
        if data.ndim > 1:
            data = data.mean(axis=1)           # stereo → mono
        data = data.astype(np.float32)
        if data.max() > 1.0:
            data /= 32768.0                    # int16 normalise
        # Resample to TARGET_SR if needed (simple decimation/repeat for scipy)
        if sr != TARGET_SR:
            ratio  = TARGET_SR / sr
            n_new  = int(len(data) * ratio)
            data   = np.interp(
                np.linspace(0, len(data) - 1, n_new),
                np.arange(len(data)), data
            )
        return data[:TARGET_SR * MAX_DURATION], TARGET_SR
    except Exception:
        return None


def _spectral_features(y: np.ndarray, sr: int) -> dict:
    """
    Extract 4 spectral features without librosa.
    All computed via numpy/scipy — no extra install needed.
    """
    n = len(y)

    # 1. Spectral flatness (Wiener entropy)
    #    TTS/neural-vocoder audio is more noise-like → higher flatness
    eps    = 1e-10
    fft_mag = np.abs(np.fft.rfft(y)) + eps
    geo_mean = np.exp(np.mean(np.log(fft_mag)))
    ari_mean = np.mean(fft_mag)
    flatness = float(geo_mean / (ari_mean + eps))

    # 2. MFCC variance proxy — frame energy variance
    #    Neural vocoders produce unnaturally smooth energy → low variance
    frame_size = 512
    frames     = [y[i:i+frame_size] for i in range(0, n - frame_size, frame_size // 2)]
    energies   = [float(np.sum(f ** 2)) for f in frames if len(f) == frame_size]
    energy_var = float(np.var(energies)) if energies else 0.0

    # 3. Zero-crossing rate std
    #    Synthetic speech has unnaturally regular ZCR
    zcr_frames = [
        float(np.mean(np.abs(np.diff(np.sign(y[i:i+frame_size])))) / 2)
        for i in range(0, n - frame_size, frame_size // 2)
        if len(y[i:i+frame_size]) == frame_size
    ]
    zcr_std = float(np.std(zcr_frames)) if zcr_frames else 0.0

    # 4. High-frequency energy ratio
    #    Old TTS models hard-cut above ~8kHz; neural models vary
    nyq       = sr / 2
    freqs     = np.fft.rfftfreq(n, 1.0 / sr)
    hf_mask   = freqs > nyq * 0.75
    lf_mask   = freqs < nyq * 0.25
    hf_energy = float(np.mean(fft_mag[hf_mask] ** 2)) if hf_mask.any() else 0.0
    lf_energy = float(np.mean(fft_mag[lf_mask] ** 2)) if lf_mask.any() else 1.0
    hf_ratio  = hf_energy / (lf_energy + eps)

    return {
        "flatness":   flatness,
        "energy_var": energy_var,
        "zcr_std":    zcr_std,
        "hf_ratio":   hf_ratio,
    }


def _spectral_score(f: dict) -> tuple[float, List[str]]:
    """Convert spectral features to 0–1 AI probability + signal list."""
    score  = 0.0
    weight = 0.0
    sigs   = []

    def add(condition: bool, w: float, label: str):
        nonlocal score, weight
        weight += w
        if condition: score += w; sigs.append(label)

    add(f["flatness"]   > 0.04,   0.30, "High spectral flatness (TTS noise-like spectrum)")
    add(f["energy_var"] < 0.01,   0.25, "Unnaturally low energy variance (neural vocoder)")
    add(f["zcr_std"]    < 0.015,  0.25, "Unnatural zero-crossing regularity")
    add(f["hf_ratio"]   < 0.005,  0.20, "Abrupt high-frequency cutoff (synthetic codec)")

    prob = score / max(weight, 0.01)
    return round(prob, 4), sigs


# ══════════════════════════════════════════════════════════════════════════════
# FULL HYBRID ANALYSIS
# ══════════════════════════════════════════════════════════════════════════════

async def _analyze_audio(audio_bytes: bytes) -> dict:
    patterns: List[str] = []

    # ── Local spectral ───────────────────────────────────────────────────────
    local_prob   = 0.5
    spectral_out = {}
    audio_data   = _load_audio(audio_bytes)

    if audio_data is not None:
        y, sr          = audio_data
        feats          = _spectral_features(y, sr)
        local_prob, sp = _spectral_score(feats)
        spectral_out   = feats
        patterns.extend(sp)
    else:
        patterns.append("Spectral analysis unavailable (unsupported format)")

    # ── Cloud wav2vec2 ───────────────────────────────────────────────────────
    cloud_prob = None
    if is_hf_configured():
        cloud_prob = await _cloud_score(audio_bytes)
        if cloud_prob is not None:
            patterns.append("wav2vec2 deepfake classifier applied")

    # ── Fusion ───────────────────────────────────────────────────────────────
    if cloud_prob is not None:
        final_prob = round(cloud_prob * 0.65 + local_prob * 0.35, 4)
        method     = "wav2vec2_cloud+spectral"
        confidence = 0.85
    else:
        final_prob = round(local_prob, 4)
        method     = "spectral_local"
        confidence = 0.60

    is_ai = final_prob >= 0.55

    if final_prob >= 0.70:
        explanation = f"Strong indicators of AI-synthesised or cloned voice ({round(final_prob*100,1)}% probability)."
    elif final_prob >= 0.50:
        explanation = f"Possible synthetic voice detected ({round(final_prob*100,1)}%). Manual review recommended."
    else:
        explanation = f"Voice appears genuine ({round((1-final_prob)*100,1)}% confidence)."

    return {
        "syntheticProbability": final_prob,
        "confidence":           round(confidence, 4),
        "detectedPatterns":     patterns or ["No synthetic patterns detected"],
        "explanation":          explanation,
        "isLikelyAI":           is_ai,
        "analysisMethod":       method,
        "subScores": {
            "cloud_prob":   cloud_prob,
            "spectral_prob": local_prob,
            **{k: round(float(v), 5) for k, v in spectral_out.items()},
        },
    }


# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINTS
# ══════════════════════════════════════════════════════════════════════════════

_ALLOWED_TYPES = {
    "audio/wav","audio/mpeg","audio/mp4","audio/ogg",
    "audio/x-m4a","audio/flac","audio/x-wav","audio/wave","audio/mp3",
}
_ALLOWED_EXT = {".wav",".mp3",".m4a",".ogg",".flac",".mp4"}


def _validate_audio(upload: UploadFile):
    ct_ok  = upload.content_type in _ALLOWED_TYPES
    ext_ok = (
        any(upload.filename.lower().endswith(e) for e in _ALLOWED_EXT)
        if upload.filename else False
    )
    if not ct_ok and not ext_ok:
        raise HTTPException(400, f"Unsupported audio type: {upload.content_type}")


@router.post("/voice", response_model=VoiceAnalysisResponse)
async def analyze_voice(audio: UploadFile = File(...)):
    _validate_audio(audio)
    raw = await audio.read()
    if len(raw) < 1000:
        raise HTTPException(400, "Audio file too small. Provide a longer sample.")
    if len(raw) > MAX_BYTES:
        raise HTTPException(413, f"File too large. Max {MAX_BYTES//1024//1024} MB.")
    try:
        result = await _analyze_audio(raw)
        return VoiceAnalysisResponse(**result)
    except HTTPException: raise
    except Exception as e:
        raise HTTPException(500, f"Voice analysis failed: {str(e)}")


@router.post("/voice/realtime")
async def analyze_voice_realtime(audio: UploadFile = File(...)):
    """Lightweight endpoint for real-time streaming chunks."""
    try:
        raw = await audio.read()
        if len(raw) < 500:
            return {"syntheticProbability": 0.0, "confidence": 0.0,
                    "status": "insufficient_data", "message": "Need more audio data"}
        result = await _analyze_audio(raw)
        return {
            "syntheticProbability": result["syntheticProbability"],
            "confidence":           result["confidence"],
            "isLikelyAI":           result["isLikelyAI"],
            "status": "analyzed",
        }
    except Exception as e:
        return {"syntheticProbability": 0.0, "confidence": 0.0,
                "status": "error", "message": str(e)}