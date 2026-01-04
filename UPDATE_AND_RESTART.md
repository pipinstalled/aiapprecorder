# How to Update and Restart FastAPI Service on Port 8001

## Step 1: Find the Service/Process on Port 8001

### Get Process ID
```bash
PID_8001=$(sudo lsof -t -i :8001)
echo "Port 8001 PID: $PID_8001"
```

### Check How It's Running
```bash
# See the full command
ps aux | grep $PID_8001

# Check if it's a systemd service
sudo systemctl list-units --type=service --all | grep -E "sazjoo|api|backend"
```

## Step 2: Find the Code Location

### Check Process Working Directory
```bash
# Get the working directory of the process
sudo ls -la /proc/$PID_8001/cwd

# Or check the command line
ps aux | grep $PID_8001 | grep -oP '(?<=/)[^ ]*main\.py'
```

### Common Locations
```bash
# Check common FastAPI locations
ls -la /opt/sazjoo/
ls -la /home/*/sazjoo/
ls -la /var/www/sazjoo/
ls -la /usr/local/sazjoo/
```

## Step 3: Update the Code

### Option A: If Using Git
```bash
cd /path/to/your/backend
git pull origin main  # or master, or your branch name
```

### Option B: If Manual Upload
```bash
# Copy the updated main.py to server
# From your local machine:
scp /Users/vafa/Documents/Backend/Recorder/Backend/main.py user@server:/path/to/backend/main.py

# Or use rsync
rsync -avz /Users/vafa/Documents/Backend/Recorder/Backend/main.py user@server:/path/to/backend/
```

### Option C: Edit Directly on Server
```bash
# SSH to server and edit
nano /path/to/backend/main.py
# Or
vim /path/to/backend/main.py
```

## Step 4: Restart the Service

### If It's a Systemd Service
```bash
# Find the service name
sudo systemctl list-units --type=service --all | grep -E "sazjoo|api|backend"

# Restart the service
sudo systemctl restart sazjoo.service
# Or if it has a different name:
sudo systemctl restart <service-name>
```

### If It's Running Directly (Not systemd)
```bash
# Kill the process
sudo kill $PID_8001

# Or gracefully
sudo kill -HUP $PID_8001

# Then restart it (check how it was started)
cd /path/to/backend
# Usually something like:
uvicorn main:app --host 0.0.0.0 --port 8001 &
# Or
nohup uvicorn main:app --host 0.0.0.0 --port 8001 > /var/log/sazjoo.log 2>&1 &
```

### If It's in a Screen/Tmux Session
```bash
# List sessions
screen -ls
# or
tmux ls

# Attach to session
screen -r <session-name>
# or
tmux attach -t <session-name>

# Inside the session, restart:
# Ctrl+C to stop
# Then restart:
uvicorn main:app --host 0.0.0.0 --port 8001
```

## Step 5: Verify the Update

### Check if New Code is Running
```bash
# Check the logs for the new logging messages
sudo journalctl _PID=$(sudo lsof -t -i :8001) -f

# Or if systemd service
sudo journalctl -u sazjoo.service -f
```

### Test the Endpoint
```bash
# Test health endpoint
curl http://localhost:8001/health

# Try uploading an M4A file
curl -X POST http://localhost:8001/transcribe \
  -F "audio=@test.m4a" \
  -H "Content-Type: multipart/form-data"
```

## Quick Update Script

```bash
#!/bin/bash
# Quick update and restart script

# 1. Find PID
PID_8001=$(sudo lsof -t -i :8001)
echo "Port 8001 PID: $PID_8001"

# 2. Find code location (adjust path)
BACKEND_PATH="/path/to/your/backend"  # UPDATE THIS
cd $BACKEND_PATH

# 3. Update code (choose one method)
# git pull
# OR copy new file
# OR edit directly

# 4. Restart
# If systemd:
sudo systemctl restart sazjoo.service

# If direct process:
sudo kill $PID_8001
sleep 2
nohup uvicorn main:app --host 0.0.0.0 --port 8001 > /var/log/sazjoo_8001.log 2>&1 &

# 5. Verify
sleep 3
curl http://localhost:8001/health
```

## Common Issues

### Issue 1: Can't Find the Code Location
```bash
# Check where the process was started from
sudo ls -la /proc/$(sudo lsof -t -i :8001)/cwd
```

### Issue 2: Service Won't Restart
```bash
# Check service status
sudo systemctl status sazjoo.service

# Check for errors
sudo journalctl -u sazjoo.service -n 50

# Try reloading systemd
sudo systemctl daemon-reload
sudo systemctl restart sazjoo.service
```

### Issue 3: Port Still Shows Old Code
```bash
# Make sure you restarted the right service
# Check if there are multiple instances
ps aux | grep uvicorn

# Kill all and restart
sudo pkill -f "uvicorn.*8001"
# Then restart properly
```

## Recommended Steps

1. **Find the code location:**
   ```bash
   sudo ls -la /proc/$(sudo lsof -t -i :8001)/cwd
   ```

2. **Update main.py** (copy from your local machine or edit on server)

3. **Restart the service:**
   ```bash
   # If systemd:
   sudo systemctl restart sazjoo.service
   
   # If not systemd, find how it's started and restart it
   ```

4. **Verify:**
   ```bash
   # Check logs for new logging messages
   sudo journalctl _PID=$(sudo lsof -t -i :8001) -f
   ```

5. **Test:**
   ```bash
   curl http://localhost:8001/health
   ```


