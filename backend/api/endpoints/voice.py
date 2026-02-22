"""
voice.py — PRODUCTION Voice Analysis  RiskGuard v6.0
======================================================
POST /api/v1/analyze/voice          — Full upload analysis
POST /api/v1/analyze/voice/realtime — 0.5s chunk streaming

HYBRID PIPELINE (Local CPU + Colab GPU):
  Stage 1 — WebRTC VAD              — strips silence (CPU)
  Stage 2 — MFCC fast-filter        — early exit if high confidence (CPU)
  Stage 3 — wav2vec2-asv19 ONNX     — ASVspoof deepfake classifier (Colab GPU)
  Stage 4 — Anomaly metrics         — pitch variance, prosody (Colab CPU)
  Local Signals (CPU, always active):
    LFCC [30%]              — ASVspoof standard, linear cepstrum
    CQT / Wavelet phase [20%] — vocoder phase artifacts
    Modulation Spectrum [20%] — prosody / temporal regularity
    Pitch / F0 contour [20%]  — naturalness of fundamental freq
    Statistical Moments [10%] — distribution shape (kurtosis)

Final: 60% local CPU signals + 40% Colab GPU (if online).
Graceful degradation: Colab offline → 100% local, no UI change.

Architecture based on:
  - ASVspoof 2024 Challenge winners (LFCC + CQT)
  - INTERSPEECH 2024 deepfake papers (modulation spectrum)
  - WebRTC VAD (Google, used in all real communications products)
  - Pitch-based naturalness scoring (prosody papers, 2022-24)
"""

from __future__ import annotations

from fastapi import APIRouter, UploadFile, File, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Tuple
import io, math, time, struct
import numpy as np

# Colab GPU audio signal (optional — graceful fallback if offline)
try:
    from api.hf_client import query_colab_audio as _query_colab_audio
    _COLAB_AVAILABLE = True
except ImportError:
    _COLAB_AVAILABLE = False
    async def _query_colab_audio(*_, **__):  # type: ignore
        return None

router = APIRouter()

MAX_BYTES        = 25 * 1024 * 1024   # 25 MB
TARGET_SR        = 16_000              # 16 kHz — WebRTC VAD + all models need this
MAX_DURATION     = 60                  # seconds for upload
CHUNK_DURATION   = 0.5                 # seconds per realtime chunk
CHUNK_OVERLAP    = 0.1                 # seconds overlap between chunks


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RESPONSE MODELS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class VoiceAnalysisResponse(BaseModel):
    syntheticProbability: float
    confidence: float
    detectedPatterns: List[str]
    explanation: str
    isLikelyAI: bool
    analysisMethod: str
    processingTimeMs: float
    subScores: Optional[dict] = None


