# How to Check Services on Your Server

## List All Services

### Using systemctl (Ubuntu/Debian, CentOS 7+, most modern Linux)
```bash
# List all services (running and stopped)
sudo systemctl list-units --type=service

# List only running services
sudo systemctl list-units --type=service --state=running

# List all services with status
sudo systemctl list-units --type=service --all

# Show detailed status of all services
sudo systemctl status
```

### Using service command (older systems)
```bash
# List all services
sudo service --status-all

# Check specific service
sudo service <service-name> status
```

### Using ps (check running processes)
```bash
# List all running processes
ps aux

# List processes with "python" or "uvicorn" (for FastAPI)
ps aux | grep -E "python|uvicorn|gunicorn"

# List processes on specific port (e.g., 8000)
sudo lsof -i :8000
```

## Check Specific Services

### Check if your FastAPI/Backend is running
```bash
# Check for Python processes
ps aux | grep python

# Check for uvicorn (common FastAPI server)
ps aux | grep uvicorn

# Check what's listening on port 8000 (common FastAPI port)
sudo netstat -tlnp | grep 8000
# or
sudo ss -tlnp | grep 8000
# or
sudo lsof -i :8000
```

### Check if FFmpeg is installed
```bash
# Check FFmpeg version
ffmpeg -version

# Check if FFmpeg is in PATH
which ffmpeg

# Check FFmpeg location
whereis ffmpeg
```

### Check if nginx is running (if using reverse proxy)
```bash
sudo systemctl status nginx
# or
sudo service nginx status
```

## Common Service Management Commands

### Start/Stop/Restart a service
```bash
# Using systemctl
sudo systemctl start <service-name>
sudo systemctl stop <service-name>
sudo systemctl restart <service-name>
sudo systemctl status <service-name>

# Using service command
sudo service <service-name> start
sudo service <service-name> stop
sudo service <service-name> restart
sudo service <service-name> status
```

### Enable/Disable service on boot
```bash
sudo systemctl enable <service-name>   # Start on boot
sudo systemctl disable <service-name>  # Don't start on boot
```

## Find Your Backend Service

### If using PM2 (Node.js process manager, sometimes used for Python)
```bash
# List all PM2 processes
pm2 list

# Show detailed info
pm2 show <app-name>

# Check logs
pm2 logs
```

### If using supervisor
```bash
# List all supervisor processes
sudo supervisorctl status

# Check specific process
sudo supervisorctl status <process-name>
```

### If running manually or in screen/tmux
```bash
# Check screen sessions
screen -ls

# Check tmux sessions
tmux ls

# Check background jobs
jobs
```

## Check Service Logs

### Systemd service logs
```bash
# View logs for a service
sudo journalctl -u <service-name>

# View recent logs
sudo journalctl -u <service-name> -n 50

# Follow logs in real-time
sudo journalctl -u <service-name> -f
```

### PM2 logs
```bash
pm2 logs
pm2 logs <app-name>
```

### Check application logs (if logging to file)
```bash
# Common log locations
tail -f /var/log/your-app/app.log
tail -f /home/user/app/logs/app.log
```

## Quick Diagnostic Commands

### Check what's using port 8000 (common FastAPI port)
```bash
sudo lsof -i :8000
sudo netstat -tlnp | grep 8000
sudo ss -tlnp | grep 8000
```

### Check all listening ports
```bash
sudo netstat -tlnp
sudo ss -tlnp
```

### Check system resources
```bash
# CPU and memory usage
top
# or
htop

# Disk usage
df -h

# Memory usage
free -h
```

## Example: Finding Your Backend Service

```bash
# 1. Check for Python processes
ps aux | grep python

# 2. Check for processes on port 8000
sudo lsof -i :8000

# 3. Check systemd services
sudo systemctl list-units --type=service | grep -i python

# 4. Check PM2 (if installed)
pm2 list

# 5. Check supervisor (if installed)
sudo supervisorctl status
```

## Common Service Names to Look For

- `python3` or `python` - Your backend process
- `uvicorn` - FastAPI server
- `gunicorn` - Another Python WSGI server
- `nginx` - Web server/reverse proxy
- `apache2` or `httpd` - Web server
- Custom service name (check your deployment scripts)





