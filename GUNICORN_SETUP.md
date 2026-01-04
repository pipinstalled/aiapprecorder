# Setting Up Gunicorn with Uvicorn Workers

## Why Gunicorn?

Gunicorn with uvicorn workers provides:
- **Multiple worker processes** - Better performance and fault tolerance
- **Process management** - Automatic worker restarts
- **Production-ready** - Better for production deployments
- **Resource management** - Better memory and CPU usage

## Quick Setup

### Step 1: Install Gunicorn
```bash
# If using venv
source /path/to/venv/bin/activate
pip install gunicorn[gevent] "uvicorn[standard]"

# Or with system Python
pip3 install gunicorn[gevent] "uvicorn[standard]"
```

### Step 2: Test Gunicorn Manually
```bash
cd /root/sazjoo/aiapprecorder

# Test the command (explicitly set port 8001)
gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app

# Or if using venv
venv/bin/gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app
```

### Step 3: Update Service File
```bash
sudo nano /etc/systemd/system/persian-speech-api.service
```

Update to:
```ini
[Unit]
Description=Persian Speech-to-Text FastAPI Service (Gunicorn)
After=network.target

[Service]
Type=notify
User=root
WorkingDirectory=/root/sazjoo/aiapprecorder
Environment="PATH=/root/sazjoo/aiapprecorder/venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/root/sazjoo/aiapprecorder/venv/bin/gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
NotifyAccess=all

[Install]
WantedBy=multi-user.target
```

### Step 4: Reload and Restart
```bash
sudo systemctl daemon-reload
sudo systemctl restart persian-speech-api.service
sudo systemctl status persian-speech-api.service
```

## Using the Automated Script

I've created a script that does all of this automatically:

```bash
# Copy to server
scp setup_gunicorn.sh user@server:/tmp/

# On server
chmod +x /tmp/setup_gunicorn.sh
sudo /tmp/setup_gunicorn.sh
```

## Gunicorn Configuration Options

### Basic Command
```bash
gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app
```

**Options:**
- `-w 2` - Number of worker processes (adjust based on CPU cores)
- `-k uvicorn.workers.UvicornWorker` - Use uvicorn workers (async support)
- `--timeout 30` - Worker timeout in seconds
- `--preload` - Preload app before forking workers (saves memory)
- `main:app` - Your FastAPI app

### Advanced Options
```bash
gunicorn \
  -w 4 \
  -k uvicorn.workers.UvicornWorker \
  --timeout 30 \
  --keepalive 2 \
  --max-requests 1000 \
  --max-requests-jitter 50 \
  --preload \
  --bind 0.0.0.0:8001 \
  --access-logfile - \
  --error-logfile - \
  --log-level info \
  main:app
```

**Note:** The `--bind 0.0.0.0:8001` is already included above, ensuring it runs on port 8001 (not 8000).

**Additional Options:**
- `--keepalive 2` - Keep connections alive for 2 seconds
- `--max-requests 1000` - Restart worker after 1000 requests (prevents memory leaks)
- `--max-requests-jitter 50` - Random jitter to prevent all workers restarting at once
- `--bind 0.0.0.0:8001` - Bind address and port
- `--access-logfile -` - Log access to stdout
- `--error-logfile -` - Log errors to stderr
- `--log-level info` - Logging level

## Using a Config File (Recommended)

Create `gunicorn_config.py` in your project directory:

```python
# gunicorn_config.py
import multiprocessing

# Server socket
bind = "0.0.0.0:8001"
backlog = 2048

# Worker processes
workers = 2
worker_class = "uvicorn.workers.UvicornWorker"
worker_connections = 1000
timeout = 30
keepalive = 2

# Logging
accesslog = "-"  # Log to stdout
errorlog = "-"   # Log to stderr
loglevel = "info"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s'

# Process naming
proc_name = "persian-speech-api"

# Preload app
preload_app = True

# Worker timeout
graceful_timeout = 30

# Restart workers after this many requests
max_requests = 1000
max_requests_jitter = 50
```

Then use it:
```bash
gunicorn -c gunicorn_config.py main:app
```

Or in service file:
```ini
ExecStart=/path/to/venv/bin/gunicorn -c gunicorn_config.py main:app
```

## Determining Number of Workers

General rule: `(2 × CPU cores) + 1`

```bash
# Check CPU cores
nproc

# Example: 4 cores = 9 workers
# But for CPU-intensive tasks (like ML), use fewer workers
# For this speech-to-text service, 2-4 workers is usually good
```

For this service (ML model loading), **2 workers is usually optimal** because:
- Each worker loads the model into memory
- Too many workers = too much memory usage
- 2 workers provide redundancy without excessive memory

## Monitoring Gunicorn

### Check Workers
```bash
ps aux | grep gunicorn
```

You should see:
- 1 master process
- 2 worker processes (if using `-w 2`)

### Check Logs
```bash
# Service logs
sudo journalctl -u persian-speech-api.service -f

# Look for worker startup messages
# Should see: "Booting worker with pid: XXXX"
```

### Test Endpoint
```bash
curl http://localhost:8001/health
```

## Troubleshooting

### Issue 1: Gunicorn Not Found
```bash
# Install gunicorn
pip install gunicorn[gevent] "uvicorn[standard]"

# Or use python -m gunicorn
python -m gunicorn -w 2 -k uvicorn.workers.UvicornWorker main:app
```

### Issue 2: Workers Not Starting
**Check logs:**
```bash
sudo journalctl -u persian-speech-api.service -n 50
```

**Common causes:**
- Import errors in main.py
- Model loading failures
- Port already in use

### Issue 3: High Memory Usage
**Solution:** Reduce number of workers or disable preload:
```bash
# Remove --preload (but this uses more memory per worker)
gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 main:app
```

### Issue 4: Workers Dying
**Check:**
- Timeout too low (increase `--timeout`)
- Memory issues (reduce workers)
- Check logs for errors

### Issue 5: Slow Response Times
**Solutions:**
- Increase number of workers
- Increase timeout
- Check if model loading is blocking

## Comparison: Uvicorn vs Gunicorn

### Direct Uvicorn (Previous)
```bash
uvicorn main:app --host 0.0.0.0 --port 8001
```
- Single process
- Simple setup
- Good for development
- Not ideal for production

### Gunicorn + Uvicorn Workers (Current)
```bash
gunicorn -w 2 -k uvicorn.workers.UvicornWorker main:app
```
- Multiple processes
- Better fault tolerance
- Production-ready
- Better resource management

## Service File Examples

### With Venv
```ini
[Service]
WorkingDirectory=/root/sazjoo/aiapprecorder
Environment="PATH=/root/sazjoo/aiapprecorder/venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/root/sazjoo/aiapprecorder/venv/bin/gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app
```

### With System Python
```ini
[Service]
WorkingDirectory=/root/sazjoo/aiapprecorder
ExecStart=/usr/bin/python3 -m gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app
```

### With Config File
```ini
[Service]
WorkingDirectory=/root/sazjoo/aiapprecorder
ExecStart=/root/sazjoo/aiapprecorder/venv/bin/gunicorn -c gunicorn_config.py main:app
```

## Summary

Gunicorn with uvicorn workers provides:
- ✅ Multiple worker processes for better performance
- ✅ Automatic worker restarts
- ✅ Production-ready setup
- ✅ Better resource management

The setup script will handle installation and configuration automatically!

