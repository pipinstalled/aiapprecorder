#!/bin/bash
# Script to verify backend code is updated and fix deployment issues

echo "=========================================="
echo "Verifying Backend Deployment"
echo "=========================================="
echo ""

# Configuration
BACKEND_DIR="/root/sazjoo/aiapprecorder"
SERVICE_NAME=$(systemctl list-units --type=service --all --no-legend | awk '{print $1}' | grep -iE "sazjoo|api|backend|recorder" | head -1)

if [ -z "$SERVICE_NAME" ]; then
    echo "⚠️  Could not find service name automatically"
    echo "   Please provide the service name:"
    read SERVICE_NAME
fi

echo "1. Service name: $SERVICE_NAME"
echo "   Backend directory: $BACKEND_DIR"
echo ""

# Check if main.py exists
echo "2. Checking main.py exists..."
if [ -f "$BACKEND_DIR/main.py" ]; then
    echo "   ✅ main.py found"
    
    # Check if it has the conversion logic
    if grep -q "convert_audio_to_wav" "$BACKEND_DIR/main.py"; then
        echo "   ✅ Conversion function found in main.py"
    else
        echo "   ❌ Conversion function NOT found in main.py"
        echo "   ⚠️  Code may not be updated!"
    fi
    
    # Check if preprocess_audio calls convert_audio_to_wav
    if grep -q "should_convert = True" "$BACKEND_DIR/main.py"; then
        echo "   ✅ Conversion logic found in preprocess_audio"
    else
        echo "   ⚠️  Conversion logic may be missing"
    fi
else
    echo "   ❌ main.py NOT found at $BACKEND_DIR/main.py"
    echo "   Please check the backend directory path"
    exit 1
fi
echo ""

# Check Python cache
echo "3. Clearing Python cache..."
find "$BACKEND_DIR" -type d -name "__pycache__" -exec rm -r {} + 2>/dev/null
find "$BACKEND_DIR" -name "*.pyc" -delete 2>/dev/null
find "$BACKEND_DIR" -name "*.pyo" -delete 2>/dev/null
echo "   ✅ Python cache cleared"
echo ""

# Check FFmpeg
echo "4. Checking FFmpeg installation..."
if command -v ffmpeg &> /dev/null; then
    FFMPEG_VERSION=$(ffmpeg -version | head -1)
    echo "   ✅ FFmpeg is installed: $FFMPEG_VERSION"
else
    echo "   ❌ FFmpeg is NOT installed!"
    echo "   Install with: sudo apt-get install ffmpeg"
fi
echo ""

# Check if pydub is installed
echo "5. Checking Python dependencies..."
PYTHON_CMD=$(which python3 || which python)
if [ -z "$PYTHON_CMD" ]; then
    echo "   ❌ Python not found!"
    exit 1
fi

echo "   Python: $PYTHON_CMD"
if $PYTHON_CMD -c "import pydub" 2>/dev/null; then
    PYDUB_VERSION=$($PYTHON_CMD -c "import pydub; print(pydub.__version__)" 2>/dev/null)
    echo "   ✅ pydub is installed: $PYDUB_VERSION"
else
    echo "   ❌ pydub is NOT installed!"
    echo "   Install with: pip3 install pydub"
fi

if $PYTHON_CMD -c "import scipy" 2>/dev/null; then
    echo "   ✅ scipy is installed"
else
    echo "   ❌ scipy is NOT installed!"
    echo "   Install with: pip3 install scipy"
fi
echo ""

# Check service status
echo "6. Checking service status..."
if [ ! -z "$SERVICE_NAME" ]; then
    sudo systemctl status "$SERVICE_NAME" --no-pager | head -10
    echo ""
    
    # Show service file location
    SERVICE_FILE=$(systemctl show "$SERVICE_NAME" -p FragmentPath --value)
    if [ ! -z "$SERVICE_FILE" ]; then
        echo "   Service file: $SERVICE_FILE"
        
        # Check what command the service runs
        EXEC_START=$(grep "^ExecStart=" "$SERVICE_FILE" | cut -d'=' -f2-)
        echo "   ExecStart: $EXEC_START"
        
        # Extract working directory
        WORKING_DIR=$(grep "^WorkingDirectory=" "$SERVICE_FILE" | cut -d'=' -f2-)
        if [ ! -z "$WORKING_DIR" ]; then
            echo "   WorkingDirectory: $WORKING_DIR"
            
            # Check if main.py exists in working directory
            if [ -f "$WORKING_DIR/main.py" ]; then
                echo "   ✅ main.py found in working directory"
                
                # Check if it's the same file
                if [ "$WORKING_DIR/main.py" != "$BACKEND_DIR/main.py" ]; then
                    echo "   ⚠️  WARNING: Service uses different main.py!"
                    echo "      Service: $WORKING_DIR/main.py"
                    echo "      Expected: $BACKEND_DIR/main.py"
                fi
            else
                echo "   ⚠️  main.py NOT found in working directory"
            fi
        fi
    fi
else
    echo "   ⚠️  Could not determine service file"
fi
echo ""

# Show recent logs
echo "7. Recent service logs (last 20 lines):"
if [ ! -z "$SERVICE_NAME" ]; then
    sudo journalctl -u "$SERVICE_NAME" -n 20 --no-pager
else
    echo "   ⚠️  Could not show logs (service name unknown)"
fi
echo ""

# Ask to restart
read -p "8. Do you want to restart the service now? [y/N]: " RESTART
if [[ $RESTART =~ ^[Yy]$ ]]; then
    echo ""
    echo "   Restarting service..."
    sudo systemctl restart "$SERVICE_NAME"
    sleep 3
    sudo systemctl status "$SERVICE_NAME" --no-pager | head -15
    echo ""
    echo "   ✅ Service restarted"
    echo ""
    echo "   To watch logs in real-time:"
    echo "   sudo journalctl -u $SERVICE_NAME -f"
fi

echo ""
echo "=========================================="
echo "Verification Complete"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Make sure main.py has the conversion code"
echo "2. Verify FFmpeg is installed: ffmpeg -version"
echo "3. Test the endpoint: curl -X POST http://localhost:8001/transcribe -F 'audio=@test.m4a'"
echo "4. Check logs: sudo journalctl -u $SERVICE_NAME -f"
echo ""

