#!/bin/bash
# Script to find both FastAPI services and their logs

echo "=========================================="
echo "Finding Both FastAPI Services (8000 & 8001)"
echo "=========================================="
echo ""

echo "1. What's Running on Port 8000:"
echo "-----------------------------------"
if command -v lsof &> /dev/null; then
    sudo lsof -i :8000 2>/dev/null || echo "Nothing on port 8000"
else
    sudo netstat -tlnp | grep :8000 || echo "Nothing on port 8000"
fi
echo ""

echo "2. What's Running on Port 8001:"
echo "-----------------------------------"
if command -v lsof &> /dev/null; then
    sudo lsof -i :8001 2>/dev/null || echo "Nothing on port 8001"
else
    sudo netstat -tlnp | grep :8001 || echo "Nothing on port 8001"
fi
echo ""

echo "3. Process Details for Both Ports:"
echo "-----------------------------------"
PID_8000=$(sudo lsof -t -i :8000 2>/dev/null)
PID_8001=$(sudo lsof -t -i :8001 2>/dev/null)

if [ ! -z "$PID_8000" ]; then
    echo "Port 8000 PID: $PID_8000"
    ps aux | grep "^[^ ]* *$PID_8000 " | grep -v grep
    echo ""
fi

if [ ! -z "$PID_8001" ]; then
    echo "Port 8001 PID: $PID_8001"
    ps aux | grep "^[^ ]* *$PID_8001 " | grep -v grep
    echo ""
fi
echo ""

echo "4. All Uvicorn/FastAPI Processes:"
echo "-----------------------------------"
ps aux | grep -E "uvicorn|fastapi|gunicorn" | grep -v grep
echo ""

echo "5. Systemd Services Related to Backend:"
echo "-----------------------------------"
sudo systemctl list-units --type=service --all --no-legend | awk '{print $1}' | grep -iE "sazjoo|api|backend|fastapi|recorder|transcribe" | while read service; do
    echo "Service: $service"
    sudo systemctl status "$service" --no-pager | head -8
    echo ""
done
echo ""

echo "6. Service File Contents (sazjoo.service):"
echo "-----------------------------------"
if systemctl list-unit-files | grep -q sazjoo.service; then
    SERVICE_FILE=$(systemctl show sazjoo.service -p FragmentPath 2>/dev/null | cut -d'=' -f2)
    if [ ! -z "$SERVICE_FILE" ] && [ -f "$SERVICE_FILE" ]; then
        echo "Service file: $SERVICE_FILE"
        cat "$SERVICE_FILE"
    else
        echo "Could not find service file"
    fi
else
    echo "sazjoo.service not found"
fi
echo ""

echo "7. Recent Logs for Port 8000 (from service logs):"
echo "-----------------------------------"
if [ ! -z "$PID_8000" ]; then
    sudo journalctl _PID=$PID_8000 -n 20 --no-pager 2>/dev/null || echo "No logs found for PID $PID_8000"
fi
echo ""

echo "8. Recent Logs for Port 8001 (from service logs):"
echo "-----------------------------------"
if [ ! -z "$PID_8001" ]; then
    sudo journalctl _PID=$PID_8001 -n 20 --no-pager 2>/dev/null || echo "No logs found for PID $PID_8001"
fi
echo ""

echo "9. Check for Screen/Tmux Sessions:"
echo "-----------------------------------"
if command -v screen &> /dev/null; then
    screen -ls 2>/dev/null || echo "No screen sessions"
fi
if command -v tmux &> /dev/null; then
    tmux ls 2>/dev/null || echo "No tmux sessions"
fi
echo ""

echo "=========================================="
echo "Commands to View Logs:"
echo "=========================================="
echo ""
if [ ! -z "$PID_8000" ]; then
    echo "View logs for port 8000:"
    echo "  sudo journalctl _PID=$PID_8000 -f"
    echo ""
fi
if [ ! -z "$PID_8001" ]; then
    echo "View logs for port 8001:"
    echo "  sudo journalctl _PID=$PID_8001 -f"
    echo ""
fi
echo "View logs for service:"
echo "  sudo journalctl -u sazjoo.service -f"
echo ""
echo "View logs for both PIDs:"
if [ ! -z "$PID_8000" ] && [ ! -z "$PID_8001" ]; then
    echo "  sudo journalctl _PID=$PID_8000 _PID=$PID_8001 -f"
fi
echo ""


