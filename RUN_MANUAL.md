# Running Gunicorn Manually (Without Systemd)

## Quick Start

### Option 1: Run in Foreground (Simple)
```bash
cd /root/sazjoo/aiapprecorder
./venv/bin/gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app
```

Press `Ctrl+C` to stop.

### Option 2: Run in Background (nohup)
```bash
cd /root/sazjoo/aiapprecorder
nohup ./venv/bin/gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app > gunicorn.log 2>&1 &
```

- Logs: `tail -f gunicorn.log`
- Stop: `pkill -f gunicorn`

### Option 3: Run with Screen (Detachable)
```bash
# Start screen session
screen -S persian-speech-api

# Inside screen, run:
cd /root/sazjoo/aiapprecorder
./venv/bin/gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app

# Detach: Ctrl+A then D
# Reattach: screen -r persian-speech-api
```

### Option 4: Run with Tmux (Detachable)
```bash
# Start tmux session
tmux new -s persian-speech-api

# Inside tmux, run:
cd /root/sazjoo/aiapprecorder
./venv/bin/gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app

# Detach: Ctrl+B then D
# Reattach: tmux attach -t persian-speech-api
```

## Using the Automated Script

I've created a script that handles all of this:

```bash
# Copy to server
scp run_gunicorn_manual.sh user@server:/tmp/

# On server
chmod +x /tmp/run_gunicorn_manual.sh
/tmp/run_gunicorn_manual.sh
```

The script will:
1. Find your working directory
2. Find Python and gunicorn
3. Check if port 8001 is available
4. Let you choose how to run (foreground, background, screen, tmux)
5. Start gunicorn

## Managing the Process

### Check if Running
```bash
# Check processes
ps aux | grep gunicorn

# Check port
sudo lsof -i :8001
# OR
sudo netstat -tlnp | grep :8001
```

### Stop the Process
```bash
# Find PID
ps aux | grep gunicorn

# Kill by PID
kill <PID>

# Or kill all gunicorn processes
pkill -f gunicorn

# Force kill if needed
pkill -9 -f gunicorn
```

### View Logs
```bash
# If using nohup
tail -f /root/sazjoo/aiapprecorder/gunicorn.log

# If using screen
screen -r persian-speech-api

# If using tmux
tmux attach -t persian-speech-api
```

## Auto-Start on Boot (Optional)

If you want it to start automatically on boot without systemd, you can add to `/etc/rc.local`:

```bash
sudo nano /etc/rc.local
```

Add before `exit 0`:
```bash
# Start Persian Speech API
cd /root/sazjoo/aiapprecorder
nohup ./venv/bin/gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app > /root/sazjoo/aiapprecorder/gunicorn.log 2>&1 &
```

Make sure `/etc/rc.local` is executable:
```bash
sudo chmod +x /etc/rc.local
```

## Simple Start Script

Create a simple start script:

```bash
# Create start script
cat > /root/sazjoo/aiapprecorder/start.sh << 'EOF'
#!/bin/bash
cd /root/sazjoo/aiapprecorder
./venv/bin/gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app
EOF

chmod +x /root/sazjoo/aiapprecorder/start.sh
```

Then run:
```bash
/root/sazjoo/aiapprecorder/start.sh
```

## Simple Stop Script

Create a stop script:

```bash
# Create stop script
cat > /root/sazjoo/aiapprecorder/stop.sh << 'EOF'
#!/bin/bash
pkill -f "gunicorn.*main:app"
echo "Gunicorn stopped"
EOF

chmod +x /root/sazjoo/aiapprecorder/stop.sh
```

Then run:
```bash
/root/sazjoo/aiapprecorder/stop.sh
```

## Testing

After starting, test the endpoint:
```bash
curl http://localhost:8001/health
```

Should return:
```json
{"status":"healthy","model_loaded":true,...}
```

## Advantages of Manual Run

- ✅ No systemd configuration issues
- ✅ Easy to start/stop
- ✅ Direct control over the process
- ✅ Easy to see logs
- ✅ Can use screen/tmux for detachable sessions

## Disadvantages

- ❌ Won't auto-restart on crash (unless using screen/tmux)
- ❌ Won't start on boot (unless added to rc.local)
- ❌ Need to manually manage the process

## Recommended Setup

For production without systemd, I recommend:

1. **Use screen or tmux** for detachable sessions
2. **Create start/stop scripts** for easy management
3. **Add to rc.local** if you want auto-start on boot

Example with screen:
```bash
# Start
screen -dmS persian-api bash -c "cd /root/sazjoo/aiapprecorder && ./venv/bin/gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app"

# Check
screen -list

# Attach
screen -r persian-api

# Stop (from inside screen: Ctrl+C, or from outside:)
pkill -f gunicorn
```

## Summary

Running manually is simpler and avoids systemd configuration issues. Use the automated script or follow the examples above!

