#!/bin/bash
# Script to find and check your backend service

echo "=========================================="
echo "Backend Service Finder"
echo "=========================================="
echo ""

echo "1. Checking for Python processes..."
echo "-----------------------------------"
ps aux | grep -E "python|uvicorn|gunicorn" | grep -v grep
echo ""

echo "2. Checking port 8000 (common FastAPI port)..."
echo "-----------------------------------"
if command -v lsof &> /dev/null; then
    sudo lsof -i :8000 2>/dev/null || echo "Nothing listening on port 8000"
elif command -v netstat &> /dev/null; then
    sudo netstat -tlnp | grep 8000 || echo "Nothing listening on port 8000"
elif command -v ss &> /dev/null; then
    sudo ss -tlnp | grep 8000 || echo "Nothing listening on port 8000"
else
    echo "No port checking tools available"
fi
echo ""

echo "3. Checking systemd services..."
echo "-----------------------------------"
if command -v systemctl &> /dev/null; then
    sudo systemctl list-units --type=service --state=running | grep -E "python|api|backend|fastapi" || echo "No matching systemd services found"
else
    echo "systemctl not available"
fi
echo ""

echo "4. Checking PM2 (if installed)..."
echo "-----------------------------------"
if command -v pm2 &> /dev/null; then
    pm2 list
else
    echo "PM2 not installed"
fi
echo ""

echo "5. Checking Supervisor (if installed)..."
echo "-----------------------------------"
if command -v supervisorctl &> /dev/null; then
    sudo supervisorctl status
else
    echo "Supervisor not installed"
fi
echo ""

echo "6. Checking FFmpeg installation..."
echo "-----------------------------------"
if command -v ffmpeg &> /dev/null; then
    echo "✅ FFmpeg is installed:"
    ffmpeg -version | head -1
else
    echo "❌ FFmpeg is NOT installed"
    echo "   Install with: sudo apt-get install ffmpeg"
fi
echo ""

echo "7. Checking for screen/tmux sessions..."
echo "-----------------------------------"
if command -v screen &> /dev/null; then
    screen -ls 2>/dev/null || echo "No screen sessions"
fi
if command -v tmux &> /dev/null; then
    tmux ls 2>/dev/null || echo "No tmux sessions"
fi
echo ""

echo "=========================================="
echo "Done!"
echo "=========================================="





