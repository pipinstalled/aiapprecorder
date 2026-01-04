#!/bin/bash
# Script to fix persian-speech-api.service

echo "=========================================="
echo "Fixing persian-speech-api.service"
echo "=========================================="
echo ""

SERVICE_NAME="persian-speech-api.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"

# Check if service exists
if [ ! -f "$SERVICE_FILE" ]; then
    echo "❌ Service file not found: $SERVICE_FILE"
    echo ""
    echo "Looking for service files..."
    find /etc/systemd/system -name "*persian*" -o -name "*speech*" -o -name "*api*" 2>/dev/null
    exit 1
fi

echo "1. Service file found: $SERVICE_FILE"
echo ""

# Show current configuration
echo "2. Current service configuration:"
echo "----------------------------------------"
cat "$SERVICE_FILE"
echo "----------------------------------------"
echo ""

# Extract current values
CURRENT_WORKING_DIR=$(grep "^WorkingDirectory=" "$SERVICE_FILE" | cut -d'=' -f2- | tr -d ' ')
CURRENT_EXEC_START=$(grep "^ExecStart=" "$SERVICE_FILE" | cut -d'=' -f2-)
CURRENT_USER=$(grep "^User=" "$SERVICE_FILE" | cut -d'=' -f2- | tr -d ' ')
CURRENT_PORT=$(echo "$CURRENT_EXEC_START" | grep -oP '--port \K\d+' || echo "unknown")

echo "3. Current settings:"
echo "   WorkingDirectory: $CURRENT_WORKING_DIR"
echo "   ExecStart: $CURRENT_EXEC_START"
echo "   User: $CURRENT_USER"
echo "   Port: $CURRENT_PORT"
echo ""

# Check service status
echo "4. Current service status:"
sudo systemctl status "$SERVICE_NAME" --no-pager | head -15
echo ""

# Check if service is running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "   ✅ Service is running"
else
    echo "   ❌ Service is NOT running"
fi
echo ""

# Check what port is actually listening
echo "5. Checking what's listening on port 8001:"
if command -v lsof &> /dev/null; then
    sudo lsof -i :8001 | head -5
elif command -v netstat &> /dev/null; then
    sudo netstat -tlnp | grep :8001
elif command -v ss &> /dev/null; then
    sudo ss -tlnp | grep :8001
else
    echo "   ⚠️  Cannot check listening ports (lsof/netstat/ss not available)"
fi
echo ""

# Check recent logs
echo "6. Recent service logs (last 30 lines):"
sudo journalctl -u "$SERVICE_NAME" -n 30 --no-pager
echo ""

# Find where main.py is
echo "7. Finding main.py location..."
if [ ! -z "$CURRENT_WORKING_DIR" ] && [ -f "$CURRENT_WORKING_DIR/main.py" ]; then
    MAIN_PY="$CURRENT_WORKING_DIR/main.py"
    echo "   ✅ Found main.py in WorkingDirectory: $MAIN_PY"
else
    # Search for main.py
    MAIN_PY=$(find /root /home -name "main.py" -type f 2>/dev/null | grep -iE "speech|api|recorder" | head -1)
    if [ ! -z "$MAIN_PY" ]; then
        echo "   ✅ Found main.py: $MAIN_PY"
        MAIN_DIR=$(dirname "$MAIN_PY")
        echo "   Directory: $MAIN_DIR"
    else
        echo "   ⚠️  Could not find main.py automatically"
        echo "   Please provide the path to main.py:"
        read MAIN_PY
        MAIN_DIR=$(dirname "$MAIN_PY")
    fi
fi
echo ""

# Check if main.py has conversion code
if [ ! -z "$MAIN_PY" ] && [ -f "$MAIN_PY" ]; then
    echo "8. Checking if main.py has conversion code..."
    if grep -q "convert_audio_to_wav" "$MAIN_PY"; then
        echo "   ✅ Conversion function found"
    else
        echo "   ⚠️  Conversion function NOT found - code may be old"
    fi
    
    if grep -q "should_convert" "$MAIN_PY"; then
        echo "   ✅ Conversion logic found"
    else
        echo "   ⚠️  Conversion logic may be missing"
    fi
    echo ""
fi

# Find Python and uvicorn
echo "9. Finding Python and uvicorn..."
if [ ! -z "$MAIN_DIR" ]; then
    # Check for venv in the main directory
    if [ -f "$MAIN_DIR/venv/bin/uvicorn" ]; then
        UVICORN_CMD="$MAIN_DIR/venv/bin/uvicorn"
        PYTHON_CMD="$MAIN_DIR/venv/bin/python"
        echo "   ✅ Found venv: $MAIN_DIR/venv"
    elif [ -f "$MAIN_DIR/.venv/bin/uvicorn" ]; then
        UVICORN_CMD="$MAIN_DIR/.venv/bin/uvicorn"
        PYTHON_CMD="$MAIN_DIR/.venv/bin/python"
        echo "   ✅ Found venv: $MAIN_DIR/.venv"
    else
        # Use system Python
        PYTHON_CMD=$(which python3 || which python)
        UVICORN_CMD="python3 -m uvicorn"
        echo "   Using system Python: $PYTHON_CMD"
    fi
