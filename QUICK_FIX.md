# Quick Fix for M4A Upload Error

## The Error
```
{
  "success": false,
  "error": "File format b'\\x00\\x00\\x00\\x1c' not understood. Only 'RIFF' and 'RIFX' supported.",
  "status_code": 400
}
```

## Root Cause
The server is trying to read M4A files as WAV without converting them first. This happens when:
1. **FFmpeg is not installed** (most common)
2. **Updated code is not deployed** to the server
3. **Server hasn't been restarted** after code update

## Quick Fix (3 Steps)

### Step 1: Install FFmpeg on Server
```bash
# SSH into your server, then:
sudo apt-get update
sudo apt-get install -y ffmpeg

# Verify installation:
ffmpeg -version
```

### Step 2: Deploy Updated Code
Copy the updated `main.py` to your server, or:
```bash
# If using git:
git pull origin main
```

### Step 3: Restart Server
```bash
# Depending on your setup:
sudo systemctl restart your-service
# or
pm2 restart your-app
# or restart manually
```

## Verify It Works

After completing the steps above, test:
```bash
curl -X POST "https://aiapp.sazjoo.com/transcribe" \
  -F "audio=@test.m4a;type=audio/x-m4a"
```

**Expected result:** Success with transcription, not the RIFF error.

## Check Server Logs

After restarting, check server logs for:
- ✅ "FFmpeg is available for audio conversion"
- ✅ "📥 Received audio file"
- ✅ "🔄 Converting audio file"
- ✅ "✅ Conversion successful"

If you see:
- ❌ "FFmpeg is NOT installed" → Install FFmpeg (Step 1)
- ❌ "Audio conversion failed" → FFmpeg issue
- ❌ Still getting RIFF error → Code not deployed or server not restarted

## Still Not Working?

1. **Check FFmpeg:**
   ```bash
   which ffmpeg
   ffmpeg -version
   ```

2. **Check if code is updated:**
   ```bash
   # On server, check main.py has convert_audio_to_wav function
   grep -n "convert_audio_to_wav" main.py
   ```

3. **Check server logs** for detailed error messages

4. **Test FFmpeg directly:**
   ```bash
   ffmpeg -i test.m4a test.wav
   ```




