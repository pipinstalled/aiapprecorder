# Backend Logging Guide

## Overview

The backend now has comprehensive logging to help diagnose M4A conversion issues. All logs include timestamps and are prefixed with tags like `[TRANSCRIBE]`, `[PREPROCESS]`, and `[CONVERT]`.

## What to Look For

### 1. When You Upload an M4A File

You should see logs like this:

```
[TRANSCRIBE] New transcription request received
[TRANSCRIBE] 📥 Received audio file: new.m4a
[TRANSCRIBE]    Extension: .m4a
[TRANSCRIBE]    Content-Type: audio/x-m4a
[TRANSCRIBE] File header (first 16 bytes, hex): 00 00 00 1c 66 74 79 70 4d 34 41 20 00 00 00 00
```

**Key Info:**
- The file extension detected
- The content-type
- The file header (first 16 bytes) - M4A files typically start with `00 00 00` or `ftyp` (66 74 79 70)

### 2. During Preprocessing

```
[PREPROCESS] Processing audio file: /tmp/xyz.m4a (extension: .m4a)
[PREPROCESS] File size: 12345 bytes
[PREPROCESS] File header (hex): 00 00 00 1c 66 74 79 70
[PREPROCESS] File is NOT WAV format (header: b'\x00\x00\x00\x1c')
[PREPROCESS] File extension '.m4a' indicates non-WAV format, will convert
[PREPROCESS] 🔄 Converting .m4a file to WAV format...
```

**Key Info:**
- Whether the file is detected as WAV or not
- The decision to convert or skip conversion

### 3. During Conversion

```
[CONVERT] Starting conversion: /tmp/xyz.m4a (format: .m4a)
[CONVERT] Input file header (hex): 00 00 00 1c 66 74 79 70 4d 34 41 20
[CONVERT] Detected format: m4a
[CONVERT] Attempting to load audio file...
[CONVERT] Loading as M4A using from_file()...
[CONVERT] ✅ Audio loaded successfully
[CONVERT] ✅ Audio loaded: 5000ms, 44100Hz, 2 channels
[CONVERT] Exporting to WAV format...
[CONVERT] ✅ Export completed
[CONVERT] Output file header (hex): 52 49 46 46
[CONVERT] ✅ Valid WAV header confirmed
```

**Key Info:**
- Whether pydub successfully loads the M4A file
- If FFmpeg is missing, you'll see an error here
- The output WAV header should be `52 49 46 46` (which is "RIFF" in ASCII)

### 4. If Conversion Fails

You'll see errors like:

```
[CONVERT] ❌ Failed to load audio file: [Errno 2] No such file or directory: 'ffmpeg'
[CONVERT] Full traceback: ...
```

Or:

```
[CONVERT] ❌ Failed to export WAV file: ...
```

### 5. When Reading with scipy

```
[PREPROCESS] Reading WAV file with scipy.wavfile.read(): /tmp/converted.wav
[PREPROCESS] Final file header before scipy read: b'RIFF'
[PREPROCESS] ✅ Loaded WAV file: 80000 samples at 16000Hz
```

**If this fails**, you'll see:
```
[PREPROCESS] ❌ Failed to read WAV file with scipy: File format b'\x00\x00\x00\x1c' not understood...
[PREPROCESS] This is the exact error the user is seeing!
```

This means the conversion didn't work - the file still has M4A headers instead of WAV headers.

## Common Issues and What Logs Tell You

### Issue 1: FFmpeg Not Installed

**Logs will show:**
```
[CONVERT] ❌ Failed to load audio file: [Errno 2] No such file or directory: 'ffmpeg'
```

**Fix:** Install FFmpeg: `sudo apt-get install ffmpeg`

### Issue 2: Conversion Runs But Output Is Still M4A

**Logs will show:**
```
[CONVERT] ✅ Export completed
[CONVERT] Output file header (hex): 00 00 00 1c  # Still M4A header!
[CONVERT] ❌ Invalid WAV header! Expected RIFF or RIFX, got: b'\x00\x00\x00\x1c'
```

**This means:** FFmpeg export failed silently, or pydub didn't actually convert the file.

### Issue 3: File Never Gets Converted

**Logs will show:**
```
[PREPROCESS] File appears to be WAV format, skipping conversion
[PREPROCESS] Reading WAV file with scipy.wavfile.read(): /tmp/xyz.m4a
[PREPROCESS] ❌ Failed to read WAV file: File format b'\x00\x00\x00\x1c' not understood...
```

**This means:** The logic incorrectly thought the file was WAV and skipped conversion.

## How to View Logs

### If using systemd:
```bash
sudo journalctl -u <your-service-name> -f
```

### If using PM2:
```bash
pm2 logs
```

### If using supervisor:
```bash
sudo tail -f /var/log/supervisor/your-app.log
```

### If running directly:
Logs will appear in the terminal/console where you started the server.

## Next Steps

1. **Deploy the updated code** with logging
2. **Restart your backend server**
3. **Try uploading an M4A file** via Swagger or your app
4. **Check the logs** to see exactly where it fails
5. **Share the logs** so we can identify the exact issue

The logs will show us:
- ✅ If FFmpeg is installed and working
- ✅ If pydub can load the M4A file
- ✅ If the conversion actually creates a WAV file
- ✅ If scipy can read the converted file
- ✅ The exact point where it fails


