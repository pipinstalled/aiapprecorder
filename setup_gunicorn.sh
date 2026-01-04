#!/bin/bash
# Script to set up gunicorn with uvicorn workers for persian-speech-api.service

echo "=========================================="
echo "Setting up Gunicorn with Uvicorn Workers"
echo "=========================================="
echo ""

SERVICE_NAME="persian-speech-api.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"

# Find working directory
echo "1. Finding working directory..."
if [ -f "$SERVICE_FILE" ]; then
    CURRENT_WORKING_DIR=$(grep "^WorkingDirectory=" "$SERVICE_FILE" | cut -d'=' -f2- | tr -d ' ')
    if [ ! -z "$CURRENT_WORKING_DIR" ] && [ -d "$CURRENT_WORKING_DIR" ]; then
        WORKING_DIR="$CURRENT_WORKING_DIR"
        echo "   ✅ Found from service file: $WORKING_DIR"
    fi
fi

if [ -z "$WORKING_DIR" ]; then
    # Search for main.py
    MAIN_PY=$(find /root /home -name "main.py" -type f 2>/dev/null | grep -iE "speech|api|recorder" | head -1)
    if [ ! -z "$MAIN_PY" ]; then
        WORKING_DIR=$(dirname "$MAIN_PY")
        echo "   ✅ Found from main.py: $WORKING_DIR"
    else
        echo "   ⚠️  Could not find working directory automatically"
        echo "   Please provide the path to your main.py directory:"
        read WORKING_DIR
    fi
fi

if [ ! -d "$WORKING_DIR" ] || [ ! -f "$WORKING_DIR/main.py" ]; then
    echo "   ❌ Invalid directory or main.py not found"
    exit 1
fi

echo "   Working directory: $WORKING_DIR"
echo ""

# Check for venv
echo "2. Checking for virtual environment..."
if [ -f "$WORKING_DIR/venv/bin/activate" ]; then
    VENV_DIR="$WORKING_DIR/venv"
    PYTHON_CMD="$VENV_DIR/bin/python"
    PIP_CMD="$VENV_DIR/bin/pip"
    echo "   ✅ Found venv: $VENV_DIR"
elif [ -f "$WORKING_DIR/.venv/bin/activate" ]; then
    VENV_DIR="$WORKING_DIR/.venv"
    PYTHON_CMD="$VENV_DIR/bin/python"
    PIP_CMD="$VENV_DIR/bin/pip"
    echo "   ✅ Found venv: $VENV_DIR"
else
    PYTHON_CMD=$(which python3 || which python)
    PIP_CMD="$PYTHON_CMD -m pip"
    echo "   ⚠️  No venv found, using system Python: $PYTHON_CMD"
fi
echo ""

# Check if gunicorn is installed
echo "3. Checking gunicorn installation..."
if $PYTHON_CMD -c "import gunicorn" 2>/dev/null; then
    GUNICORN_VERSION=$($PYTHON_CMD -c "import gunicorn; print(gunicorn.__version__)" 2>/dev/null)
    echo "   ✅ gunicorn is installed: $GUNICORN_VERSION"
else
    echo "   ❌ gunicorn is NOT installed"
    echo "   Installing gunicorn..."
    $PIP_CMD install gunicorn[gevent]
    if [ $? -eq 0 ]; then
        echo "   ✅ gunicorn installed successfully"
    else
        echo "   ❌ Failed to install gunicorn"
        exit 1
    fi
fi
echo ""

# Check if uvicorn workers are available
echo "4. Checking uvicorn workers..."
if $PYTHON_CMD -c "import uvicorn.workers" 2>/dev/null; then
    echo "   ✅ uvicorn.workers is available"
else
    echo "   ⚠️  uvicorn.workers not found, installing uvicorn[standard]..."
    $PIP_CMD install "uvicorn[standard]"
    if [ $? -eq 0 ]; then
        echo "   ✅ uvicorn[standard] installed"
    else
        echo "   ❌ Failed to install uvicorn[standard]"
        exit 1
    fi
fi
echo ""

# Test gunicorn command
echo "5. Testing gunicorn command..."
cd "$WORKING_DIR" || exit 1

# Build gunicorn command
if [ ! -z "$VENV_DIR" ]; then
    GUNICORN_CMD="$VENV_DIR/bin/gunicorn"
else
    GUNICORN_CMD="$PYTHON_CMD -m gunicorn"
fi

# Test if gunicorn works
if $GUNICORN_CMD --version 2>/dev/null; then
    echo "   ✅ gunicorn command works"
else
    echo "   ⚠️  gunicorn command test failed, but continuing..."
fi
echo ""

# Get service user
echo "6. Getting service configuration..."
if [ -f "$SERVICE_FILE" ]; then
    SERVICE_USER=$(grep "^User=" "$SERVICE_FILE" | cut -d'=' -f2- | tr -d ' ' || echo "root")
    echo "   Service user: $SERVICE_USER"
else
    SERVICE_USER="root"
    echo "   Service file not found, using default user: $SERVICE_USER"
fi
echo ""

