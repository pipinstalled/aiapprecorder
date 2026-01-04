# How to View Service Logs

## View Logs for Your Service

### 1. View Recent Logs (Last 50 lines)
```bash
sudo journalctl -u sazjoo.service -n 50
```

### 2. View All Logs (Since Service Started)
```bash
sudo journalctl -u sazjoo.service
```

### 3. Follow Logs in Real-Time (Like `tail -f`)
```bash
sudo journalctl -u sazjoo.service -f
```

### 4. View Logs with Timestamps
```bash
sudo journalctl -u sazjoo.service --since "1 hour ago"
sudo journalctl -u sazjoo.service --since "2024-01-01 10:00:00"
sudo journalctl -u sazjoo.service --since today
```

### 5. View Logs Between Two Times
```bash
sudo journalctl -u sazjoo.service --since "10:00" --until "11:00"
```

### 6. View Only Error Logs
```bash
sudo journalctl -u sazjoo.service -p err
```

### 7. View Logs with More Details
```bash
# Show full output (no pager)
sudo journalctl -u sazjoo.service --no-pager

# Show with full timestamps
sudo journalctl -u sazjoo.service --no-pager -o verbose
```

## Filter Logs

### Search for Specific Terms
```bash
# Search for "error"
sudo journalctl -u sazjoo.service | grep -i error

# Search for "M4A" or "conversion"
sudo journalctl -u sazjoo.service | grep -iE "m4a|conversion|convert"

# Search for "transcribe" requests
sudo journalctl -u sazjoo.service | grep -i transcribe

# Search for port information
sudo journalctl -u sazjoo.service | grep -iE "port|8001|listening"
```

### View Logs from Multiple Services
```bash
# View logs from multiple services
sudo journalctl -u sazjoo.service -u another-service.service
```

## Check Application Log Files

If your FastAPI app writes to log files:

### Common Log File Locations
```bash
# Check if there are log files in common locations
ls -la /var/log/*.log | grep -i sazjoo
ls -la /var/log/*.log | grep -i api
ls -la /var/log/*.log | grep -i fastapi

# Check application directory
ls -la /path/to/your/app/*.log
ls -la /path/to/your/app/logs/
```

### View Log Files
```bash
# View log file
tail -f /var/log/sazjoo.log

# Or if in application directory
tail -f /path/to/your/app/logs/app.log
```

## About Your SSL Error

The error `SSL routines::wrong version number` means:
- **Port 8001 is using HTTP (not HTTPS)**
- You're trying to access it with `https://` but it's not configured for SSL

### Solution: Use HTTP Instead
```bash
# Use HTTP (not HTTPS) for port 8001
curl http://aiapp.sazjoo.com:8001/health

# Or if behind a reverse proxy, check nginx config
sudo cat /etc/nginx/sites-available/* | grep -A 10 "8001"
```

### Check if Port 8001 Has SSL
```bash
# Test if port 8001 supports HTTPS
curl -k https://localhost:8001/health

# Or check what's actually listening
sudo lsof -i :8001
```

## View Logs While Testing

### Method 1: Two Terminal Windows
```bash
# Terminal 1: Follow logs
sudo journalctl -u sazjoo.service -f

# Terminal 2: Make request
curl http://localhost:8001/health
```

### Method 2: View Logs After Request
```bash
# Make request
curl http://localhost:8001/health

# Then view recent logs
sudo journalctl -u sazjoo.service -n 20
```

## Export Logs to File

```bash
# Export recent logs to file
sudo journalctl -u sazjoo.service --since "1 hour ago" > /tmp/sazjoo_logs.txt

# Export all logs
sudo journalctl -u sazjoo.service > /tmp/sazjoo_all_logs.txt
```

## Check Service Status and Recent Activity

```bash
# Check service status
sudo systemctl status sazjoo.service

# This shows:
# - Current status
# - Recent log entries
# - Process information
```

## Real-Time Monitoring

### Watch Logs and System Resources
```bash
# Follow logs in real-time
sudo journalctl -u sazjoo.service -f

# In another terminal, monitor resources
watch -n 1 'ps aux | grep python'
```

## Common Log Patterns to Look For

### When Testing M4A Upload
```bash
# Watch for conversion logs
sudo journalctl -u sazjoo.service -f | grep -iE "convert|m4a|wav|ffmpeg"
```

### When Testing Transcription
```bash
# Watch for transcription logs
sudo journalctl -u sazjoo.service -f | grep -iE "transcribe|transcription|audio"
```

### When Debugging Errors
```bash
# Watch for errors
sudo journalctl -u sazjoo.service -f | grep -iE "error|exception|failed|traceback"
```


