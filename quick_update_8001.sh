#!/bin/bash
# Quick script to update and restart FastAPI on port 8001

echo "=========================================="
echo "Update and Restart FastAPI on Port 8001"
echo "=========================================="
echo ""

# Step 1: Find PID
echo "1. Finding process on port 8001..."
PID_8001=$(sudo lsof -t -i :8001 2>/dev/null)
if [ -z "$PID_8001" ]; then
    echo "❌ No process found on port 8001"
    exit 1
fi
echo "✅ Found PID: $PID_8001"
echo ""

# Step 2: Find code location
echo "2. Finding code location..."
CODE_DIR=$(sudo readlink -f /proc/$PID_8001/cwd 2>/dev/null)
if [ -z "$CODE_DIR" ]; then
    echo "⚠️  Could not determine code directory"
    echo "   Please specify the backend path:"
    read -p "   Backend path: " CODE_DIR
fi

if [ ! -d "$CODE_DIR" ]; then
    echo "❌ Directory does not exist: $CODE_DIR"
    exit 1
fi

echo "✅ Code directory: $CODE_DIR"
echo ""

# Step 3: Check if main.py exists
MAIN_PY="$CODE_DIR/main.py"
if [ ! -f "$MAIN_PY" ]; then
    echo "❌ main.py not found at: $MAIN_PY"
    exit 1
fi
echo "✅ Found main.py at: $MAIN_PY"
echo ""

# Step 4: Check how it's running
echo "3. Checking how service is running..."
PROCESS_CMD=$(ps aux | grep "^[^ ]* *$PID_8001 " | grep -v grep)
echo "Process command: $PROCESS_CMD"
echo ""

# Check if it's a systemd service
SERVICE_NAME=$(systemctl list-units --type=service --all --no-legend | awk '{print $1}' | grep -iE "sazjoo|api|backend" | head -1)
if [ ! -z "$SERVICE_NAME" ]; then
    echo "✅ Found systemd service: $SERVICE_NAME"
    IS_SYSTEMD=true
else
    echo "⚠️  Not a systemd service (running directly)"
    IS_SYSTEMD=false
fi
echo ""

# Step 5: Show current file info
echo "4. Current main.py info:"
echo "   Size: $(ls -lh $MAIN_PY | awk '{print $5}')"
echo "   Modified: $(ls -l $MAIN_PY | awk '{print $6, $7, $8}')"
echo ""

# Step 6: Ask for update method
echo "5. How do you want to update the code?"
echo "   1) I'll update it manually (press Enter when done)"
echo "   2) Copy from local machine (requires scp/rsync)"
echo "   3) Pull from git"
read -p "   Choice [1-3]: " UPDATE_METHOD

case $UPDATE_METHOD in
    2)
        echo ""
        read -p "   Enter local file path: " LOCAL_FILE
        if [ -f "$LOCAL_FILE" ]; then
            echo "   Copying $LOCAL_FILE to $MAIN_PY..."
            sudo cp "$LOCAL_FILE" "$MAIN_PY"
            sudo chown $(stat -c '%U:%G' "$CODE_DIR") "$MAIN_PY"
            echo "   ✅ File copied"
        else
            echo "   ❌ Local file not found: $LOCAL_FILE"
            exit 1
        fi
        ;;
    3)
        echo ""
        read -p "   Enter git branch [main/master]: " GIT_BRANCH
        GIT_BRANCH=${GIT_BRANCH:-main}
        cd "$CODE_DIR"
        if [ -d ".git" ]; then
            echo "   Pulling from git ($GIT_BRANCH)..."
            git pull origin "$GIT_BRANCH"
            echo "   ✅ Git pull completed"
        else
            echo "   ❌ Not a git repository"
            exit 1
        fi
        ;;
    1)
        echo ""
        echo "   Please update $MAIN_PY manually"
        read -p "   Press Enter when you've updated the file..."
        ;;
    *)
        echo "   Invalid choice"
        exit 1
        ;;
esac

# Step 7: Verify file was updated
echo ""
echo "6. Verifying update..."
NEW_SIZE=$(ls -lh $MAIN_PY | awk '{print $5}')
NEW_MODIFIED=$(ls -l $MAIN_PY | awk '{print $6, $7, $8}')
echo "   New size: $NEW_SIZE"
echo "   New modified: $NEW_MODIFIED"

# Check if file has logging (our new code)
if grep -q "logger.info" "$MAIN_PY" 2>/dev/null; then
    echo "   ✅ File contains new logging code"
else
    echo "   ⚠️  Warning: File doesn't seem to have the new logging code"
fi
echo ""

# Step 8: Restart service
echo "7. Restarting service..."
if [ "$IS_SYSTEMD" = true ]; then
    echo "   Restarting systemd service: $SERVICE_NAME"
    sudo systemctl restart "$SERVICE_NAME"
    sleep 2
    sudo systemctl status "$SERVICE_NAME" --no-pager | head -10
else
    echo "   Killing process $PID_8001..."
    sudo kill $PID_8001
    sleep 2
    
    # Try to restart (need to know the command)
    echo "   ⚠️  Process killed. You need to restart it manually."
    echo "   Common command:"
    echo "   cd $CODE_DIR"
    echo "   nohup uvicorn main:app --host 0.0.0.0 --port 8001 > /var/log/sazjoo_8001.log 2>&1 &"
fi
echo ""

# Step 9: Verify
echo "8. Verifying service is running..."
sleep 3
NEW_PID=$(sudo lsof -t -i :8001 2>/dev/null)
if [ ! -z "$NEW_PID" ]; then
    echo "   ✅ Service is running on port 8001 (PID: $NEW_PID)"
    
    # Test health endpoint
    if command -v curl &> /dev/null; then
        echo "   Testing health endpoint..."
        curl -s http://localhost:8001/health | head -1
    fi
else
    echo "   ❌ Service is not running on port 8001"
    echo "   Please check logs and restart manually"
fi
echo ""

echo "=========================================="
echo "Done!"
echo "=========================================="
echo ""
echo "To view logs:"
echo "  sudo journalctl _PID=$NEW_PID -f"
if [ "$IS_SYSTEMD" = true ]; then
    echo "  sudo journalctl -u $SERVICE_NAME -f"
fi


