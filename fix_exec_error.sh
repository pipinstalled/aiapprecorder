#!/bin/bash
# Script to fix EXEC error (203) for persian-speech-api.service

echo "=========================================="
echo "Fixing EXEC Error (203) for persian-speech-api.service"
echo "=========================================="
echo ""

SERVICE_NAME="persian-speech-api.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"

# Check service file
if [ ! -f "$SERVICE_FILE" ]; then
    echo "❌ Service file not found: $SERVICE_FILE"
    exit 1
fi

echo "1. Current service file:"
echo "----------------------------------------"
cat "$SERVICE_FILE"
echo "----------------------------------------"
echo ""

# Extract ExecStart
CURRENT_EXEC=$(grep "^ExecStart=" "$SERVICE_FILE" | cut -d'=' -f2-)
CURRENT_WORKING_DIR=$(grep "^WorkingDirectory=" "$SERVICE_FILE" | cut -d'=' -f2- | tr -d ' ')

echo "2. Current ExecStart: $CURRENT_EXEC"
echo "   WorkingDirectory: $CURRENT_WORKING_DIR"
echo ""

# Check if venv path exists
VENV_PATH=$(echo "$CURRENT_EXEC" | awk '{print $1}')
echo "3. Checking venv path: $VENV_PATH"

if [ -f "$VENV_PATH" ]; then
    echo "   ✅ File exists"
    if [ -x "$VENV_PATH" ]; then
        echo "   ✅ File is executable"
    else
        echo "   ❌ File is NOT executable"
        echo "   Fixing permissions..."
        sudo chmod +x "$VENV_PATH"
    fi
else
    echo "   ❌ File does NOT exist"
    echo "   This is the problem!"
fi
echo ""

# Check if venv directory exists
VENV_DIR=$(dirname "$VENV_PATH")
echo "4. Checking venv directory: $VENV_DIR"

if [ -d "$VENV_DIR" ]; then
    echo "   ✅ Directory exists"
    
    # Check if it's actually a venv
    if [ -f "$VENV_DIR/bin/activate" ]; then
        echo "   ✅ This is a valid venv"
    else
        echo "   ⚠️  Directory exists but may not be a venv"
    fi
    
    # List what's in bin/
    echo "   Contents of bin/:"
    ls -la "$VENV_DIR/bin/" 2>/dev/null | head -10
else
    echo "   ❌ Directory does NOT exist"
    echo "   This is the problem!"
fi
echo ""

# Check WorkingDirectory
echo "5. Checking WorkingDirectory: $CURRENT_WORKING_DIR"

if [ -d "$CURRENT_WORKING_DIR" ]; then
    echo "   ✅ Directory exists"
    
    if [ -f "$CURRENT_WORKING_DIR/main.py" ]; then
        echo "   ✅ main.py found"
    else
        echo "   ❌ main.py NOT found"
    fi
    
    # Check for venv in working directory
    if [ -d "$CURRENT_WORKING_DIR/venv" ]; then
        echo "   ✅ venv found in working directory"
        WORKING_VENV="$CURRENT_WORKING_DIR/venv"
    elif [ -d "$CURRENT_WORKING_DIR/.venv" ]; then
        echo "   ✅ .venv found in working directory"
        WORKING_VENV="$CURRENT_WORKING_DIR/.venv"
    else
        echo "   ⚠️  No venv found in working directory"
        WORKING_VENV=""
    fi
else
    echo "   ❌ Directory does NOT exist"
    echo "   This is the problem!"
    WORKING_VENV=""
fi
echo ""

# Find Python
echo "6. Finding Python..."
SYSTEM_PYTHON=$(which python3 || which python)
echo "   System Python: $SYSTEM_PYTHON"

if [ ! -z "$WORKING_VENV" ] && [ -f "$WORKING_VENV/bin/python" ]; then
    VENV_PYTHON="$WORKING_VENV/bin/python"
    echo "   Venv Python: $VENV_PYTHON"
    USE_VENV=true
elif [ ! -z "$WORKING_VENV" ] && [ -f "$WORKING_VENV/bin/python3" ]; then
    VENV_PYTHON="$WORKING_VENV/bin/python3"
    echo "   Venv Python: $VENV_PYTHON"
    USE_VENV=true
else
    USE_VENV=false
    echo "   ⚠️  No venv Python found, will use system Python"
fi
echo ""

# Test uvicorn
echo "7. Testing uvicorn availability..."

if [ "$USE_VENV" = true ]; then
    # Test venv uvicorn
    if [ -f "$WORKING_VENV/bin/uvicorn" ]; then
        echo "   ✅ Found: $WORKING_VENV/bin/uvicorn"
        UVICORN_CMD="$WORKING_VENV/bin/uvicorn"
        TEST_CMD="$VENV_PYTHON -m uvicorn --version"
    else
        echo "   ⚠️  uvicorn binary not found, will use python -m uvicorn"
        UVICORN_CMD="$VENV_PYTHON -m uvicorn"
        TEST_CMD="$VENV_PYTHON -m uvicorn --version"
    fi