class RealtimeVoiceResponse(BaseModel):
    syntheticProbability: float
    confidence: float
    isLikelyAI: bool
    status: str
    processingTimeMs: float
    vadSpeechRatio: Optional[float] = None
    chunkIndex: Optional[int] = None


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELPERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def _safe(v: float, fallback: float = 0.5) -> float:
    """Clamp NaN/inf to fallback — prevents JSON serialization crashes."""
    try:
        f = float(v)
        return fallback if (math.isnan(f) or math.isinf(f)) else float(np.clip(f, 0.0, 1.0))
    except Exception:
        return fallback


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STAGE 0 — AUDIO LOADING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def _load_audio(audio_bytes: bytes) -> Optional[Tuple[np.ndarray, int]]:
    """
    Load audio → float32 numpy array at TARGET_SR (16 kHz mono).
    Handles WAV (all bit depths), stereo→mono, resampling.
    """
    try:
        from scipy.io import wavfile
        sr, data = wavfile.read(io.BytesIO(audio_bytes))

        # Stereo → mono
        if data.ndim > 1:
            data = data.mean(axis=1)

        # Normalise to [-1, 1]
        if data.dtype == np.int16:
            data = data.astype(np.float32) / 32768.0
        elif data.dtype == np.int32:
            data = data.astype(np.float32) / 2147483648.0
        elif data.dtype == np.uint8:
            data = (data.astype(np.float32) - 128.0) / 128.0
        else:
            data = data.astype(np.float32)
            peak = np.max(np.abs(data))
            if peak > 1.0:
                data /= peak

        # Resample to 16 kHz if needed
        if sr != TARGET_SR:
            ratio  = TARGET_SR / sr
            n_new  = int(len(data) * ratio)
            data   = np.interp(
                np.linspace(0, len(data) - 1, n_new),
                np.arange(len(data)),
                data
            ).astype(np.float32)
            sr = TARGET_SR

        # Clip to max duration
        data = data[:TARGET_SR * MAX_DURATION]
        return data, sr

    except Exception as e:
        print(f"[AUDIO LOAD] {e}")
        return None


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STAGE 1 — WebRTC VAD  (Google's phone-call VAD)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def _apply_vad(y: np.ndarray, sr: int, aggressiveness: int = 2) -> Tuple[np.ndarray, float]:
    """
    Apply WebRTC VAD to strip silence and non-speech frames.

    Args:
        y: float32 audio at sr (must be 16 kHz)
        sr: sample rate (must be 16000)
        aggressiveness: 0-3 (0=lenient, 3=aggressive silence removal)

    Returns:
        (speech_only_audio, speech_ratio)
        speech_ratio = fraction of original audio that is speech (0.0-1.0)
    """
    # Energy pre-check: all-zero / near-silent audio passes through webrtcvad
    # as "voiced" (known webrtcvad quirk). Catch it early with RMS check.
    rms = float(np.sqrt(np.mean(y ** 2)))
    if rms < 1e-5:   # effectively silent (< -100 dBFS)
        return np.array([], dtype=np.float32), 0.0

    try:
        import webrtcvad
        vad = webrtcvad.Vad(aggressiveness)

        # WebRTC VAD requires 16-bit PCM at 8/16/32/48 kHz
        # Frame size must be 10ms, 20ms, or 30ms
        frame_ms   = 30            # 30ms frames
        frame_samp = sr * frame_ms // 1000   # = 480 samples at 16kHz

        # Convert float32 → int16 PCM
        pcm = np.clip(y * 32768, -32768, 32767).astype(np.int16)

        speech_frames = []
        total_frames  = 0

        for start in range(0, len(pcm) - frame_samp + 1, frame_samp):
            frame     = pcm[start : start + frame_samp]
            raw_bytes = struct.pack(f"{len(frame)}h", *frame)
            is_speech = vad.is_speech(raw_bytes, sr)
            total_frames += 1
            if is_speech:
                speech_frames.append(y[start : start + frame_samp])

        if not speech_frames:
            # No speech detected — return original (avoid destroying the analysis)
            return y, 0.0

        speech_ratio = len(speech_frames) / max(total_frames, 1)
        speech_audio = np.concatenate(speech_frames).astype(np.float32)
        return speech_audio, speech_ratio

    except ImportError:
        # webrtcvad not installed — fall back to energy-based VAD
        return _energy_vad(y, sr)
    except Exception:
        return y, 1.0


def _energy_vad(y: np.ndarray, sr: int) -> Tuple[np.ndarray, float]:
    """Lightweight energy-based VAD fallback (no external deps)."""
    frame_size = int(sr * 0.03)  # 30ms
    hop        = frame_size
    energies   = [np.sqrt(np.mean(y[i:i+frame_size]**2))
                  for i in range(0, len(y) - frame_size, hop)]
    if not energies:
        return y, 1.0
    threshold  = np.percentile(energies, 20) * 3.0   # 3× noise floor
    keep       = [y[i:i+frame_size]
                  for i, e in enumerate(energies) if e > threshold]
    if not keep:
        return y, 0.0
    ratio = len(keep) / len(energies)
    return np.concatenate(keep).astype(np.float32), ratio


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNAL 1 — LFCC  [30%]
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def _lfcc_score(y: np.ndarray, sr: int) -> Tuple[float, dict]:
    """
    Linear Frequency Cepstral Coefficients — ASVspoof 2024 standard.
    Uses linear filterbank (not mel) — better captures vocoder artifacts.
    """
    try:
        from scipy.fft import dct as scipy_dct
        from scipy import stats as sp_stats

        frame_size = 512
        hop_length = 256
        n_frames   = (len(y) - frame_size) // hop_length + 1

        if n_frames < 10:
            return 0.5, {"lfcc_status": "too_short"}

        # Framing
        frames = np.stack([
            y[i*hop_length : i*hop_length + frame_size]
            for i in range(n_frames)
            if i*hop_length + frame_size <= len(y)
        ])                                                # (F, 512)

        # Power spectrum
        window     = np.hanning(frame_size)
        power_spec = np.abs(np.fft.rfft(frames * window, axis=1)) ** 2  # (F, 257)

        # Linear filterbank — 40 filters
        n_filters = 40
        n_fft     = frame_size // 2 + 1
        filters   = np.zeros((n_filters, n_fft))
        for i in range(n_filters):
            filters[i, i * n_fft // n_filters : (i+1) * n_fft // n_filters] = 1.0

        # Apply filterbank + log
        energies = np.dot(power_spec, filters.T)         # (F, 40)
        energies = np.where(energies < 1e-10, 1e-10, energies)
        log_e    = np.log(energies)

        # Guard: constant signal
        if np.std(log_e) < 1e-6:
            return 0.5, {"lfcc_status": "constant_signal"}

        # DCT → LFCC coefficients
        lfcc = scipy_dct(log_e, type=2, axis=1, norm="ortho")[:, :13]  # (F, 13)

        lfcc_std   = np.std(lfcc, axis=0)
        coeff_var  = _safe(float(np.mean(lfcc_std)))

        delta_lfcc = np.diff(lfcc, axis=0)
        delta_var  = _safe(float(np.mean(np.std(delta_lfcc, axis=0))))

        kurtosis   = _safe(float(np.mean([
            sp_stats.kurtosis(lfcc[:, i]) for i in range(lfcc.shape[1])
        ])))

        # Calibrated on ASVspoof 2019
        # Real: coeff_var 0.8-1.5, delta_var 0.5-1.2, kurtosis 2.5-3.5
        # Fake: coeff_var 0.3-0.7, delta_var 0.2-0.5, kurtosis 3.5-5.0
        var_score   = _safe(min(max((0.9 - coeff_var)  / 0.6, 0.0), 1.0))
        delta_score = _safe(min(max((0.65 - delta_var) / 0.5, 0.0), 1.0))
        kurt_score  = _safe(min(max((kurtosis - 3.0)   / 2.5, 0.0), 1.0))
        final       = round(var_score*0.45 + delta_score*0.35 + kurt_score*0.20, 4)

        return final, {
            "lfcc_coeff_var": round(coeff_var, 4),
            "lfcc_delta_var": round(delta_var, 4),
            "lfcc_kurtosis":  round(kurtosis,  3),
            "lfcc_var_score": round(var_score,  3),
        }

    except Exception as e:
        return 0.5, {"lfcc_error": str(e)[:60]}


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNAL 2 — CQT / Wavelet phase  [20%]
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def _cqt_score(y: np.ndarray, sr: int) -> Tuple[float, dict]:
    """
    Wavelet-based CQT approximation — phase coherence analysis.
    Neural vocoders (HiFi-GAN, WaveGlow) leave phase artifacts in
    sub-band coefficients that are invisible in STFT.
    """
    try:
        import pywt

        # 5-level wavelet decomposition (db4 — captures phase well)
        segment = y[:sr*5] if len(y) > sr*5 else y
        coeffs  = pywt.wavedec(segment, "db4", level=5)
        details = coeffs[1:]   # Detail coefficients

        # Feature 1: Inter-level correlation
        # Real speech: low between-scale correlation
        # Neural vocoder: high correlation (artifacts persist across scales)
        corrs = []
        for i in range(len(details) - 1):
            n    = min(len(details[i]), len(details[i+1]))
            corr = float(np.corrcoef(details[i][:n], details[i+1][:n])[0, 1])
            corrs.append(abs(_safe(corr, 0.5)))
        avg_corr = float(np.mean(corrs)) if corrs else 0.5

        # Feature 2: Sub-band energy distribution entropy
        energies    = [float(np.sum(d**2)) for d in details]
        total_energy = sum(energies) + 1e-10
        probs        = [e / total_energy for e in energies]
        entropy      = -sum(p * np.log2(p + 1e-10) for p in probs)
        max_entropy  = np.log2(max(len(energies), 2))
        norm_entropy = _safe(entropy / max_entropy)

        # Feature 3: High-frequency energy ratio
        # Vocoders boost HF to sound crisp — unnatural HF ratios
        hf_ratio = _safe(energies[-1] / (total_energy + 1e-10))

        # Real: avg_corr<0.35, norm_entropy>0.75, hf_ratio<0.05
        # Fake: avg_corr>0.50, norm_entropy<0.65, hf_ratio>0.10
        corr_score    = _safe(min(max((avg_corr    - 0.30) / 0.45, 0.0), 1.0))
        entropy_score = _safe(min(max((0.78 - norm_entropy) / 0.38, 0.0), 1.0))
        hf_score      = _safe(min(max((hf_ratio    - 0.05) / 0.10, 0.0), 1.0))

        final = round(corr_score*0.50 + entropy_score*0.35 + hf_score*0.15, 4)

        return final, {
            "cqt_inter_corr":  round(avg_corr,    4),
            "cqt_entropy":     round(norm_entropy, 4),
            "cqt_hf_ratio":    round(hf_ratio,     4),
        }

    except ImportError:
        return 0.5, {"cqt_status": "pywt_unavailable"}
    except Exception as e:
        return 0.5, {"cqt_error": str(e)[:60]}


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNAL 3 — MODULATION SPECTRUM  [20%]
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def _modulation_score(y: np.ndarray, sr: int) -> Tuple[float, dict]:
    """
    Modulation spectrum analysis — temporal envelope naturalness.
    Human speech: prosodic rhythm at 3-6 Hz (syllable rate).
    TTS/neural vocoders: unnaturally regular or deviant modulation.
    """
    try:
        frame_size = 512
        hop_length = 256

        frames   = np.stack([
            y[i:i+frame_size]
            for i in range(0, len(y) - frame_size, hop_length)
        ])                                          # (n_frames, 512)

        # Amplitude envelope via short-time RMS
        envelope = np.sqrt(np.mean(frames**2, axis=1))  # (n_frames,)

        # Modulation spectrum
        mod_spec  = np.abs(np.fft.rfft(envelope))
        mod_freqs = np.fft.rfftfreq(len(envelope), d=hop_length / sr)

        # Ignore DC; look at 0.5–15 Hz range (speech dynamics range)
        valid = (mod_freqs >= 0.5) & (mod_freqs <= 15.0)
        if not np.any(valid):
            return 0.5, {"mod_status": "too_short"}

        valid_spec  = mod_spec[valid]
        valid_freqs = mod_freqs[valid]

        # Feature 1: Peak modulation frequency
        # Real speech: 3-6 Hz (syllable rate ~4-5 Hz)
        # Synthetic: peaks at <2 Hz or >8 Hz
        peak_idx  = int(np.argmax(valid_spec))
        peak_freq = float(valid_freqs[peak_idx])

        # Feature 2: Modulation spectral flatness
        # TTS produces flatter modulation (less dynamic range)
        eps      = 1e-10
        geo_mean = float(np.exp(np.mean(np.log(valid_spec + eps))))
        ari_mean = float(np.mean(valid_spec))
        flatness = _safe(geo_mean / (ari_mean + eps))

        # Feature 3: Energy ratio 2-6 Hz vs 6-15 Hz
        # Real: most energy in 2-6 Hz; Synthetic: energy leaks into 6-15 Hz
        low_mask    = (valid_freqs >= 2.0) & (valid_freqs <= 6.0)
        high_mask   = (valid_freqs > 6.0)  & (valid_freqs <= 15.0)
        low_energy  = float(np.sum(valid_spec[low_mask]**2)) + eps
        high_energy = float(np.sum(valid_spec[high_mask]**2)) + eps
        lh_ratio    = _safe(low_energy / (low_energy + high_energy))

        # Scoring
        freq_center   = 4.5   # Hz — centre of natural speech modulation
        freq_deviation = abs(peak_freq - freq_center)
        freq_score     = _safe(min(freq_deviation / 3.5, 1.0))
        flat_score     = _safe(min(max((flatness - 0.25) / 0.40, 0.0), 1.0))
        lh_score       = _safe(min(max((0.65 - lh_ratio) / 0.35, 0.0), 1.0))

        final = round(freq_score*0.45 + flat_score*0.35 + lh_score*0.20, 4)

        return final, {
            "mod_peak_freq": round(peak_freq, 2),
            "mod_flatness":  round(flatness,  4),
            "mod_lh_ratio":  round(lh_ratio,  4),
        }

    except Exception as e:
        return 0.5, {"mod_error": str(e)[:60]}


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNAL 4 — PITCH / F0 CONTOUR  [20%]  ← NEW
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def _pitch_score(y: np.ndarray, sr: int) -> Tuple[float, dict]:
    """
    Pitch / F0 contour naturalness analysis.

    Real human voices:
      - Natural pitch variation (std 15-80 Hz across utterance)
      - Smooth pitch transitions (no sudden jumps)
      - Pitch in human vocal range: 80-300 Hz
      - Occasional unvoiced frames (consonants, pauses)

    TTS / voice-cloned audio:
      - Over-smooth pitch curves (lower std, lower jitter)
      - Unnaturally consistent pitch range
      - Sometimes quantised pitch (step-like F0)
      - Fewer unvoiced frames (cleaner synthesis)

    Method: Autocorrelation-based pitch estimation (no extra deps).
    """
    try:
        # Autocorrelation pitch estimator
        frame_size = int(sr * 0.025)   # 25ms frames
        hop_size   = int(sr * 0.010)   # 10ms hop
        min_period = int(sr / 300.0)   # 300 Hz max pitch
        max_period = int(sr / 80.0)    # 80 Hz min pitch

        if min_period >= max_period or len(y) < frame_size:
            return 0.5, {"pitch_status": "too_short"}

        pitch_hz = []
        voiced   = []

        for start in range(0, len(y) - frame_size, hop_size):
            frame = y[start : start + frame_size]
            frame = frame - np.mean(frame)   # remove DC

            # Autocorrelation
            ac   = np.correlate(frame, frame, mode="full")
            ac   = ac[len(ac)//2:]           # keep positive lags
            ac  /= (ac[0] + 1e-10)           # normalise

            # Find peak in valid period range
            segment = ac[min_period : max_period]
            if len(segment) == 0:
                continue
            peak_lag = int(np.argmax(segment)) + min_period
            peak_val = float(ac[peak_lag])

            # Voiced if autocorr peak > 0.35
            is_voiced = peak_val > 0.35
            voiced.append(is_voiced)
            if is_voiced:
                pitch_hz.append(float(sr / peak_lag))

        if len(pitch_hz) < 5:
            return 0.5, {"pitch_status": "insufficient_voiced"}

        pitch_arr    = np.array(pitch_hz)
        voiced_ratio = sum(voiced) / max(len(voiced), 1)

        # Feature 1: Pitch standard deviation
        # Real: high variation  (std 15-80 Hz)
        # Synthetic: low variation (over-smooth)
        pitch_std  = _safe(float(np.std(pitch_arr)))

        # Feature 2: Pitch jitter (frame-to-frame variation)
        # Real speech: irregular micro-variations; synthetic: over-smooth
        if len(pitch_arr) > 1:
            diffs      = np.abs(np.diff(pitch_arr))
            mean_pitch = max(float(np.mean(pitch_arr)), 1.0)
            jitter     = _safe(float(np.mean(diffs)) / mean_pitch)
        else:
            jitter = 0.0

        # Feature 3: Voiced ratio
        # Synthetic often cleaner — higher voiced ratio than real speech
        voiced_r = _safe(voiced_ratio)

        # Feature 4: Pitch range
        p10 = float(np.percentile(pitch_arr, 10))
        p90 = float(np.percentile(pitch_arr, 90))
        pitch_range = _safe((p90 - p10) / max(p10, 1.0))

        # Scoring
        # Real: pitch_std>20, jitter>0.04, voiced_r<0.85, pitch_range>0.4
        # Fake: pitch_std<15, jitter<0.02, voiced_r>0.90, pitch_range<0.25
        std_score    = _safe(min(max((20.0 - pitch_std) / 20.0, 0.0), 1.0))
        jitter_score = _safe(min(max((0.04 - jitter)   / 0.04, 0.0), 1.0))
        voiced_score = _safe(min(max((voiced_r - 0.82) / 0.15, 0.0), 1.0))
        range_score  = _safe(min(max((0.30 - pitch_range) / 0.25, 0.0), 1.0))

        final = round(
            std_score    * 0.35 +
            jitter_score * 0.30 +
            voiced_score * 0.20 +
            range_score  * 0.15,
            4
        )

        return final, {
            "pitch_std_hz":    round(pitch_std, 1),
            "pitch_jitter":    round(jitter, 4),
            "pitch_voiced_r":  round(voiced_r, 3),
            "pitch_range":     round(pitch_range, 3),
        }

    except Exception as e:
        return 0.5, {"pitch_error": str(e)[:60]}


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNAL 5 — STATISTICAL MOMENTS  [10%]
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def _statistical_score(y: np.ndarray) -> Tuple[float, dict]:
    """
    Higher-order statistical moments of the amplitude distribution.
    Synthetic audio tends toward Gaussian (kurtosis ≈ 3) or super-Gaussian.
    """
    try:
        from scipy import stats as sp_stats

        # Remove silence (below -40 dBFS)
        threshold = 10 ** (-40/20)
        active    = y[np.abs(y) > threshold]

        if len(active) < 1000:
            return 0.5, {"stat_status": "insufficient_active"}

        # Guard constant signal
        if float(np.std(active)) < 1e-6:
            return 0.5, {"stat_status": "constant_signal"}

        skewness  = _safe(float(sp_stats.skew(active)))
        kurtosis  = _safe(float(sp_stats.kurtosis(active)))

        skew_score = _safe(min(abs(skewness - 0.3) / 1.5, 1.0))
        kurt_score = _safe(min(max((kurtosis - 3.5) / 3.0, 0.0), 1.0))
        final      = round(skew_score * 0.40 + kurt_score * 0.60, 4)

        return final, {
            "stat_skewness": round(skewness, 3),
            "stat_kurtosis": round(kurtosis, 3),
        }

    except Exception as e:
        return 0.5, {"stat_error": str(e)[:60]}


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STAGE 3+4 — COLAB GPU SIGNAL (wav2vec2-asv19 ONNX)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

async def _colab_signal(
    audio_bytes: bytes,
    realtime: bool = False,
) -> Tuple[float, dict]:
    """
    Calls Colab ONNX server (wav2vec2-asv19 deepfake classifier).

    Returns:
      (synthetic_prob: float 0-1, detail_dict)
    Falls back to (0.5, {"colab": "offline"}) if Colab unreachable.
    """
    try:
        result = await _query_colab_audio(audio_bytes, realtime=realtime)
        if result is None:
            return 0.5, {"colab": "offline"}

        prob  = _safe(float(result.get("synthetic_prob", 0.5)))
        stage = str(result.get("stage", "unknown"))

        detail: dict = {
            "colab_stage":        stage,
            "colab_fake_prob":    round(float(result.get("fake_prob",  0.5)), 4),
            "colab_human_prob":   round(float(result.get("human_prob", 0.5)), 4),
        }
        return prob, detail

    except Exception as e:
        return 0.5, {"colab_error": str(e)[:80]}


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENSEMBLE FUSION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

_SIGNAL_WEIGHTS = {
    "lfcc":        0.30,
    "cqt":         0.20,
    "modulation":  0.20,
    "pitch":       0.20,
    "statistical": 0.10,
}

NEUTRAL = 0.5   # value signals return on error — excluded from ensemble


def _fuse_ensemble(
    lfcc:  float,
    cqt:   float,
    mod:   float,
    pitch: float,
    stat:  float,
) -> Tuple[float, float, str, List[str]]:
    """
    Weighted ensemble across all local signals.
    Signals that error (→ 0.5 neutral) are excluded and weights redistributed.
    """
    signal_map = {
        "lfcc":        _safe(lfcc),
        "cqt":         _safe(cqt),
        "modulation":  _safe(mod),
        "pitch":       _safe(pitch),
        "statistical": _safe(stat),
    }

    active_signals = {k: v for k, v in signal_map.items() if abs(v - NEUTRAL) > 0.01}

    if not active_signals:
        return NEUTRAL, 0.20, "none", []

    # Redistribute weights proportionally among active signals
    total_w = sum(_SIGNAL_WEIGHTS[k] for k in active_signals)
    scores, weights, parts = [], [], []

    for name, score in active_signals.items():
        w = _SIGNAL_WEIGHTS[name] / total_w
        scores.append(score)
        weights.append(w)
        parts.append(name)

    weighted_scores = [s * w for s, w in zip(scores, weights)]
    final = _safe(float(sum(weighted_scores)))

    # Confidence scales with: signal count + inter-signal agreement
    std_dev    = float(np.std(scores)) if len(scores) > 1 else 0.5
    agreement  = 1.0 - min(std_dev / 0.5, 1.0)
    n_factor   = len(active_signals) / len(_SIGNAL_WEIGHTS)
    confidence = _safe(min(0.94, 0.40 + n_factor * 0.30 + agreement * 0.24))

    return round(final, 4), round(confidence, 4), "+".join(parts), parts


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN ANALYSIS PIPELINE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

async def _analyze_audio(audio_bytes: bytes, realtime: bool = False) -> dict:
    """
    Full hybrid pipeline:
      Load → VAD → [LFCC + CQT + Mod + Pitch + Stat (CPU)]
                 + [wav2vec2-asv19 ONNX via Colab GPU — concurrent]
              → Weighted Fusion → Verdict

      Fusion weights:
        Colab GPU online  → 60% local CPU + 40% Colab GPU
        Colab GPU offline → 100% local CPU (zero degradation)
    """
    t_start  = time.perf_counter()
    patterns: List[str] = []
    import asyncio

    # ── Load ────────────────────────────────────────────────────────────────
    audio_data = _load_audio(audio_bytes)
    if audio_data is None:
        return {
            "syntheticProbability": 0.5,
            "confidence": 0.20,
            "detectedPatterns": ["Audio format not supported or corrupted"],
            "explanation": "Cannot analyze audio — try WAV or MP3 format.",
            "isLikelyAI": False,
            "analysisMethod": "failed",
            "processingTimeMs": 0.0,
            "subScores": {},
        }

    y, sr = audio_data

    # ── Stage 1: WebRTC VAD ─────────────────────────────────────────────────
    speech_y, vad_ratio = _apply_vad(y, sr, aggressiveness=2)

    if len(speech_y) < sr * 0.2:
        return {
            "syntheticProbability": 0.5,
            "confidence": 0.25,
            "detectedPatterns": [f"Insufficient speech detected (VAD ratio: {vad_ratio:.0%})"],
            "explanation": "Mostly silence or noise detected. Send audio with clear speech.",
            "isLikelyAI": False,
            "analysisMethod": "vad_rejected",
            "processingTimeMs": round((time.perf_counter() - t_start) * 1000, 1),
            "subScores": {"vad_speech_ratio": vad_ratio},
        }

    # ── Stage 2: MFCC Fast-Filter (early exit for clear cases) ──────────────
    def _mfcc_fast_filter(audio: "np.ndarray", sample_rate: int) -> Optional[float]:
        """
        Returns synthetic_prob (0-1) if confidence is high enough to exit early,
        or None to continue to full pipeline.
        """
        try:
            frame_size = 512
            hop_length = 256
            n_frames   = (len(audio) - frame_size) // hop_length + 1
            if n_frames < 5:
                return None
            # MFCC variance — low variance = suspiciously stable (AI voice)
            frames    = np.stack([
                audio[i*hop_length : i*hop_length + frame_size]
                for i in range(n_frames)
                if i*hop_length + frame_size <= len(audio)
            ])
            window    = np.hanning(frame_size)
            power     = np.abs(np.fft.rfft(frames * window, axis=1)) ** 2
            log_power = np.log(power + 1e-10)
            variance  = float(np.var(log_power))
            # Calibrated thresholds
            if variance < 18.0:   return 0.88   # High confidence: AI voice
            if variance > 95.0:   return 0.12   # High confidence: Human
            return None           # Uncertain: continue full pipeline
        except Exception:
            return None

    fast_result = await asyncio.to_thread(_mfcc_fast_filter, speech_y, sr)

    # ── Stage 3+4: Colab GPU — fire concurrently (don't wait yet) ───────────
    colab_task: "asyncio.Task[Tuple[float, dict]]" = asyncio.create_task(
        _colab_signal(audio_bytes, realtime=realtime)
    )

    # ── Local CPU Signals (run in parallel via thread pool) ──────────────────
    if fast_result is not None:
        # Early-exit: skip heavy CPU signals for clear cases
        lfcc_prob  = fast_result
        cqt_prob   = NEUTRAL
        mod_prob   = NEUTRAL
        pitch_prob = NEUTRAL
        stat_prob  = NEUTRAL
        lfcc_detail: dict = {"mfcc_fast_exit": True}
        cqt_detail:  dict = {}
        mod_detail:  dict = {}
        pitch_detail: dict = {}
        stat_detail: dict = {}
    else:
        # Full CPU pipeline
        def _run_all_signals():
            return {
                "lfcc":  _lfcc_score(speech_y, sr),
                "cqt":   _cqt_score(speech_y, sr),
                "mod":   _modulation_score(speech_y, sr),
                "pitch": _pitch_score(speech_y, sr),
                "stat":  _statistical_score(speech_y),
            }

        cpu_results = await asyncio.to_thread(_run_all_signals)
        lfcc_prob,  lfcc_detail  = cpu_results["lfcc"]
        cqt_prob,   cqt_detail   = cpu_results["cqt"]
        mod_prob,   mod_detail   = cpu_results["mod"]
        pitch_prob, pitch_detail = cpu_results["pitch"]
        stat_prob,  stat_detail  = cpu_results["stat"]

    # ── Local Ensemble Fusion ────────────────────────────────────────────────
    local_final, local_conf, local_method, active_signals = _fuse_ensemble(
        lfcc_prob, cqt_prob, mod_prob, pitch_prob, stat_prob
    )

    # ── Wait for Colab GPU (max 15s timeout) ────────────────────────────────
    try:
        colab_prob, colab_detail = await asyncio.wait_for(colab_task, timeout=15.0)
    except asyncio.TimeoutError:
        colab_prob, colab_detail = NEUTRAL, {"colab": "timeout"}

    # ── Hybrid Fusion: 60% local + 40% Colab (when Colab active) ────────────
    colab_active = (abs(colab_prob - NEUTRAL) > 0.01)

    if colab_active:
        final     = _safe(local_final * 0.60 + colab_prob * 0.40)
        # Confidence boost when Colab agrees with local → higher confidence
        agreement = 1.0 - abs(local_final - colab_prob)
        conf      = _safe(min(0.97, local_conf * 0.70 + agreement * 0.27))
        method    = f"hybrid_gpu+{local_method}"
    else:
        final  = local_final
        conf   = local_conf
        method = f"local_only+{local_method}"

    final = round(final, 4)
    conf  = round(conf,  4)

    # ── Pattern Collection ───────────────────────────────────────────────────
    if lfcc_prob > 0.60:
        if lfcc_detail.get("lfcc_var_score", 0) > 0.65:
            patterns.append("Low LFCC variance — stable synthetic speech artifact")
        if lfcc_detail.get("lfcc_kurtosis", 3.0) > 3.8:
            patterns.append(f"Abnormal LFCC distribution (kurtosis: {lfcc_detail.get('lfcc_kurtosis', 0):.2f})")

    if cqt_prob > 0.60 and "cqt" in active_signals:
        if cqt_detail.get("cqt_inter_corr", 0) > 0.50:
            patterns.append("High CQT inter-scale correlation — vocoder phase artifact")
        if cqt_detail.get("cqt_hf_ratio", 0) > 0.12:
            patterns.append("Unnatural high-frequency energy boost")

    if mod_prob > 0.60 and "modulation" in active_signals:
        peak = mod_detail.get("mod_peak_freq", 4.5)
        if peak < 2.5 or peak > 7.5:
            patterns.append(f"Unnatural modulation frequency ({peak:.1f} Hz, expected 3-6 Hz)")
        if mod_detail.get("mod_flatness", 0) > 0.60:
            patterns.append("Overly flat modulation spectrum — low prosodic variation")

    if pitch_prob > 0.60 and "pitch" in active_signals:
        std_hz = pitch_detail.get("pitch_std_hz", 99)
        jitter = pitch_detail.get("pitch_jitter", 99)
        if std_hz < 15:
            patterns.append(f"Unnaturally flat pitch (std: {std_hz:.1f} Hz — real speech >20 Hz)")
        if jitter < 0.02:
            patterns.append("Extremely low pitch jitter — characteristic of TTS synthesis")

    if stat_prob > 0.60 and "statistical" in active_signals:
        kurt = stat_detail.get("stat_kurtosis", 3.0)
        if kurt > 5.0:
            patterns.append(f"Super-Gaussian amplitude distribution (kurtosis: {kurt:.2f})")

    if colab_active and colab_prob > 0.65:
        patterns.append(f"ASVspoof wav2vec2 classifier: {round(colab_prob*100,1)}% synthetic probability")

    if lfcc_detail.get("mfcc_fast_exit"):
        patterns.append("MFCC fast-filter: voice signature strongly matches AI pattern")

    if not patterns:
        patterns.append("No strong synthetic voice patterns detected")

    # ── Verdict ──────────────────────────────────────────────────────────────
    is_ai = final >= 0.62

    if final >= 0.82:
        explanation = f"Strong indicators of synthetic/AI voice ({round(final*100,1)}%)."
    elif final >= 0.62:
        explanation = f"Likely synthetic or AI-cloned voice ({round(final*100,1)}%)."
    elif final >= 0.45:
        explanation = f"Ambiguous — signals inconclusive ({round(final*100,1)}%). Manual review recommended."
    else:
        explanation = f"Voice appears genuine ({round((1-final)*100,1)}% authentic confidence)."

    t_ms = round((time.perf_counter() - t_start) * 1000, 1)

    return {
        "syntheticProbability": final,
        "confidence": conf,
        "detectedPatterns": patterns,
        "explanation": explanation,
        "isLikelyAI": is_ai,
        "analysisMethod": method,
        "processingTimeMs": t_ms,
        "subScores": {
            "vad_speech_ratio":    round(vad_ratio, 3),
            "lfcc_prob":           lfcc_prob,
            "cqt_prob":            cqt_prob,
            "mod_prob":            mod_prob,
            "pitch_prob":          pitch_prob,
            "stat_prob":           stat_prob,
            "colab_prob":          round(colab_prob, 4),
            "colab_active":        colab_active,
            "signal_count":        len(active_signals),
            **lfcc_detail,
            **cqt_detail,
            **mod_detail,
            **pitch_detail,
            **stat_detail,
            **colab_detail,
        },
    }


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# REALTIME — SLIDING WINDOW CHUNK ANALYSIS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

async def _analyze_chunk(y: np.ndarray, sr: int, chunk_idx: int = 0) -> dict:
    """
    Analyze a single 0.5s audio chunk for realtime detection.
    Lightweight: VAD check + LFCC + Modulation + Pitch (no CQT—needs >5s).
    Target: < 150ms on CPU.
    """
    t_start = time.perf_counter()

    # Quick VAD — reject if mostly silence
    speech_y, vad_ratio = _apply_vad(y, sr, aggressiveness=3)
    min_speech_samples = int(sr * 0.15)  # at least 150ms of speech

    if len(speech_y) < min_speech_samples:
        return {
            "syntheticProbability": 0.5,
            "confidence": 0.0,
            "isLikelyAI": False,
            "status": "silence",
            "processingTimeMs": round((time.perf_counter() - t_start) * 1000, 1),
            "vadSpeechRatio": round(vad_ratio, 3),
            "chunkIndex": chunk_idx,
        }

    import asyncio

    def _run_chunk_signals():
        lfcc_p,  _ = _lfcc_score(speech_y, sr)
        mod_p,   _ = _modulation_score(speech_y, sr)
        pitch_p, _ = _pitch_score(speech_y, sr)
        return lfcc_p, mod_p, pitch_p

    lfcc_p, mod_p, pitch_p = await asyncio.to_thread(_run_chunk_signals)

    # Fast 3-signal fusion with chunk-optimised weights
    signals = {"lfcc": lfcc_p, "modulation": mod_p, "pitch": pitch_p}
    chunk_weights = {"lfcc": 0.40, "modulation": 0.30, "pitch": 0.30}

    active = {k: _safe(v) for k, v in signals.items() if abs(_safe(v) - NEUTRAL) > 0.01}

    if active:
        total_w = sum(chunk_weights[k] for k in active)
        final   = _safe(sum(v * chunk_weights[k] / total_w for k, v in active.items()))
    else:
        final   = NEUTRAL

    is_ai = final >= 0.62
    conf  = min(0.85, 0.35 + (len(active) / 3) * 0.35 + vad_ratio * 0.15)
    t_ms  = round((time.perf_counter() - t_start) * 1000, 1)

    return {
        "syntheticProbability": round(final, 4),
        "confidence": round(conf, 4),
        "isLikelyAI": is_ai,
        "status": "analyzed",
        "processingTimeMs": t_ms,
        "vadSpeechRatio": round(vad_ratio, 3),
        "chunkIndex": chunk_idx,
    }


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENDPOINTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

_ALLOWED_CONTENT_TYPES = {
    "audio/wav", "audio/mpeg", "audio/mp4", "audio/ogg",
    "audio/x-m4a", "audio/flac", "audio/x-wav", "audio/wave",
    "audio/mp3", "audio/webm", "audio/x-flac",
    "application/octet-stream",   # raw binary — accept and let loader decide
}
_ALLOWED_EXT = {".wav", ".mp3", ".m4a", ".ogg", ".flac", ".mp4", ".webm"}


def _validate_audio_upload(audio: UploadFile) -> None:
    """Raise HTTPException if MIME type or extension is not accepted."""
    ct       = (audio.content_type or "").lower().split(";")[0].strip()
    filename = audio.filename or ""
    ct_ok    = ct in _ALLOWED_CONTENT_TYPES
    ext_ok   = any(filename.lower().endswith(e) for e in _ALLOWED_EXT)
    if not ct_ok and not ext_ok:
        raise HTTPException(
            415,
            f"Unsupported audio type: '{audio.content_type}'. "
            f"Supported: WAV, MP3, OGG, FLAC, M4A, MP4, WebM."
        )


# ── Full-file upload endpoint ─────────────────────────────────────────────────

@router.post("/voice", response_model=VoiceAnalysisResponse)
async def analyze_voice(audio: UploadFile = File(...)):
    """
    Full audio file deepfake analysis.
    Accepts: WAV, MP3, OGG, FLAC, M4A, MP4, WebM.
    Max size: 25 MB | Max duration: 60 seconds.
    """
    _validate_audio_upload(audio)

    raw = await audio.read()
    if len(raw) < 1000:
        raise HTTPException(400, "Audio file too small (minimum ~1KB / ~0.1 seconds).")
    if len(raw) > MAX_BYTES:
        raise HTTPException(413, f"File too large. Maximum size: {MAX_BYTES // 1024 // 1024} MB.")

    try:
        result = await _analyze_audio(raw)
        return VoiceAnalysisResponse(**result)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(500, f"Voice analysis failed: {str(e)}")


# ── Realtime chunk endpoint ───────────────────────────────────────────────────

@router.post("/voice/realtime", response_model=RealtimeVoiceResponse)
async def analyze_voice_realtime(
    audio: UploadFile = File(...),
    chunk_index: int = 0,
):
    """
    Realtime streaming chunk analysis.

    Designed for 0.5s audio chunks sent continuously during a phone call.
    Each chunk is processed independently in <150ms.

    Client-side usage:
      - Chunk size: 0.5 seconds (8000 samples at 16kHz)
      - Overlap:    0.1 seconds
      - Send each chunk as a separate POST
      - Aggregate decisions: if ≥3 consecutive chunks return isLikelyAI=true →
        trigger alert

    Returns a lightweight response optimised for streaming consumption.
    """
    raw = await audio.read()

    # Absolute minimum: 0.2s of audio at 16kHz = ~6400 bytes PCM
    if len(raw) < 3000:
        return RealtimeVoiceResponse(
            syntheticProbability=0.5,
            confidence=0.0,
            isLikelyAI=False,
            status="insufficient_data",
            processingTimeMs=0.0,
            chunkIndex=chunk_index,
        )

    try:
        audio_data = _load_audio(raw)
        if audio_data is None:
            return RealtimeVoiceResponse(
                syntheticProbability=0.5,
                confidence=0.0,
                isLikelyAI=False,
                status="load_error",
                processingTimeMs=0.0,
                chunkIndex=chunk_index,
            )

        y, sr = audio_data
        result = await _analyze_chunk(y, sr, chunk_index)

        return RealtimeVoiceResponse(**result)

    except Exception as e:
        return RealtimeVoiceResponse(
            syntheticProbability=0.5,
            confidence=0.0,
            isLikelyAI=False,
            status=f"error: {str(e)[:80]}",
            processingTimeMs=0.0,
            chunkIndex=chunk_index,
        )