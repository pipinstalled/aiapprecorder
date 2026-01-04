# Fix 404 Error After Restarting persian-speech-api.service

## Problem
When restarting `persian-speech-api.service`, you get a 404 error.

## Common Causes

### 1. Service Not Starting
The service might be failing to start.

**Check:**
```bash
sudo systemctl status persian-speech-api.service
```

**Look for:**
- `Active: active (running)` - Service is running ✅
- `Active: failed` - Service failed to start ❌
- `Active: inactive (dead)` - Service is stopped ❌

### 2. Wrong Port
Service might be running on a different port.

**Check:**
```bash
# Check what's listening on port 8001
sudo lsof -i :8001
# OR
sudo netstat -tlnp | grep :8001
# OR
sudo ss -tlnp | grep :8001
```

### 3. Wrong Host/Binding
Service might be binding to 127.0.0.1 instead of 0.0.0.0.

**Check service file:**
```bash
grep "ExecStart" /etc/systemd/system/persian-speech-api.service
```

Should have: `--host 0.0.0.0` (not `--host 127.0.0.1`)

### 4. Service Using Wrong Code
Service might be using old code or wrong directory.

**Check:**
```bash
# Check working directory
sudo systemctl show persian-speech-api.service -p WorkingDirectory

# Check if main.py exists there
ls -la $(sudo systemctl show persian-speech-api.service -p WorkingDirectory --value)/main.py
```

## Quick Fix Steps

### Step 1: Check Service Status
```bash
sudo systemctl status persian-speech-api.service
```

### Step 2: Check Logs
```bash
# Recent logs
sudo journalctl -u persian-speech-api.service -n 50

# Follow logs in real-time
sudo journalctl -u persian-speech-api.service -f
```

### Step 3: Check Service Configuration
```bash
cat /etc/systemd/system/persian-speech-api.service
```

**Should look like:**
```ini
[Service]
WorkingDirectory=/path/to/your/main.py/directory
ExecStart=/path/to/uvicorn main:app --host 0.0.0.0 --port 8001
```

### Step 4: Verify Main.py Location
```bash
# Find where you run uvicorn manually
# (The directory where: uvicorn main:app --reload --port 8001 works)

# Make sure service WorkingDirectory matches that location
```

### Step 5: Update Service File
```bash
sudo nano /etc/systemd/system/persian-speech-api.service
```

**Update to:**
```ini
[Unit]
Description=Persian Speech-to-Text FastAPI Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/sazjoo/aiapprecorder  # ← Your actual directory
Environment="PATH=/root/sazjoo/aiapprecorder/venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/root/sazjoo/aiapprecorder/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8001
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### Step 6: Reload and Restart
```bash
# Reload systemd
sudo systemctl daemon-reload

# Clear Python cache
find /root/sazjoo/aiapprecorder -type d -name "__pycache__" -exec rm -r {} + 2>/dev/null
find /root/sazjoo/aiapprecorder -name "*.pyc" -delete 2>/dev/null

# Restart service
sudo systemctl restart persian-speech-api.service

# Check status
sudo systemctl status persian-speech-api.service
```

### Step 7: Test
```bash
# Test health endpoint
curl http://localhost:8001/health

# Should return: {"status":"healthy","model_loaded":true,...}

# Test docs
curl http://localhost:8001/docs
# Should return HTML (or open in browser: http://your-server:8001/docs)
```

## Using the Automated Script

I've created a script that fixes everything automatically:

```bash
# Copy to server
scp fix_persian_speech_api.sh user@server:/tmp/

# On server
chmod +x /tmp/fix_persian_speech_api.sh
sudo /tmp/fix_persian_speech_api.sh
```

## Troubleshooting 404 Errors

### Error: Connection Refused
**Meaning:** Service is not running or not listening on that port.

**Fix:**
```bash
# Check if service is running
sudo systemctl status persian-speech-api.service

# If not running, start it
sudo systemctl start persian-speech-api.service

# Check logs for errors
sudo journalctl -u persian-speech-api.service -n 50
```

### Error: 404 Not Found
**Meaning:** Service is running but route doesn't exist.

**Possible causes:**
1. Wrong FastAPI app instance
2. Routes not registered
3. Wrong base path

**Check:**
```bash
# Test root endpoint
curl http://localhost:8001/

# Test health endpoint
curl http://localhost:8001/health

# Check what routes are available
curl http://localhost:8001/docs
# Open in browser to see all endpoints
```

### Error: Service Starts Then Stops
**Meaning:** Service crashes after starting.

**Check logs:**
```bash
sudo journalctl -u persian-speech-api.service -n 100 | grep -i error
```

**Common causes:**
- Import errors (missing dependencies)
- Port already in use
- Permission issues
- Wrong Python environment

### Port Already in Use
**Check:**
```bash
sudo lsof -i :8001
```

**Kill process if needed:**
```bash
# Find PID
sudo lsof -i :8001 | grep LISTEN

# Kill it (replace PID)
sudo kill -9 <PID>
```

### Wrong Python Environment
**Check:**
```bash
# What Python the service uses
grep "ExecStart" /etc/systemd/system/persian-speech-api.service

# Test if that Python can import main
/path/to/python -c "import sys; sys.path.insert(0, '/path/to/main.py/dir'); import main"
```

## Verification Checklist

After fixing, verify:

- [ ] Service status shows `active (running)`
- [ ] `curl http://localhost:8001/health` returns JSON
- [ ] `curl http://localhost:8001/docs` returns HTML
- [ ] Logs show service started successfully
- [ ] No errors in logs
- [ ] Port 8001 is listening: `sudo lsof -i :8001`
- [ ] Can upload M4A file and get transcription

## Common Service File Issues

### Issue 1: Missing WorkingDirectory
```ini
# ❌ Wrong - no WorkingDirectory
ExecStart=/usr/bin/uvicorn main:app

# ✅ Correct - has WorkingDirectory
WorkingDirectory=/root/sazjoo/aiapprecorder
ExecStart=/usr/bin/uvicorn main:app
```

### Issue 2: Wrong Host Binding
```ini
# ❌ Wrong - only accessible locally
ExecStart=uvicorn main:app --host 127.0.0.1 --port 8001

# ✅ Correct - accessible from network
ExecStart=uvicorn main:app --host 0.0.0.0 --port 8001
```

### Issue 3: Wrong Python Path
```ini
# ❌ Wrong - might use wrong Python
ExecStart=uvicorn main:app

# ✅ Correct - explicit Python path
ExecStart=/root/sazjoo/aiapprecorder/venv/bin/uvicorn main:app
```

### Issue 4: Missing Environment PATH
```ini
# ❌ Wrong - venv not in PATH
ExecStart=/root/sazjoo/aiapprecorder/venv/bin/uvicorn main:app

# ✅ Correct - PATH includes venv
Environment="PATH=/root/sazjoo/aiapprecorder/venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/root/sazjoo/aiapprecorder/venv/bin/uvicorn main:app
```

## Summary

The 404 error is usually caused by:
1. **Service not running** - Check status and logs
2. **Wrong directory** - Service using different code than manual run
3. **Wrong port/host** - Service not binding correctly
4. **Python environment** - Service using wrong Python/venv

Use the automated script to fix all of these automatically!

