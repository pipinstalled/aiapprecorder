# Finding Multiple FastAPI Services and Their Ports

## Quick Commands to Find FastAPI Ports

### 1. Find All Processes Listening on Ports
```bash
# Show all listening ports with process info
sudo netstat -tlnp | grep LISTEN

# Or using ss (more modern)
sudo ss -tlnp | grep LISTEN

# Or using lsof
sudo lsof -i -P -n | grep LISTEN
```

### 2. Find Python/FastAPI Processes
```bash
# Find all Python processes
ps aux | grep python

# Find uvicorn processes (common FastAPI server)
ps aux | grep uvicorn

# Find gunicorn processes (another common server)
ps aux | grep gunicorn
```

### 3. Find What's Running on Common FastAPI Ports
```bash
# Check common ports
for port in 8000 8001 8080 5000 3000 9000; do
    echo "Checking port $port:"
    sudo lsof -i :$port || sudo netstat -tlnp | grep :$port || echo "Nothing on port $port"
    echo ""
done
```

### 4. Find All FastAPI/Uvicorn Processes with Ports
```bash
# This will show the command line which usually includes the port
ps aux | grep -E "uvicorn|fastapi|gunicorn" | grep -v grep
```

## Check Service Configuration

### View Your Service File
```bash
# View the sazjoo.service file
sudo cat /etc/systemd/system/sazjoo.service

# Or if it's in a different location
sudo systemctl show sazjoo.service -p FragmentPath
```

### Check for Multiple Services
```bash
# List all services that might be FastAPI
sudo systemctl list-units --type=service --all | grep -E "sazjoo|api|fastapi|backend"
```

## Common FastAPI Port Configurations

FastAPI services typically run on:
- **8000** - Default uvicorn port
- **8001** - Alternative port
- **8080** - Common web port
- **5000** - Flask default (sometimes used)
- **3000** - Development port
- **9000** - Alternative port

## Find Ports from Process Command Line

### If Using Uvicorn
```bash
# Uvicorn command usually shows: uvicorn main:app --host 0.0.0.0 --port 8001
ps aux | grep uvicorn | grep -oP '--port \K\d+'
```

### If Using Gunicorn
```bash
# Gunicorn command usually shows: gunicorn -b 0.0.0.0:8080
ps aux | grep gunicorn | grep -oP ':\K\d+'
```

## Check Service Logs for Port Information

```bash
# Check service logs - they often show which port the service started on
sudo journalctl -u sazjoo.service -n 100 | grep -i port

# Or check all recent logs
sudo journalctl -u sazjoo.service -n 50
```

## Access the Other FastAPI Service

Once you find the port, you can access it:

### Via Browser
```
http://your-server-ip:PORT
http://your-server-ip:PORT/docs  # Swagger UI
http://your-server-ip:PORT/redoc  # ReDoc
```

### Via curl
```bash
# Health check
curl http://localhost:PORT/health

# Or with your domain
curl https://aiapp.sazjoo.com:PORT/health
```

### Via Swagger UI
```
http://your-server-ip:PORT/docs
```

## Check if Ports Are Behind a Reverse Proxy

If you're using nginx or another reverse proxy:

```bash
# Check nginx configuration
sudo cat /etc/nginx/sites-available/* | grep -A 10 -B 10 "proxy_pass"

# Or check all nginx configs
sudo nginx -T 2>/dev/null | grep -A 5 "proxy_pass"
```

## Example: Finding Both Services

```bash
# Step 1: Find all listening ports
sudo ss -tlnp | grep python

# Step 2: Check what's on each port
sudo lsof -i :8000
sudo lsof -i :8001
sudo lsof -i :8080

# Step 3: Test each port
curl http://localhost:8000/health
curl http://localhost:8001/health
curl http://localhost:8080/health
```


