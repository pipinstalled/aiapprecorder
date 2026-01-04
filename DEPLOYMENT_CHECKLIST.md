# Deployment Checklist

## Before Deploying

- [ ] **FFmpeg is installed on server**
  ```bash
  ffmpeg -version
  ```
  If not installed:
  ```bash
  sudo apt-get update && sudo apt-get install -y ffmpeg
  ```

- [ ] **Updated code is in the repository**
  - Check that `main.py` has the latest conversion logic
  - Verify `preprocess_audio()` function includes conversion
  - Verify `convert_audio_to_wav()` function is present

- [ ] **Dependencies are up to date**
  ```bash
  pip install -r requirements.txt
  ```

## Deployment Steps

1. **Stop the current server**
   ```bash
   # Depending on your setup:
   sudo systemctl stop your-service
   # or
   pm2 stop your-app
   # or
   # Kill the process manually
   ```

2. **Pull/Deploy the updated code**
   ```bash
   git pull origin main
   # or copy the updated main.py
   ```

3. **Verify FFmpeg is accessible**
   ```bash
   python3 check_ffmpeg.py
   ```

4. **Start the server**
   ```bash
   # Depending on your setup:
   sudo systemctl start your-service
   # or
   pm2 start your-app
   # or
   uvicorn main:app --host 0.0.0.0 --port 8000
   ```

5. **Check server logs for startup messages**
   - Look for: "✅ FFmpeg is available for audio conversion"
   - Or: "⚠️ WARNING: FFmpeg is NOT installed"

## Testing After Deployment

1. **Test with M4A file:**
   ```bash
   curl -X POST "https://aiapp.sazjoo.com/transcribe" \
     -F "audio=@test.m4a;type=audio/x-m4a"
   ```

2. **Check server logs for:**
   - "📥 Received audio file"
   - "🔄 Converting audio file"
   - "✅ Conversion successful"
   - "✅ Loaded WAV file"

3. **If you see errors:**
   - "❌ Audio conversion failed" → FFmpeg issue
   - "File format not understood" → Conversion not happening
   - Check server logs for detailed error messages

## Verification

After deployment, the server should:
- ✅ Accept M4A files without errors
- ✅ Convert M4A to WAV automatically
- ✅ Show conversion logs in server output
- ✅ Return successful transcription

## Rollback Plan

If something goes wrong:
1. Revert to previous version of `main.py`
2. Restart server
3. Check logs for errors




