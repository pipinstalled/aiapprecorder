# How to List and Manage Systemd Services

## List All Services

### 1. List All Services (Running and Stopped)
```bash
sudo systemctl list-units --type=service --all
```

### 2. List Only Running Services
```bash
sudo systemctl list-units --type=service --state=running
```

### 3. List Only Stopped Services
```bash
sudo systemctl list-units --type=service --state=stopped
```

### 4. List All Service Files (Including Disabled)
```bash
sudo systemctl list-unit-files --type=service
```

## Find Your Backend Service

### Search for Services with Specific Keywords
```bash
# Search for services containing "sazjoo"
sudo systemctl list-units --type=service --all | grep sazjoo

# Search for services containing "api", "backend", "fastapi", "python"
sudo systemctl list-units --type=service --all | grep -E "api|backend|fastapi|python|uvicorn"

# Search for services containing "recorder" or "transcribe"
sudo systemctl list-units --type=service --all | grep -E "recorder|transcribe"
```

### List All Service Names (Just the Names)
```bash
# Get just the service names
sudo systemctl list-units --type=service --all --no-legend | awk '{print $1}'

# Search within those names
sudo systemctl list-units --type=service --all --no-legend | awk '{print $1}' | grep -i sazjoo
```

## Check a Specific Service

### Check if a Service Exists
```bash
# Check if sazjoo.service exists
sudo systemctl status sazjoo.service

# Or check without sudo (will show if it exists)
systemctl list-unit-files | grep sazjoo
```

### Get Detailed Info About a Service
```bash
# Status of a specific service
sudo systemctl status sazjoo.service

# Show service file location
systemctl show sazjoo.service -p FragmentPath

# Show all properties
systemctl show sazjoo.service
```

## Common Service Management Commands

### Start a Service
```bash
sudo systemctl start <service-name>
# Example:
sudo systemctl start sazjoo.service
```

### Stop a Service
```bash
sudo systemctl stop <service-name>
```

### Restart a Service
```bash
sudo systemctl restart <service-name>
# Example:
sudo systemctl restart sazjoo.service
```

### Reload a Service (if supported)
```bash
sudo systemctl reload <service-name>
```

### Enable Service on Boot
```bash
sudo systemctl enable <service-name>
```

### Disable Service on Boot
```bash
sudo systemctl disable <service-name>
```

## Find Service Files Location

### List Service Files in /etc/systemd/system/
```bash
ls -la /etc/systemd/system/*.service
```

### List Service Files in /lib/systemd/system/ (system services)
```bash
ls -la /lib/systemd/system/*.service
```

### Search for Service Files
```bash
# Find all service files
sudo find /etc/systemd/system /lib/systemd/system -name "*.service" 2>/dev/null

# Search for specific service
sudo find /etc/systemd/system /lib/systemd/system -name "*sazjoo*" 2>/dev/null
```

## Quick Commands for Your Use Case

### 1. Find All Available Services (One Per Line)
```bash
sudo systemctl list-units --type=service --all --no-legend | awk '{print $1}'
```

### 2. Find Services Related to Your Backend
```bash
sudo systemctl list-units --type=service --all --no-legend | awk '{print $1}' | grep -iE "sazjoo|api|backend|fastapi|python|recorder"
```

### 3. Check What Services Are Running
```bash
sudo systemctl list-units --type=service --state=running --no-legend | awk '{print $1}'
```

### 4. See All Services with Their Status
```bash
sudo systemctl list-units --type=service --all
```

## Example Output

When you run `sudo systemctl list-units --type=service --all`, you'll see:

```
UNIT                      LOAD   ACTIVE   SUB     DESCRIPTION
sazjoo.service           loaded active   running Sazjoo Backend Service
nginx.service            loaded active   running A high performance web server
postgresql.service       loaded active   running PostgreSQL database server
...
```

The first column (`UNIT`) is what you use with `systemctl restart`.

## Your Specific Case

Since you have `sazjoo.service`, you can:

```bash
# Restart it
sudo systemctl restart sazjoo.service

# Check its status
sudo systemctl status sazjoo.service

# View its logs
sudo journalctl -u sazjoo.service -f

# See recent logs
sudo journalctl -u sazjoo.service -n 50
```

## Find Other Related Services

If you're not sure of the exact name, try:

```bash
# List all services and search
sudo systemctl list-units --type=service --all | grep -i saz

# Or check what's listening on port 8000 (common FastAPI port)
sudo lsof -i :8000
# This will show the process, which might help identify the service name
```


