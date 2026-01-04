#!/usr/bin/env python3
"""
Quick script to check if FFmpeg is installed and accessible
This is required for audio format conversion
"""

import subprocess
import sys

def check_ffmpeg():
    """Check if FFmpeg is installed and accessible"""
    try:
        result = subprocess.run(
            ['ffmpeg', '-version'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            version_line = result.stdout.split('\n')[0]
            print(f"✅ FFmpeg is installed: {version_line}")
            return True
        else:
            print("❌ FFmpeg command failed")
            return False
    except FileNotFoundError:
        print("❌ FFmpeg is NOT installed or not in PATH")
        print("\nTo install FFmpeg:")
        print("  Ubuntu/Debian: sudo apt-get install ffmpeg")
        print("  macOS:         brew install ffmpeg")
        print("  CentOS/RHEL:   sudo yum install ffmpeg")
        return False
    except Exception as e:
        print(f"❌ Error checking FFmpeg: {e}")
        return False

def check_pydub():
    """Check if pydub can access FFmpeg"""
    try:
        from pydub import AudioSegment
        # Try to get FFmpeg path
        try:
            import pydub.utils
            ffmpeg_path = pydub.utils.which("ffmpeg")
            if ffmpeg_path:
                print(f"✅ pydub found FFmpeg at: {ffmpeg_path}")
                return True
            else:
                print("❌ pydub cannot find FFmpeg")
                return False
        except:
            print("⚠️  Could not check pydub FFmpeg path, but pydub is installed")
            return True
    except ImportError:
        print("❌ pydub is not installed")
        print("   Install with: pip install pydub")
        return False

if __name__ == "__main__":
    print("Checking FFmpeg installation...\n")
    
    ffmpeg_ok = check_ffmpeg()
    print()
    pydub_ok = check_pydub()
    
    print("\n" + "="*50)
    if ffmpeg_ok and pydub_ok:
        print("✅ All checks passed! Audio conversion should work.")
        sys.exit(0)
    else:
        print("❌ Some checks failed. Please install missing dependencies.")
        sys.exit(1)





