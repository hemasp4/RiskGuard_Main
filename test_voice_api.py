"""Test voice endpoint with real and AI audio files to check for false positives."""
import urllib.request
import json
import os

BACKEND = "http://localhost:8000"
SAMPLES_DIR = r"c:\dev\flutter_pro\RiskGaurd1\audio_samples"

test_files = [
    ("real_samples/1089_134686_000007_000002.wav", "REAL"),
    ("real_samples/1089_134686_000009_000000.wav", "REAL"),
    ("flashSpeech/101.wav", "AI"),
    ("open_AI/alloy_25.wav", "AI"),
]

for fname, label in test_files:
    filepath = os.path.join(SAMPLES_DIR, fname.replace("/", os.sep))
    if not os.path.exists(filepath):
        print(f"SKIP {fname} (not found)")
        continue
    
    with open(filepath, "rb") as f:
        file_bytes = f.read()
    
    # Build multipart form data manually
    boundary = b"----WebKitFormBoundary7MA4YWxkTrZu0gW"
    body = b""
    body += b"--" + boundary + b"\r\n"
    body += b'Content-Disposition: form-data; name="file"; filename="' + os.path.basename(filepath).encode() + b'"\r\n'
    body += b"Content-Type: audio/wav\r\n\r\n"
    body += file_bytes
    body += b"\r\n--" + boundary + b"--\r\n"
    
    req = urllib.request.Request(
        f"{BACKEND}/api/v1/analyze/voice",
        data=body,
        headers={
            "Content-Type": f"multipart/form-data; boundary={boundary.decode()}",
        },
        method="POST",
    )
    
    try:
        resp = urllib.request.urlopen(req, timeout=30)
        result = json.loads(resp.read().decode())
        prob = result.get("syntheticProbability", "?")
        is_ai = result.get("isLikelyAI", "?")
        conf = result.get("confidence", "?")
        ms = result.get("processingTimeMs", "?")
        print(f"{label:4s} | {fname:45s} | prob={prob:.4f} is_ai={is_ai} conf={conf:.4f} time={ms}ms")
    except Exception as e:
        print(f"{label:4s} | {fname:45s} | ERROR: {e}")
