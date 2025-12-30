# Troubleshooting Guide

## Error: "File format b'\\x00\\x00\\x00\\x1c' not understood. Only 'RIFF' and 'RIFX' supported."

### Problem
This error occurs when trying to upload M4A (or other non-WAV) files. The backend is trying to read the file as WAV before converting it.

### Root Cause
**FFmpeg is not installed** on the server. The `pydub` library requires FFmpeg to convert audio formats.

### Solution

1. **Install FFmpeg on your server:**

   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install -y ffmpeg
   
   # macOS
   brew install ffmpeg
   
   # CentOS/RHEL
   sudo yum install epel-release
   sudo yum install ffmpeg
   ```

2. **Verify FFmpeg is installed:**

   ```bash
   ffmpeg -version
   ```

   You should see output like:
   ```
   ffmpeg version 4.x.x Copyright (c) 2000-2023...
   ```

3. **Check if pydub can find FFmpeg:**

   ```bash
   python3 check_ffmpeg.py
   ```

4. **Restart your backend server** after installing FFmpeg.

### Verification

After installing FFmpeg, test with an M4A file:

```bash
curl -X POST "https://aiapp.sazjoo.com/transcribe" \
  -F "audio=@test.m4a"
```

You should see in the server logs:
```
🔄 Converting audio file: ... (format: .m4a)
   Loading as M4A...
   ✅ Audio loaded: ...
   ✅ Successfully converted to WAV: ...
```

### Additional Checks

If FFmpeg is installed but still not working:

1. **Check FFmpeg is in PATH:**
   ```bash
   which ffmpeg
   ```

2. **Check pydub can access FFmpeg:**
   ```python
   from pydub import AudioSegment
   import pydub.utils
   print(pydub.utils.which("ffmpeg"))
   ```

3. **Check server logs** for conversion messages:
   - Look for "🔄 Converting audio file" messages
   - Look for "✅ Conversion successful" messages
   - Look for "❌" error messages

### Expected Behavior After Fix

- ✅ M4A files upload successfully
- ✅ MP3 files upload successfully  
- ✅ All formats are automatically converted to WAV
- ✅ Server logs show conversion progress
- ✅ No more "RIFF/RIFX" errors

### Still Having Issues?

1. Check server logs for detailed error messages
2. Verify FFmpeg version: `ffmpeg -version`
3. Test FFmpeg directly: `ffmpeg -i input.m4a output.wav`
4. Check file permissions on the server
5. Verify pydub version: `pip show pydub`

