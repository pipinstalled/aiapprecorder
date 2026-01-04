# Verify Backend Deployment

## Problem
After restarting the service, M4A files are still failing with:
```json
{
  "success": false,
  "error": "File format b'\\x00\\x00\\x00\\x1c' not understood. Only 'RIFF' and 'RIFX' supported.",
  "status_code": 400
}
```

This suggests the updated code with conversion logic is not being used.

## Quick Fix Steps

### Step 1: Verify Code is Updated
```bash
# SSH into your server
ssh user@your-server

# Check if main.py has the conversion code
grep -n "convert_audio_to_wav" /root/sazjoo/aiapprecorder/main.py

# Check if preprocess_audio calls conversion
grep -n "should_convert" /root/sazjoo/aiapprecorder/main.py
```

### Step 2: Clear Python Cache
```bash
# Remove all Python cache files
find /root/sazjoo/aiapprecorder -type d -name "__pycache__" -exec rm -r {} +
find /root/sazjoo/aiapprecorder -name "*.pyc" -delete
find /root/sazjoo/aiapprecorder -name "*.pyo" -delete
```

### Step 3: Verify Service Configuration
```bash
# Find your service name
systemctl list-units --type=service | grep -iE "sazjoo|api|backend"

# Check service file location
systemctl show sazjoo.service -p FragmentPath

# Check what directory the service runs from
systemctl show sazjoo.service -p WorkingDirectory

# Check what command it runs
grep "ExecStart" /etc/systemd/system/sazjoo.service
```

### Step 4: Ensure Code is in the Right Location
```bash
# Make sure main.py is where the service expects it
# Check the WorkingDirectory from Step 3
ls -la /root/sazjoo/aiapprecorder/main.py

# If it's in a different location, either:
# Option A: Update the service file to point to the correct location
# Option B: Copy main.py to where the service expects it
```

### Step 5: Verify Dependencies
```bash
# Check FFmpeg
ffmpeg -version

# Check Python packages
python3 -c "import pydub; print('pydub:', pydub.__version__)"
python3 -c "import scipy; print('scipy installed')"
python3 -c "import transformers; print('transformers installed')"
```

### Step 6: Restart Service
```bash
# Restart the service
sudo systemctl restart sazjoo.service

# Check status
sudo systemctl status sazjoo.service

# Watch logs
sudo journalctl -u sazjoo.service -f
```

## Using the Verification Script

I've created a script that does all of the above automatically:

```bash
# Copy the script to your server
scp verify_and_fix_deployment.sh user@your-server:/tmp/

# SSH into server
ssh user@your-server

# Make executable and run
chmod +x /tmp/verify_and_fix_deployment.sh
sudo /tmp/verify_and_fix_deployment.sh
```

## Common Issues

### Issue 1: Code Not Updated on Server
**Symptom**: Service restarts but still has old behavior.

**Solution**:
```bash
# Make sure you've copied the updated main.py to the server
# Check the file modification time
ls -la /root/sazjoo/aiapprecorder/main.py

# If it's old, copy the new version
scp main.py user@server:/root/sazjoo/aiapprecorder/
```

### Issue 2: Python Cache
**Symptom**: Code changes don't take effect.

**Solution**:
```bash
# Clear all Python cache
find /root/sazjoo/aiapprecorder -type d -name "__pycache__" -exec rm -r {} +
find /root/sazjoo/aiapprecorder -name "*.pyc" -delete
```

### Issue 3: Service Running from Wrong Directory
**Symptom**: Service can't find main.py or uses wrong version.

**Solution**:
```bash
# Check service file
cat /etc/systemd/system/sazjoo.service

# Update WorkingDirectory if needed
sudo nano /etc/systemd/system/sazjoo.service
# Change WorkingDirectory=/path/to/correct/directory

# Reload systemd
sudo systemctl daemon-reload
sudo systemctl restart sazjoo.service
```

### Issue 4: FFmpeg Not Found
**Symptom**: Conversion fails with FFmpeg errors.

**Solution**:
```bash
# Install FFmpeg
sudo apt-get update
sudo apt-get install -y ffmpeg

# Verify installation
ffmpeg -version
```

### Issue 5: Virtual Environment Issues
**Symptom**: Dependencies not found after restart.

**Solution**:
```bash
# If using virtual environment, make sure service activates it
# Check service file ExecStart:
# Should be: /path/to/venv/bin/python /path/to/main.py
# Or: /path/to/venv/bin/uvicorn main:app ...

# Activate venv and install dependencies
source /path/to/venv/bin/activate
pip install pydub scipy transformers torch fastapi uvicorn
```

## Testing After Fix

```bash
# Test with M4A file
curl -X POST http://localhost:8001/transcribe \
  -F 'audio=@test.m4a;type=audio/x-m4a'

# Should return success, not format error
```

## Debugging

If still not working, check logs for conversion attempts:

```bash
# Watch logs in real-time
sudo journalctl -u sazjoo.service -f

# Look for these log messages:
# - "[CONVERT] Starting conversion"
# - "[PREPROCESS] Converting ... file to WAV format"
# - "[TRANSCRIBE] Starting audio preprocessing"

# If you don't see these, conversion is not being called
```

## Manual Code Check

Verify these key parts exist in main.py:

1. **convert_audio_to_wav function** (around line 145):
```python
def convert_audio_to_wav(input_path: str, output_path: str) -> str:
    # Should have pydub AudioSegment.from_file() calls
```

2. **preprocess_audio function** (around line 292):
```python
def preprocess_audio(...):
    # Should have:
    should_convert = False
    if file_ext != '.wav':
        should_convert = True
    if should_convert:
        convert_audio_to_wav(...)
```

3. **/transcribe endpoint** (around line 581):
```python
@app.post("/transcribe", ...)
async def transcribe_audio_file(...):
    # Should call preprocess_audio which handles conversion
    audio_array, duration = preprocess_audio(temp_path)
```

If any of these are missing, the code is not updated!

