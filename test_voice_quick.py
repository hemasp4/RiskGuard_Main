"""Quick test: voice endpoint with real audio after MFCC fast-filter fix."""
import requests

BACKEND = "http://localhost:8000"
files = [
    r"c:\dev\flutter_pro\RiskGaurd1\audio_samples\real_samples\1089_134686_000007_000002.wav",
    r"c:\dev\flutter_pro\RiskGaurd1\audio_samples\flashSpeech\101.wav",
]

for f in files:
    with open(f, "rb") as fp:
        r = requests.post(
            f"{BACKEND}/api/v1/analyze/voice",
            files={"audio": (f.split("\\")[-1], fp, "audio/wav")},
            timeout=30,
        )
    if r.status_code == 200:
        d = r.json()
        label = "REAL" if "real_samples" in f else "AI"
        print(f"{label}: prob={d['syntheticProbability']:.4f} isAI={d['isLikelyAI']} conf={d['confidence']:.4f} signals={d['subScores'].get('signal_count','?')} fast_exit={d['subScores'].get('mfcc_fast_exit','no')}")
    else:
        print(f"ERROR {r.status_code}: {r.text[:100]}")
