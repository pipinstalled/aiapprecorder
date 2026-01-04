# Fix Systemd Service to Use Correct Code

## Problem
When running `uvicorn main:app --reload --port 8001` manually, everything works fine.
But when using `sudo systemctl restart sazjoo.service`, it loads old code.

## Root Cause
The systemd service is likely:
1. Using a different working directory
2. Using a different Python environment
3. Pointing to an old version of main.py
4. Using cached Python bytecode

## Quick Fix

### Step 1: Find Your Service File
```bash
# Find the service file
sudo systemctl show sazjoo.service -p FragmentPath

# Or list all service files
ls -la /etc/systemd/system/*sazjoo*
```

### Step 2: Check Current Configuration
```bash
# View the service file
cat /etc/systemd/system/sazjoo.service

# Check what directory it's using
sudo systemctl show sazjoo.service -p WorkingDirectory

# Check what command it runs
grep "ExecStart" /etc/systemd/system/sazjoo.service
```

### Step 3: Find Where You Run Uvicorn Manually
```bash
# Where are you when you run: uvicorn main:app --reload --port 8001?
pwd

# Make sure main.py is there
ls -la main.py
```

### Step 4: Update Service File

Edit the service file:
```bash
sudo nano /etc/systemd/system/sazjoo.service
```

Update it to match where you run uvicorn manually:

```ini
[Unit]
Description=Persian Speech-to-Text FastAPI Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/sazjoo/aiapprecorder  # CHANGE THIS to your actual directory
Environment="PATH=/root/sazjoo/aiapprecorder/venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/root/sazjoo/aiapprecorder/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8001
# OR if not using venv:
# ExecStart=/usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port 8001
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**Important changes:**
- `WorkingDirectory`: Set to the directory where your `main.py` is located
- `ExecStart`: 
  - If using venv: `/path/to/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8001`
  - If using system Python: `/usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port 8001`
- `Environment PATH`: Include your venv/bin if using virtual environment

### Step 5: Reload and Restart
```bash
# Reload systemd to pick up changes
sudo systemctl daemon-reload

# Clear Python cache in the working directory
find /root/sazjoo/aiapprecorder -type d -name "__pycache__" -exec rm -r {} + 2>/dev/null
find /root/sazjoo/aiapprecorder -name "*.pyc" -delete 2>/dev/null

# Restart service
sudo systemctl restart sazjoo.service

# Check status
sudo systemctl status sazjoo.service

# Watch logs
sudo journalctl -u sazjoo.service -f
```

## Using the Automated Script

I've created a script that does all of this automatically:

```bash
# Copy script to server
scp fix_systemd_service.sh user@server:/tmp/

# SSH into server
ssh user@server

# Run the script
chmod +x /tmp/fix_systemd_service.sh
sudo /tmp/fix_systemd_service.sh
```

The script will:
1. Find your service file
2. Show current configuration
3. Ask where you run uvicorn manually
4. Create a backup
5. Update the service file
6. Clear Python cache
7. Restart the service

## Common Scenarios

### Scenario 1: Using Virtual Environment
If you're using a venv when running manually:

```ini
[Service]
WorkingDirectory=/root/sazjoo/aiapprecorder
Environment="PATH=/root/sazjoo/aiapprecorder/venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/root/sazjoo/aiapprecorder/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8001
```

### Scenario 2: Using System Python
If you're using system Python:

```ini
[Service]
WorkingDirectory=/root/sazjoo/aiapprecorder
ExecStart=/usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port 8001
```

### Scenario 3: Different User
If you run manually as a different user:

```ini
[Service]
User=your-username
WorkingDirectory=/home/your-username/project
ExecStart=/home/your-username/project/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8001
```

## Verification

After updating, verify it's working:

```bash
# Check service is running
sudo systemctl status sazjoo.service

# Check it's using the right directory
sudo systemctl show sazjoo.service -p WorkingDirectory

# Test the endpoint
curl http://localhost:8001/health

# Check logs for conversion attempts
sudo journalctl -u sazjoo.service -f
# Look for: "[CONVERT] Starting conversion" when uploading M4A
```

## Troubleshooting

### Still Loading Old Code?
1. **Check file paths match:**
   ```bash
   # What the service thinks
   sudo systemctl show sazjoo.service -p WorkingDirectory
   
   # Where you run manually
   pwd
   
   # Make sure they match!
   ```

2. **Clear all Python cache:**
   ```bash
   find /root/sazjoo/aiapprecorder -type d -name "__pycache__" -exec rm -r {} +
   find /root/sazjoo/aiapprecorder -name "*.pyc" -delete
   ```

3. **Check if multiple main.py files exist:**
   ```bash
   find /root -name "main.py" -type f 2>/dev/null
   # Make sure service is using the right one
   ```

4. **Verify the actual file being used:**
   ```bash
   # Add this to main.py temporarily to see which file is loaded
   print(f"Loading from: {__file__}")
   
   # Then check logs
   sudo journalctl -u sazjoo.service -n 50 | grep "Loading from"
   ```

### Service Won't Start?
```bash
# Check for errors
sudo journalctl -u sazjoo.service -n 50

# Common issues:
# - Python not found: Check PATH in service file
# - Module not found: Check if venv is activated or dependencies installed
# - Permission denied: Check User and file permissions
```

### Still Getting Format Error?
If you still get the format error after fixing the service:

1. **Verify conversion code exists:**
   ```bash
   grep -n "convert_audio_to_wav" /root/sazjoo/aiapprecorder/main.py
   # Should show line numbers
   ```

2. **Check logs for conversion attempts:**
   ```bash
   sudo journalctl -u sazjoo.service -f
   # Upload an M4A file and watch for "[CONVERT]" messages
   ```

3. **Test conversion manually:**
   ```bash
   cd /root/sazjoo/aiapprecorder
   python3 -c "from main import convert_audio_to_wav; print('Function exists')"
   ```

## Summary

The key is making sure the systemd service uses:
- **Same directory** where you run uvicorn manually
- **Same Python/uvicorn** (venv or system)
- **Same main.py file** (not an old copy)

Once these match, the service will use the updated code with conversion logic!

