#!/usr/bin/env python3
"""
Test script for the Persian Speech-to-Text FastAPI service
"""

import base64
import json
import os
from pathlib import Path

import requests

# Configuration
BASE_URL = "http://localhost:8000"


def test_health():
    """Test health endpoint"""
    print("Testing health endpoint...")
    try:
        response = requests.get(f"{BASE_URL}/health")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Health check passed: {data['status']}")
            print(f"   Model loaded: {data['model_loaded']}")
            return True
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Health check error: {e}")
        return False


def test_base64_transcription():
    """Test base64 transcription endpoint"""
    print("\nTesting base64 transcription...")

    # Create a simple test audio (silence) - in real usage, you'd have actual audio
    try:
        # This is a minimal WAV file header for silence (1 second, 16kHz, mono)
        wav_header = b"RIFF$\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00\x00>\x00\x00\x00}\x00\x00\x02\x00\x10\x00data\x00\x00\x00\x00"
        wav_data = wav_header + b"\x00" * 32000  # 1 second of silence at 16kHz

        # Encode to base64
        audio_base64 = base64.b64encode(wav_data).decode("utf-8")

        # Send request
        payload = {"audio_base64": audio_base64}
        response = requests.post(
            f"{BASE_URL}/transcribe-base64",
            json=payload,
            headers={"Content-Type": "application/json"},
        )

        if response.status_code == 200:
            data = response.json()
            print(f"✅ Base64 transcription successful")
            print(f"   Transcription: '{data['transcription']}'")
            print(f"   Confidence: {data['confidence']:.3f}")
            print(f"   Processing time: {data['processing_time']:.2f}s")
            return True
        else:
            print(f"❌ Base64 transcription failed: {response.status_code}")
            print(f"   Error: {response.text}")
            return False

    except Exception as e:
        print(f"❌ Base64 transcription error: {e}")
        return False


def test_file_upload():
    """Test file upload transcription endpoint"""
    print("\nTesting file upload transcription...")

    try:
        # Create a temporary test audio file
        test_audio_path = "test_audio.wav"

        # Create minimal WAV file
        wav_header = b"RIFF$\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00\x00>\x00\x00\x00}\x00\x00\x02\x00\x10\x00data\x00\x00\x00\x00"
        wav_data = wav_header + b"\x00" * 32000  # 1 second of silence

        with open(test_audio_path, "wb") as f:
            f.write(wav_data)

        # Upload file
        with open(test_audio_path, "rb") as f:
            files = {"audio": ("test_audio.wav", f, "audio/wav")}
            response = requests.post(f"{BASE_URL}/transcribe", files=files)

        # Clean up
        os.remove(test_audio_path)

        if response.status_code == 200:
            data = response.json()
            print(f"✅ File upload transcription successful")
            print(f"   Transcription: '{data['transcription']}'")
            print(f"   Confidence: {data['confidence']:.3f}")
            print(f"   Processing time: {data['processing_time']:.2f}s")
            return True
        else:
            print(f"❌ File upload transcription failed: {response.status_code}")
            print(f"   Error: {response.text}")
            return False

    except Exception as e:
        print(f"❌ File upload transcription error: {e}")
        return False


def test_error_handling():
    """Test error handling"""
    print("\nTesting error handling...")

    try:
        # Test invalid base64
        payload = {"audio_base64": "invalid_base64"}
        response = requests.post(
            f"{BASE_URL}/transcribe-base64",
            json=payload,
            headers={"Content-Type": "application/json"},
        )

        if response.status_code == 400:
            print("✅ Invalid base64 error handling works")
            return True
        else:
            print(f"❌ Error handling failed: {response.status_code}")
            return False

    except Exception as e:
        print(f"❌ Error handling test error: {e}")
        return False


def main():
    """Run all tests"""
    print("🧪 Testing Persian Speech-to-Text FastAPI Service")
    print("=" * 50)

    tests = [
        ("Health Check", test_health),
        ("Base64 Transcription", test_base64_transcription),
        ("File Upload", test_file_upload),
        ("Error Handling", test_error_handling),
    ]

    passed = 0
    total = len(tests)

    for test_name, test_func in tests:
        print(f"\n📋 {test_name}")
        print("-" * 30)
        if test_func():
            passed += 1

    print("\n" + "=" * 50)
    print(f"📊 Test Results: {passed}/{total} tests passed")

    if passed == total:
        print("🎉 All tests passed! Service is ready to use.")
    else:
        print("⚠️  Some tests failed. Check the service and try again.")


if __name__ == "__main__":
    main()
