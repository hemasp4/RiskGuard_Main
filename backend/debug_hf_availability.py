
import requests
import os
from dotenv import load_dotenv

load_dotenv()

HF_TOKEN = os.getenv("HF_TOKEN")
BASE_URL = "https://router.huggingface.co/ht-inference/models"

models = [
    "Neural-Hacker/distilbert_ai_text_detector",     # Candidate from search
    "Lokibb/DistilBERT-AI-Detector",                 # Candidate guess
    "distilbert-base-uncased",                       # Base model (fallback)
    "Hello-SimpleAI/chatgpt-detector-roberta",       # Current working model
]

token_display = "None"
if HF_TOKEN and len(HF_TOKEN) > 8:
    token_display = f"{HF_TOKEN[:4]}...{HF_TOKEN[-4:]}"
elif HF_TOKEN:
    token_display = "Set (Short)"

print(f"Checking models with token: {token_display}\n")

headers = {"Authorization": f"Bearer {HF_TOKEN}"} if HF_TOKEN else {}

for model in models:
    url = f"{BASE_URL}/{model}"
    print(f"Checking: {model}")
    try:
        # Just check status, not actually run inference (GET /models returns info sometimes, but for inference API we usually POST)
        # However, GET on the model page itself works to check existence, but for API endpoint...
        # Let's try a small dummy inference
        if "wav2vec2" in model:
            # Skip audio for now or send empty bytes - might fail 400 not 404
             payload = b"dummy"
        elif "siglip" in model:
             payload = {"inputs": "dummy text"} # Might fail 400, but checking for 404
        else:
             payload = {"inputs": "This is a test."}

        response = requests.post(url, headers=headers, json=payload if isinstance(payload, dict) else None, data=payload if isinstance(payload, bytes) else None)
        
        print(f"  Status: {response.status_code}")
        if response.status_code == 404:
            print("  ❌ 404 Not Found - Model ID incorrect or private")
        elif response.status_code == 200:
            print("  ✅ 200 OK - Model available")
        else:
            print(f"  ⚠️ {response.status_code} - {response.text[:100]}")
            
    except Exception as e:
        print(f"  Error: {e}")
    print("-" * 30)
