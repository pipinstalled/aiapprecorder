# Finding Logs for Both FastAPI Services (Port 8000 and 8001)

## Find Which Process is on Each Port

### 1. Check What's Running on Port 8000 and 8001
```bash
# Check port 8000
sudo lsof -i :8000

# Check port 8001
sudo lsof -i :8001

# Or check both at once
sudo lsof -i :8000 -i :8001
```

### 2. Find Process IDs (PIDs) for Both Ports
```bash
# Get PID for port 8000
sudo lsof -t -i :8000

# Get PID for port 8001
sudo lsof -t -i :8001

# Or both
echo "Port 8000 PID: $(sudo lsof -t -i :8000)"
echo "Port 8001 PID: $(sudo lsof -t -i :8001)"
```

### 3. Check Process Details
```bash
# See full command line for processes on both ports
ps aux | grep -E "$(sudo lsof -t -i :8000)|$(sudo lsof -t -i :8001)"
```

## View Logs for Both Services

### Option 1: If They're Different Systemd Services
```bash
# List all services to find the second one
sudo systemctl list-units --type=service --all | grep -E "sazjoo|api|fastapi|backend"

# View logs for both services
sudo journalctl -u sazjoo.service -u another-service.service -f
```

### Option 2: If They're the Same Service (Different Processes)
```bash
# View logs for the service (might show both)
sudo journalctl -u sazjoo.service -f

# Filter by port in logs
sudo journalctl -u sazjoo.service -f | grep -E "8000|8001"
```

### Option 3: View Logs by Process ID
```bash
# Get PIDs
PID_8000=$(sudo lsof -t -i :8000)
PID_8001=$(sudo lsof -t -i :8001)

# View logs for specific PID (if using journald)
sudo journalctl _PID=$PID_8000 -f
sudo journalctl _PID=$PID_8001 -f

# Or view both
sudo journalctl _PID=$PID_8000 _PID=$PID_8001 -f
```

### Option 4: If They Write to Log Files
```bash
# Check if there are log files
find /var/log -name "*8000*" -o -name "*8001*" 2>/dev/null
find /path/to/your/app -name "*.log" 2>/dev/null

# View log files
tail -f /path/to/log/file
```

## Check Service Configuration

### View Service File to See How It's Started
```bash
# View the service file
sudo cat /etc/systemd/system/sazjoo.service

# Or get the path
systemctl show sazjoo.service -p FragmentPath
```

The service file might show:
- Two separate `ExecStart` commands
- A script that starts both services
- Multiple uvicorn processes

## Check if They're Started by a Script

### Find the Startup Script
```bash
# Check service file for script
sudo cat /etc/systemd/system/sazjoo.service | grep -i execstart

# If it runs a script, check that script
# Common locations:
ls -la /opt/sazjoo/*.sh
ls -la /home/*/sazjoo/*.sh
ls -la /usr/local/bin/*sazjoo*
```

## View Logs from Process Command Line

### If Using Uvicorn Directly
```bash
# Find uvicorn processes
ps aux | grep uvicorn

# Check their output (if running in foreground)
# They might be logging to stdout/stderr which goes to journald
```

## Check if They're Running in Screen/Tmux

```bash
# Check screen sessions
screen -ls

# Check tmux sessions
tmux ls

# If found, attach to see logs
screen -r <session-name>
# or
tmux attach -t <session-name>
```

## View All Python Process Logs

```bash
# View logs for all Python processes
sudo journalctl | grep -E "python|uvicorn" | tail -50

# Or filter by the specific PIDs
PID_8000=$(sudo lsof -t -i :8000)
PID_8001=$(sudo lsof -t -i :8001)
sudo journalctl | grep -E "$PID_8000|$PID_8001" | tail -50
```

## Real-Time Monitoring of Both Ports

### Method 1: Two Terminal Windows
```bash
# Terminal 1: Follow service logs
sudo journalctl -u sazjoo.service -f

# Terminal 2: Filter by port
sudo journalctl -u sazjoo.service -f | grep "8001"
```

### Method 2: Check Process Output Directly
```bash
# If processes are managed by systemd, check their output
sudo journalctl -f | grep -E "8000|8001"
```

## Find the Second Service Name

```bash
# List all services
sudo systemctl list-units --type=service --all --no-legend | awk '{print $1}'

# Check which ones are related
sudo systemctl list-units --type=service --all | grep -E "sazjoo|api|fastapi|backend|recorder|transcribe"

# Check status of each
for service in $(sudo systemctl list-units --type=service --all --no-legend | awk '{print $1}' | grep -E "sazjoo|api"); do
    echo "=== $service ==="
    sudo systemctl status $service --no-pager | head -5
    echo ""
done
```