else
    # Use system Python
    UVICORN_CMD="$SYSTEM_PYTHON -m uvicorn"
    TEST_CMD="$SYSTEM_PYTHON -m uvicorn --version"
fi

echo "   Testing: $TEST_CMD"
if $TEST_CMD 2>/dev/null; then
    echo "   ✅ uvicorn is available"
else
    echo "   ❌ uvicorn is NOT available"
    echo "   Installing uvicorn..."
    if [ "$USE_VENV" = true ]; then
        $VENV_PYTHON -m pip install uvicorn[standard]
    else
        sudo $SYSTEM_PYTHON -m pip install uvicorn[standard]
    fi
fi
echo ""

# Create backup
echo "8. Creating backup..."
BACKUP_FILE="${SERVICE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
sudo cp "$SERVICE_FILE" "$BACKUP_FILE"
echo "   ✅ Backup created: $BACKUP_FILE"
echo ""

# Create new service file
echo "9. Creating new service configuration..."

# Get user from current service file
SERVICE_USER=$(grep "^User=" "$SERVICE_FILE" | cut -d'=' -f2- | tr -d ' ' || echo "root")

# Build PATH
if [ "$USE_VENV" = true ]; then
    ENV_PATH="$WORKING_VENV/bin:/usr/local/bin:/usr/bin:/bin"
else
    ENV_PATH="/usr/local/bin:/usr/bin:/bin"
fi

# Create new service file
NEW_SERVICE_FILE="/tmp/${SERVICE_NAME}.new"
cat > "$NEW_SERVICE_FILE" << EOF
[Unit]
Description=Persian Speech-to-Text FastAPI Service
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$CURRENT_WORKING_DIR
Environment="PATH=$ENV_PATH"
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

# Verify the command works
echo "10. Testing the command manually..."
cd "$CURRENT_WORKING_DIR" || exit 1
echo "   Running: $UVICORN_CMD --version"
if $UVICORN_CMD --version 2>&1 | head -1; then
    echo "   ✅ Command works!"
else
    echo "   ❌ Command failed!"
    echo "   Please check the error above"
    read -p "   Continue anyway? [y/N]: " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        rm "$NEW_SERVICE_FILE"
        exit 1
    fi
fi
echo ""

# Ask for confirmation
read -p "11. Do you want to update the service file? [y/N]: " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "   Cancelled"
    rm "$NEW_SERVICE_FILE"
    exit 0
fi

# Install new service file
echo ""
echo "12. Installing new service file..."
sudo cp "$NEW_SERVICE_FILE" "$SERVICE_FILE"
sudo chmod 644 "$SERVICE_FILE"
rm "$NEW_SERVICE_FILE"
echo "   ✅ Service file updated"
echo ""

# Reload systemd
echo "13. Reloading systemd..."
sudo systemctl daemon-reload
echo "   ✅ Systemd reloaded"
echo ""

# Clear Python cache
echo "14. Clearing Python cache..."
find "$CURRENT_WORKING_DIR" -type d -name "__pycache__" -exec sudo rm -r {} + 2>/dev/null
find "$CURRENT_WORKING_DIR" -name "*.pyc" -delete 2>/dev/null
echo "   ✅ Cache cleared"
echo ""

# Start service
echo "15. Starting service..."
sudo systemctl start "$SERVICE_NAME"
sleep 3
echo ""

# Check status
echo "16. Service status:"
sudo systemctl status "$SERVICE_NAME" --no-pager | head -20
echo ""

# Check if running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "   ✅ Service is running!"
else
    echo "   ❌ Service failed to start"
    echo ""
    echo "   Recent error logs:"
    sudo journalctl -u "$SERVICE_NAME" -n 20 --no-pager | grep -iE "error|fail|exception" || sudo journalctl -u "$SERVICE_NAME" -n 20 --no-pager
fi
echo ""

# Test endpoint
echo "17. Testing endpoint..."
sleep 2
HEALTH_RESPONSE=$(curl -s http://localhost:8001/health 2>&1)
if [ $? -eq 0 ] && echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
    echo "   ✅ Health endpoint working!"
    echo "   Response: $HEALTH_RESPONSE"
else
    echo "   ⚠️  Health endpoint test:"
    echo "   Response: $HEALTH_RESPONSE"
fi
echo ""

echo "=========================================="
echo "Done!"
echo "=========================================="
echo ""
echo "If service is still not running, check logs:"
echo "  sudo journalctl -u $SERVICE_NAME -n 50"
echo ""
echo "To watch logs in real-time:"
echo "  sudo journalctl -u $SERVICE_NAME -f"
echo ""

