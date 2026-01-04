#!/bin/bash
# Script to fix systemd service to use the correct code

echo "=========================================="
echo "Fixing Systemd Service Configuration"
echo "=========================================="
echo ""

SERVICE_NAME="sazjoo.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"

# Check if service file exists
if [ ! -f "$SERVICE_FILE" ]; then
    echo "❌ Service file not found: $SERVICE_FILE"
    echo ""
    echo "Looking for service files..."
    find /etc/systemd/system -name "*sazjoo*" -o -name "*api*" -o -name "*backend*" 2>/dev/null
    echo ""
    echo "Please provide the correct service name:"
    read SERVICE_NAME
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
fi

if [ ! -f "$SERVICE_FILE" ]; then
    echo "❌ Service file still not found: $SERVICE_FILE"
    exit 1
fi

echo "1. Current service file: $SERVICE_FILE"
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

echo "3. Current settings:"
echo "   WorkingDirectory: $CURRENT_WORKING_DIR"
echo "   ExecStart: $CURRENT_EXEC_START"
echo "   User: $CURRENT_USER"
echo ""

# Find where you're running uvicorn manually
echo "4. Where are you running uvicorn manually?"
echo "   (The directory where you run: uvicorn main:app --reload --port 8001)"
read MANUAL_DIR

if [ ! -d "$MANUAL_DIR" ]; then
    echo "❌ Directory not found: $MANUAL_DIR"
    exit 1
fi

# Check if main.py exists there
if [ ! -f "$MANUAL_DIR/main.py" ]; then
    echo "❌ main.py not found in: $MANUAL_DIR"
    exit 1
fi

echo "   ✅ Found main.py in: $MANUAL_DIR"
echo ""

# Find Python and uvicorn
echo "5. Finding Python and uvicorn..."
MANUAL_PYTHON=$(which python3 || which python)
MANUAL_UVICORN=$(which uvicorn)

if [ -z "$MANUAL_UVICORN" ]; then
    # Try to find uvicorn in the manual directory's venv
    if [ -f "$MANUAL_DIR/venv/bin/uvicorn" ]; then
        MANUAL_UVICORN="$MANUAL_DIR/venv/bin/uvicorn"
        MANUAL_PYTHON="$MANUAL_DIR/venv/bin/python"
        echo "   Found uvicorn in venv: $MANUAL_UVICORN"
    else
        # Try pip show to find uvicorn location
        UVICORN_PATH=$(python3 -c "import uvicorn; import os; print(os.path.dirname(uvicorn.__file__))" 2>/dev/null)
        if [ ! -z "$UVICORN_PATH" ]; then
            MANUAL_UVICORN="python3 -m uvicorn"
            echo "   Using: python3 -m uvicorn"
        else
            echo "   ⚠️  Could not find uvicorn, will use: python3 -m uvicorn"
            MANUAL_UVICORN="python3 -m uvicorn"
        fi
    fi
else
    echo "   Found uvicorn: $MANUAL_UVICORN"
fi

echo "   Python: $MANUAL_PYTHON"
echo "   Uvicorn: $MANUAL_UVICORN"
echo ""

# Create backup
echo "6. Creating backup of service file..."
BACKUP_FILE="${SERVICE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
sudo cp "$SERVICE_FILE" "$BACKUP_FILE"
echo "   ✅ Backup created: $BACKUP_FILE"
echo ""

# Create new service file content
echo "7. Creating new service configuration..."

# Determine if we should use venv or system Python
USE_VENV=false
if [ -f "$MANUAL_DIR/venv/bin/uvicorn" ]; then
    USE_VENV=true
    PYTHON_CMD="$MANUAL_DIR/venv/bin/python"
    UVICORN_CMD="$MANUAL_DIR/venv/bin/uvicorn"
else
    PYTHON_CMD="$MANUAL_PYTHON"
    if [[ "$MANUAL_UVICORN" == *"python"* ]]; then
        UVICORN_CMD="$MANUAL_UVICORN"
    else
        UVICORN_CMD="$MANUAL_UVICORN"
    fi
fi

# Create new service file
NEW_SERVICE_FILE="/tmp/${SERVICE_NAME}.new"
cat > "$NEW_SERVICE_FILE" << EOF
[Unit]
Description=Persian Speech-to-Text FastAPI Service
After=network.target

[Service]
Type=simple
User=${CURRENT_USER:-root}
WorkingDirectory=$MANUAL_DIR
Environment="PATH=$MANUAL_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin"
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
read -p "8. Do you want to update the service file? [y/N]: " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "   Cancelled"
    rm "$NEW_SERVICE_FILE"
    exit 0
fi

# Install new service file
echo ""
echo "9. Installing new service file..."
sudo cp "$NEW_SERVICE_FILE" "$SERVICE_FILE"
sudo chmod 644 "$SERVICE_FILE"
rm "$NEW_SERVICE_FILE"
echo "   ✅ Service file updated"
echo ""

# Reload systemd
echo "10. Reloading systemd..."
sudo systemctl daemon-reload
echo "   ✅ Systemd reloaded"
echo ""

# Clear Python cache in the working directory
echo "11. Clearing Python cache..."
find "$MANUAL_DIR" -type d -name "__pycache__" -exec sudo rm -r {} + 2>/dev/null
find "$MANUAL_DIR" -name "*.pyc" -delete 2>/dev/null
find "$MANUAL_DIR" -name "*.pyo" -delete 2>/dev/null
echo "   ✅ Cache cleared"
echo ""

# Restart service
echo "12. Restarting service..."
sudo systemctl restart "$SERVICE_NAME"
sleep 2
echo ""

# Check status
echo "13. Service status:"
sudo systemctl status "$SERVICE_NAME" --no-pager | head -20
echo ""

# Show recent logs
echo "14. Recent logs (last 10 lines):"
sudo journalctl -u "$SERVICE_NAME" -n 10 --no-pager
echo ""

echo "=========================================="
echo "Done!"
echo "=========================================="
echo ""
echo "The service should now be using the correct code from:"
echo "  $MANUAL_DIR"
echo ""
echo "To watch logs:"
echo "  sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "To test:"
echo "  curl http://localhost:8001/health"
echo ""

