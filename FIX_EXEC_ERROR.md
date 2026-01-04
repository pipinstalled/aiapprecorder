# Fix EXEC Error (203) for persian-speech-api.service

## Error
```
Job for persian-speech-api.service failed because the control process exited with error code.
status=203/EXEC
```

## What This Means
`status=203/EXEC` means the `ExecStart` command in your service file **cannot be executed**. This usually means:

1. **The file path doesn't exist** - The uvicorn binary is not at that location
2. **Wrong permissions** - The file exists but isn't executable
3. **Wrong path** - The venv path is incorrect
4. **Missing dependencies** - The venv is broken or missing

## Quick Diagnosis

### Step 1: Check the ExecStart Command
```bash
grep "ExecStart" /etc/systemd/system/persian-speech-api.service
```

You'll see something like:
```
ExecStart=/root/sazjoo/aiapprecorder/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8001
```

### Step 2: Check if the File Exists
```bash
# Check if uvicorn binary exists
ls -la /root/sazjoo/aiapprecorder/venv/bin/uvicorn

# If it doesn't exist, check if venv exists
ls -la /root/sazjoo/aiapprecorder/venv/bin/
```

### Step 3: Check if Venv Exists
```bash
ls -la /root/sazjoo/aiapprecorder/venv/
```

## Solutions

### Solution 1: Use Python -m uvicorn (Recommended)
Instead of using the uvicorn binary directly, use `python -m uvicorn`:

```bash
sudo nano /etc/systemd/system/persian-speech-api.service
```

Change:
```ini
# ❌ Wrong - if uvicorn binary doesn't exist
ExecStart=/root/sazjoo/aiapprecorder/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8001

# ✅ Correct - uses Python module
ExecStart=/root/sazjoo/aiapprecorder/venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8001
```

Or if not using venv:
```ini
ExecStart=/usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port 8001
```

### Solution 2: Fix Venv Path
If the venv path is wrong, find the correct path:

```bash
# Find where you run uvicorn manually
# (The directory where: uvicorn main:app --reload --port 8001 works)

# Check if venv exists there
ls -la /path/to/your/directory/venv/bin/uvicorn

# Update service file with correct path
```

### Solution 3: Recreate Venv
If venv is broken, recreate it:

```bash
cd /root/sazjoo/aiapprecorder

# Remove old venv
rm -rf venv

# Create new venv
python3 -m venv venv

# Activate and install dependencies
source venv/bin/activate
pip install uvicorn[standard] fastapi transformers torch scipy numpy pydub

# Test
uvicorn main:app --version
```

### Solution 4: Use System Python
If venv is causing issues, use system Python:

```bash
sudo nano /etc/systemd/system/persian-speech-api.service
```

Change to:
```ini
[Service]
WorkingDirectory=/root/sazjoo/aiapprecorder
ExecStart=/usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port 8001
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
```

## Complete Service File Example

Here's a working service file that uses `python -m uvicorn`:

```ini
[Unit]
Description=Persian Speech-to-Text FastAPI Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/sazjoo/aiapprecorder
Environment="PATH=/root/sazjoo/aiapprecorder/venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/root/sazjoo/aiapprecorder/venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8001
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**Key points:**
- Uses `python -m uvicorn` instead of `uvicorn` binary
- `WorkingDirectory` points to where `main.py` is
- `Environment PATH` includes venv/bin if using venv

## Using the Automated Script

I've created a script that fixes this automatically:

```bash
# Copy to server
scp fix_exec_error.sh user@server:/tmp/

# On server
chmod +x /tmp/fix_exec_error.sh
sudo /tmp/fix_exec_error.sh
```

The script will:
1. Check if the uvicorn path exists
2. Test if uvicorn works
3. Update service file to use `python -m uvicorn`
4. Restart the service
5. Test the endpoint

## Manual Fix Steps

### Step 1: Check Current Service File
```bash
cat /etc/systemd/system/persian-speech-api.service
```

### Step 2: Find Correct Paths
```bash
# Where is your main.py?
find /root -name "main.py" -type f 2>/dev/null

# Where is your Python?
which python3

# Where is your venv? (if using one)
find /root -name "activate" -path "*/venv/bin/activate" 2>/dev/null
```

### Step 3: Update Service File
```bash
sudo nano /etc/systemd/system/persian-speech-api.service
```

Change `ExecStart` to use `python -m uvicorn`:
```ini
ExecStart=/root/sazjoo/aiapprecorder/venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8001
```

### Step 4: Reload and Restart
```bash
sudo systemctl daemon-reload
sudo systemctl restart persian-speech-api.service
sudo systemctl status persian-speech-api.service
```

### Step 5: Check Logs
```bash
# If still failing, check logs
sudo journalctl -u persian-speech-api.service -n 50
```

## Verification

After fixing, verify:

```bash
# Check service status
sudo systemctl status persian-speech-api.service
# Should show: Active: active (running)

# Test endpoint
curl http://localhost:8001/health
# Should return: {"status":"healthy",...}

# Check logs
sudo journalctl -u persian-speech-api.service -f
# Should show service starting successfully
```

## Common Issues

### Issue 1: Venv Path Wrong
**Symptom:** `ls: cannot access '/path/to/venv/bin/uvicorn': No such file or directory`

**Fix:** Use `python -m uvicorn` instead:
```ini
ExecStart=/path/to/venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8001
```

### Issue 2: No Venv
**Symptom:** Venv directory doesn't exist

**Fix:** Either create venv or use system Python:
```ini
ExecStart=/usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port 8001
```

### Issue 3: Wrong Working Directory
**Symptom:** Service can't find `main.py`

**Fix:** Update `WorkingDirectory` to where `main.py` is:
```ini
WorkingDirectory=/root/sazjoo/aiapprecorder
```

### Issue 4: Missing Dependencies
**Symptom:** Service starts but crashes with import errors

**Fix:** Install dependencies:
```bash
cd /root/sazjoo/aiapprecorder
source venv/bin/activate
pip install -r requirements.txt
# OR
pip install uvicorn fastapi transformers torch scipy numpy pydub
```

## Summary

The `203/EXEC` error means the command in `ExecStart` cannot be executed. The fix is usually:

1. **Use `python -m uvicorn`** instead of `uvicorn` binary
2. **Check paths** - Make sure WorkingDirectory and Python paths are correct
3. **Fix venv** - Recreate if broken, or use system Python

The automated script will handle all of this for you!