else
    PYTHON_CMD=$(which python3 || which python)
    UVICORN_CMD="python3 -m uvicorn"
fi

echo "   Python: $PYTHON_CMD"
echo "   Uvicorn: $UVICORN_CMD"
echo ""

# Test if uvicorn works
echo "10. Testing uvicorn..."
if [[ "$UVICORN_CMD" == *"python"* ]]; then
    $PYTHON_CMD -m uvicorn --version 2>/dev/null && echo "   ✅ uvicorn is available" || echo "   ❌ uvicorn not found"
else
    $UVICORN_CMD --version 2>/dev/null && echo "   ✅ uvicorn is available" || echo "   ❌ uvicorn not found"
fi
echo ""

# Create backup
echo "11. Creating backup..."
BACKUP_FILE="${SERVICE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
sudo cp "$SERVICE_FILE" "$BACKUP_FILE"
echo "   ✅ Backup created: $BACKUP_FILE"
echo ""

# Create new service file
echo "12. Creating new service configuration..."

# Determine user
SERVICE_USER=${CURRENT_USER:-root}

# Create new service file
NEW_SERVICE_FILE="/tmp/${SERVICE_NAME}.new"
cat > "$NEW_SERVICE_FILE" << EOF
[Unit]
Description=Persian Speech-to-Text FastAPI Service
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$MAIN_DIR
Environment="PATH=$MAIN_DIR/venv/bin:$MAIN_DIR/.venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=$UVICORN_CMD main:app --host 0.0.0.0 --port 8001
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "   New service configuration:"
echo "----------------------------------------"
cat "$NEW_SERVICE_FILE"
echo "----------------------------------------"
echo ""

# Ask for confirmation
read -p "13. Do you want to update the service file? [y/N]: " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "   Cancelled"
    rm "$NEW_SERVICE_FILE"
    exit 0
fi

# Install new service file
echo ""
echo "14. Installing new service file..."
sudo cp "$NEW_SERVICE_FILE" "$SERVICE_FILE"
sudo chmod 644 "$SERVICE_FILE"
rm "$NEW_SERVICE_FILE"
echo "   ✅ Service file updated"
echo ""

# Reload systemd
echo "15. Reloading systemd..."
sudo systemctl daemon-reload
echo "   ✅ Systemd reloaded"
echo ""

# Clear Python cache
echo "16. Clearing Python cache..."
if [ ! -z "$MAIN_DIR" ]; then
    find "$MAIN_DIR" -type d -name "__pycache__" -exec sudo rm -r {} + 2>/dev/null
    find "$MAIN_DIR" -name "*.pyc" -delete 2>/dev/null
    find "$MAIN_DIR" -name "*.pyo" -delete 2>/dev/null
    echo "   ✅ Cache cleared"
else
    echo "   ⚠️  Could not clear cache (MAIN_DIR not set)"
fi
echo ""

# Stop service first
echo "17. Stopping service..."
sudo systemctl stop "$SERVICE_NAME"
sleep 2
echo ""

# Start service
echo "18. Starting service..."
sudo systemctl start "$SERVICE_NAME"
sleep 3
echo ""

# Check status
echo "19. Service status:"
sudo systemctl status "$SERVICE_NAME" --no-pager | head -20
echo ""

# Check if it's running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "   ✅ Service is running"
else
    echo "   ❌ Service failed to start"
    echo ""
    echo "   Recent error logs:"
    sudo journalctl -u "$SERVICE_NAME" -n 20 --no-pager | grep -i error
fi
echo ""

# Test endpoint
echo "20. Testing endpoint..."
sleep 2
HEALTH_RESPONSE=$(curl -s http://localhost:8001/health 2>&1)
if [ $? -eq 0 ] && echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
    echo "   ✅ Health endpoint working!"
    echo "   Response: $HEALTH_RESPONSE"
else
    echo "   ❌ Health endpoint failed"
    echo "   Response: $HEALTH_RESPONSE"
    echo ""
    echo "   Checking if service is listening..."
    if command -v lsof &> /dev/null; then
        sudo lsof -i :8001
    fi
fi
echo ""

# Show recent logs
echo "21. Recent logs (last 15 lines):"
sudo journalctl -u "$SERVICE_NAME" -n 15 --no-pager
echo ""

echo "=========================================="
echo "Done!"
echo "=========================================="
echo ""
echo "Service should now be running with updated code."
echo ""
echo "To watch logs:"
echo "  sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "To test:"
echo "  curl http://localhost:8001/health"
echo "  curl http://localhost:8001/docs"
echo ""
echo "If you still get 404:"
echo "  1. Check if service is actually running: sudo systemctl status $SERVICE_NAME"
echo "  2. Check what port it's using: sudo lsof -i :8001"
echo "  3. Check logs for errors: sudo journalctl -u $SERVICE_NAME -n 50"
echo ""