# Create gunicorn config file (optional but recommended)
echo "7. Creating gunicorn config file..."
GUNICORN_CONFIG="$WORKING_DIR/gunicorn_config.py"
cat > "$GUNICORN_CONFIG" << 'EOF'
# Gunicorn configuration file
import multiprocessing

# Server socket
bind = "0.0.0.0:8001"
backlog = 2048

# Worker processes
workers = 2
worker_class = "uvicorn.workers.UvicornWorker"
worker_connections = 1000
timeout = 30
keepalive = 2

# Logging
accesslog = "-"  # Log to stdout
errorlog = "-"   # Log to stderr
loglevel = "info"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s'

# Process naming
proc_name = "persian-speech-api"

# Server mechanics
daemon = False
pidfile = None
umask = 0
user = None
group = None
tmp_upload_dir = None

# Preload app
preload_app = True

# Worker timeout
graceful_timeout = 30

# Restart workers after this many requests (helps with memory leaks)
max_requests = 1000
max_requests_jitter = 50
EOF

echo "   ✅ Created: $GUNICORN_CONFIG"
echo ""

# Create backup of service file
if [ -f "$SERVICE_FILE" ]; then
    echo "8. Creating backup of service file..."
    BACKUP_FILE="${SERVICE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    sudo cp "$SERVICE_FILE" "$BACKUP_FILE"
    echo "   ✅ Backup created: $BACKUP_FILE"
    echo ""
fi

# Create new service file
echo "9. Creating new service file with gunicorn..."

# Build PATH
if [ ! -z "$VENV_DIR" ]; then
    ENV_PATH="$VENV_DIR/bin:/usr/local/bin:/usr/bin:/bin"
else
    ENV_PATH="/usr/local/bin:/usr/bin:/bin"
fi

# Build ExecStart command (explicitly set port 8001)
if [ ! -z "$VENV_DIR" ]; then
    if [ -f "$VENV_DIR/bin/gunicorn" ]; then
        EXEC_START="$VENV_DIR/bin/gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app"
    else
        EXEC_START="$VENV_DIR/bin/python -m gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app"
    fi
else
    EXEC_START="$PYTHON_CMD -m gunicorn -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app"
fi

# Alternative: Use config file (config already has port 8001)
EXEC_START_CONFIG="$GUNICORN_CMD -c gunicorn_config.py main:app"

NEW_SERVICE_FILE="/tmp/${SERVICE_NAME}.new"
cat > "$NEW_SERVICE_FILE" << EOF
[Unit]
Description=Persian Speech-to-Text FastAPI Service (Gunicorn)
After=network.target

[Service]
Type=notify
User=$SERVICE_USER
WorkingDirectory=$WORKING_DIR
Environment="PATH=$ENV_PATH"
ExecStart=$EXEC_START
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
NotifyAccess=all

[Install]
WantedBy=multi-user.target
EOF

echo "   New service configuration:"
echo "----------------------------------------"
cat "$NEW_SERVICE_FILE"
echo "----------------------------------------"
echo ""

# Ask for confirmation
read -p "10. Do you want to update the service file? [y/N]: " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "   Cancelled"
    rm "$NEW_SERVICE_FILE"
    exit 0
fi

# Install new service file
echo ""
echo "11. Installing new service file..."
sudo cp "$NEW_SERVICE_FILE" "$SERVICE_FILE"
sudo chmod 644 "$SERVICE_FILE"
rm "$NEW_SERVICE_FILE"
echo "   ✅ Service file updated"
echo ""

# Reload systemd
echo "12. Reloading systemd..."
sudo systemctl daemon-reload
echo "   ✅ Systemd reloaded"
echo ""

# Clear Python cache
echo "13. Clearing Python cache..."
find "$WORKING_DIR" -type d -name "__pycache__" -exec sudo rm -r {} + 2>/dev/null
find "$WORKING_DIR" -name "*.pyc" -delete 2>/dev/null
echo "   ✅ Cache cleared"
echo ""

# Stop old service if running
echo "14. Stopping old service..."
sudo systemctl stop "$SERVICE_NAME" 2>/dev/null
sleep 2
echo ""

# Start service
echo "15. Starting service with gunicorn..."
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
    
    # Check workers
    echo ""
    echo "17. Checking gunicorn workers..."
    sleep 2
    if command -v ps &> /dev/null; then
        ps aux | grep "[g]unicorn" | head -5
    fi
else
    echo "   ❌ Service failed to start"
    echo ""
    echo "   Recent error logs:"
    sudo journalctl -u "$SERVICE_NAME" -n 20 --no-pager | grep -iE "error|fail|exception" || sudo journalctl -u "$SERVICE_NAME" -n 20 --no-pager
fi
echo ""

# Test endpoint
echo "18. Testing endpoint..."
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
echo "Gunicorn is now configured with:"
echo "  - 2 workers"
echo "  - UvicornWorker class"
echo "  - 30 second timeout"
echo "  - Preload enabled"
echo ""
echo "To watch logs:"
echo "  sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "To check workers:"
echo "  ps aux | grep gunicorn"
echo ""
echo "To restart:"
echo "  sudo systemctl restart $SERVICE_NAME"
echo ""

