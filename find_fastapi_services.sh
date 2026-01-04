#!/bin/bash
# Script to find all FastAPI service names

echo "=========================================="
echo "FastAPI Services Finder"
echo "=========================================="
echo ""

echo "1. FastAPI/Uvicorn processes (by process name)..."
echo "-----------------------------------"
ps aux | grep -E "uvicorn|fastapi|gunicorn" | grep -v grep | awk '{print $11, $12, $13, $14, $15}' | head -20
echo ""

echo "2. Python processes that might be FastAPI..."
echo "-----------------------------------"
ps aux | grep python | grep -v grep | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}'
echo ""

echo "3. Systemd services (FastAPI-related)..."
echo "-----------------------------------"
if command -v systemctl &> /dev/null; then
    echo "All systemd services:"
    sudo systemctl list-units --type=service --all | grep -E "api|backend|fastapi|uvicorn|python" || echo "No matching services found"
    echo ""
    echo "Running systemd services:"
    sudo systemctl list-units --type=service --state=running | grep -E "api|backend|fastapi|uvicorn|python" || echo "No matching running services found"
else
    echo "systemctl not available"
fi
echo ""

echo "4. Services listening on common FastAPI ports..."
echo "-----------------------------------"
for port in 8000 8001 8080 5000 3000; do
    if command -v lsof &> /dev/null; then
        result=$(sudo lsof -i :$port 2>/dev/null)
        if [ ! -z "$result" ]; then
            echo "Port $port:"
            echo "$result"
            echo ""
        fi
    elif command -v netstat &> /dev/null; then
        result=$(sudo netstat -tlnp | grep :$port)
        if [ ! -z "$result" ]; then
            echo "Port $port:"
            echo "$result"
            echo ""
        fi
    fi
done

echo "5. PM2 processes (if using PM2)..."
echo "-----------------------------------"
if command -v pm2 &> /dev/null; then
    pm2 list
else
    echo "PM2 not installed"
fi
echo ""

echo "=========================================="
echo "Done!"
echo "=========================================="


