#!/usr/bin/env python3
"""
Diagnostic script to check why M4A conversion is failing
Run this on your server to diagnose the issue
"""

import os
import sys
import subprocess
import tempfile
from pathlib import Path

def check_ffmpeg():
    """Check if FFmpeg is installed and accessible"""
    print("=" * 60)
    print("1. Checking FFmpeg installation...")
    print("=" * 60)
    try:
        result = subprocess.run(
            ['ffmpeg', '-version'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            print("✅ FFmpeg is installed")
            print(f"   Version: {result.stdout.split(chr(10))[0]}")
            return True
        else:
            print("❌ FFmpeg check failed")
            return False
    except FileNotFoundError:
        print("❌ FFmpeg is NOT installed or not in PATH")
        print("   Install with: sudo apt-get install ffmpeg")
        return False
    except Exception as e:
        print(f"❌ Error checking FFmpeg: {e}")
        return False

def check_pydub():
    """Check if pydub is installed"""
    print("\n" + "=" * 60)
    print("2. Checking pydub installation...")
    print("=" * 60)
    try:
        from pydub import AudioSegment
        print("✅ pydub is installed")
        return True
    except ImportError:
        print("❌ pydub is NOT installed")
        print("   Install with: pip install pydub")
        return False

def test_m4a_conversion():
    """Test if M4A conversion works"""
    print("\n" + "=" * 60)
    print("3. Testing M4A conversion capability...")
    print("=" * 60)
    
    try:
        from pydub import AudioSegment
        import tempfile
        
        # Create a dummy test (we can't test without an actual M4A file)
        print("   Note: This requires an actual M4A file to test")
        print("   To test manually, run:")
        print("   python3 -c \"from pydub import AudioSegment; AudioSegment.from_file('test.m4a', format='m4a')\"")
        return True
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def check_backend_code():
    """Check if backend code has conversion logic"""
    print("\n" + "=" * 60)
    print("4. Checking backend code for conversion logic...")
    print("=" * 60)
    
    backend_file = Path(__file__).parent / "main.py"
    if not backend_file.exists():
        print(f"❌ Backend file not found: {backend_file}")
        return False
    
    with open(backend_file, 'r') as f:
        content = f.read()
    
    checks = {
        "convert_audio_to_wav function": "def convert_audio_to_wav" in content,
        "pydub import": "from pydub import AudioSegment" in content,
        "preprocess_audio calls convert": "convert_audio_to_wav" in content and "preprocess_audio" in content,
        "FFmpeg check on startup": "ffmpeg" in content.lower() and "startup" in content.lower(),
    }
    
    all_passed = True
    for check_name, passed in checks.items():
        if passed:
            print(f"✅ {check_name}: Found")
        else:
            print(f"❌ {check_name}: NOT found")
            all_passed = False
    
    return all_passed

def check_server_running():
    """Check if server is running"""
    print("\n" + "=" * 60)
    print("5. Checking if backend server is running...")
    print("=" * 60)
    
    try:
        import requests
        try:
            response = requests.get("https://aiapp.sazjoo.com/health", timeout=5)
            if response.status_code == 200:
                print("✅ Backend server is running")
                print(f"   Response: {response.json()}")
                return True
            else:
                print(f"⚠️  Backend responded with status {response.status_code}")
                return False
        except requests.exceptions.RequestException as e:
            print(f"❌ Cannot reach backend server: {e}")
            return False
    except ImportError:
        print("⚠️  requests library not installed, skipping server check")
        print("   Install with: pip install requests")
        return None

def main():
    print("\n" + "=" * 60)
    print("M4A Conversion Diagnostic Tool")
    print("=" * 60)
    print()
    
    results = {
        "FFmpeg": check_ffmpeg(),
        "pydub": check_pydub(),
        "Backend Code": check_backend_code(),
        "Server Running": check_server_running(),
    }
    
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    
    for check_name, result in results.items():
        if result is True:
            status = "✅ PASS"
        elif result is False:
            status = "❌ FAIL"
        else:
            status = "⚠️  SKIP"
        print(f"{check_name}: {status}")
    
    print("\n" + "=" * 60)
    print("RECOMMENDATIONS")
    print("=" * 60)
    
    if not results.get("FFmpeg"):
        print("1. ❌ CRITICAL: Install FFmpeg")
        print("   sudo apt-get update")
        print("   sudo apt-get install -y ffmpeg")
        print("   ffmpeg -version  # Verify")
    
    if not results.get("pydub"):
        print("2. ❌ CRITICAL: Install pydub")
        print("   pip install pydub")
    
    if not results.get("Backend Code"):
        print("3. ❌ CRITICAL: Backend code is missing conversion logic")
        print("   Make sure main.py has the updated code with convert_audio_to_wav()")
    
    if results.get("Server Running") is False:
        print("4. ⚠️  Backend server is not running or not accessible")
        print("   Restart your backend service after making changes")
    
    if all(results.values()):
        print("\n✅ All checks passed!")
        print("   If you're still getting errors, check server logs:")
        print("   - sudo journalctl -u <your-service-name> -f")
        print("   - Or check your PM2/supervisor logs")
    else:
        print("\n❌ Some checks failed. Fix the issues above and restart your server.")

if __name__ == "__main__":
    main()


