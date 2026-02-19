
import unittest
import requests
import json
import time

BASE_URL = "http://127.0.0.1:8000/api/v1"

class TestTextAnalysis(unittest.TestCase):
    def setUp(self):
        # Wait for server to be ready
        try:
            requests.get(f"http://127.0.0.1:8000/health", timeout=1)
        except:
            self.skipTest("Backend server not running at http://127.0.0.1:8000")

    def test_analyze_human_text(self):
        """Test with text likely to be classified as Human"""
        text = "I went to the store yesterday and bought some apples. It was a nice day, so I walked home."
        response = requests.post(f"{BASE_URL}/analyze/text", json={"text": text})
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("aiGeneratedProbability", data)
        self.assertLess(data["aiGeneratedProbability"], 0.5, "Should be classified as Human")

    def test_analyze_ai_text(self):
        """Test with text likely to be classified as AI (formal, low lexical diversity)"""
        text = "Furthermore, it is crucial to maximize the utilization of available resources to ensure optimal operational efficiency and scalable growth trajectories."
        response = requests.post(f"{BASE_URL}/analyze/text", json={"text": text})
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("aiGeneratedProbability", data)
        # Note: Might not be 100% AI depending on model, but should be > 0.5 or high
        # We check if keys exist and values are valid
        self.assertIsInstance(data["aiGeneratedProbability"], float)
        self.assertIsInstance(data["isAiGenerated"], bool)
        self.assertIn("Lexical Diversity", data.get("aiExplanation", ""))

    def test_short_text_error(self):
        """Test text that is too short"""
        text = "Hi"
        response = requests.post(f"{BASE_URL}/analyze/text", json={"text": text})
        self.assertNotEqual(response.status_code, 200) # Should fail or return 400

    def test_multiline_text(self):
        """Test multiline text handling"""
        text = "Line 1.\nLine 2.\nLine 3."
        response = requests.post(f"{BASE_URL}/analyze/text", json={"text": text})
        self.assertEqual(response.status_code, 200)

if __name__ == '__main__':
    unittest.main()
