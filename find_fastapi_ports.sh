#!/bin/bash
# Script to find all FastAPI services and their ports

echo "=========================================="
echo "FastAPI Services Port Finder"
echo "=========================================="
echo ""

echo "1. All Listening Ports (Python processes):"
echo "-----------------------------------"
if command -v ss &> /dev/null; then
    sudo ss -tlnp | grep python || echo "No Python processes found listening"
elif command -v netstat &> /dev/null; then
    sudo netstat -tlnp | grep python || echo "No Python processes found listening"
else
    echo "Neither ss nor netstat available"
fi
echo ""

echo "2. Uvicorn/Gunicorn Processes:"
echo "-----------------------------------"
ps aux | grep -E "uvicorn|gunicorn|fastapi" | grep -v grep || echo "No uvicorn/gunicorn processes found"
echo ""

echo "3. Checking Common FastAPI Ports:"
echo "-----------------------------------"
for port in 8000 8001 8080 5000 3000 9000; do
    if command -v lsof &> /dev/null; then
        result=$(sudo lsof -i :$port 2>/dev/null)
        if [ ! -z "$result" ]; then
            echo "Port $port:"
            echo "$result" | head -3
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
echo ""

echo "4. Extracting Ports from Process Commands:"
echo "-----------------------------------"
echo "Uvicorn ports:"
ps aux | grep uvicorn | grep -v grep | grep -oP '--port\s+\K\d+' | while read port; do
    echo "  - Port $port (uvicorn)"
done

echo "Gunicorn ports:"
ps aux | grep gunicorn | grep -v grep | grep -oP ':\K\d+' | while read port; do
    echo "  - Port $port (gunicorn)"
done
echo ""

echo "5. Testing Common Ports (Health Check):"
echo "-----------------------------------"
for port in 8000 8001 8080 5000 3000 9000; do
    if command -v curl &> /dev/null; then
        response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 http://localhost:$port/health 2>/dev/null)
        if [ "$response" != "000" ] && [ "$response" != "" ]; then
            echo "✅ Port $port: Responding (HTTP $response)"
            echo "   Try: curl http://localhost:$port/health"
            echo "   Or: http://your-server:$port/docs"
        fi
    fi
done
echo ""

echo "6. Service Configuration (sazjoo.service):"
echo "-----------------------------------"
if systemctl list-unit-files | grep -q sazjoo.service; then
    echo "Service file location:"
    systemctl show sazjoo.service -p FragmentPath 2>/dev/null || echo "Could not find service file"
    echo ""
    echo "Recent service logs (looking for port info):"
    sudo journalctl -u sazjoo.service -n 20 --no-pager | grep -iE "port|uvicorn|listening|started" || echo "No port info in recent logs"
else
    echo "sazjoo.service not found"
fi
echo ""

echo "=========================================="
echo "To access a FastAPI service:"
echo "  http://your-server:PORT/docs"
echo "  http://your-server:PORT/health"
echo "=========================================="


