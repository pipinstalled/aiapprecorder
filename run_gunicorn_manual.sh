#!/bin/bash
# Script to run gunicorn manually (without systemd)

echo "=========================================="
echo "Running Gunicorn Manually"
echo "=========================================="
echo ""

# Find working directory
WORKING_DIR=""
if [ -d "/root/sazjoo/aiapprecorder" ]; then
    WORKING_DIR="/root/sazjoo/aiapprecorder"
elif [ -d "/home/$(whoami)/sazjoo/aiapprecorder" ]; then
    WORKING_DIR="/home/$(whoami)/sazjoo/aiapprecorder"
else
    MAIN_PY=$(find /root /home -name "main.py" -type f 2>/dev/null | grep -iE "speech|api|recorder" | head -1)
    if [ ! -z "$MAIN_PY" ]; then
        WORKING_DIR=$(dirname "$MAIN_PY")
    else
        echo "⚠️  Could not find working directory automatically"
        echo "   Please provide the path to your main.py directory:"
        read WORKING_DIR
    fi
fi

if [ ! -d "$WORKING_DIR" ] || [ ! -f "$WORKING_DIR/main.py" ]; then
    echo "❌ Invalid directory or main.py not found: $WORKING_DIR"
    exit 1
fi

echo "1. Working directory: $WORKING_DIR"
cd "$WORKING_DIR" || exit 1
echo ""

# Find Python and gunicorn
echo "2. Finding Python and gunicorn..."
if [ -f "$WORKING_DIR/venv/bin/activate" ]; then
    VENV_DIR="$WORKING_DIR/venv"
    PYTHON_CMD="$VENV_DIR/bin/python"
    GUNICORN_CMD="$VENV_DIR/bin/gunicorn"
    echo "   ✅ Using venv: $VENV_DIR"
elif [ -f "$WORKING_DIR/.venv/bin/activate" ]; then
    VENV_DIR="$WORKING_DIR/.venv"
    PYTHON_CMD="$VENV_DIR/bin/python"
    GUNICORN_CMD="$VENV_DIR/bin/gunicorn"
    echo "   ✅ Using venv: $VENV_DIR"
else
    PYTHON_CMD=$(which python3 || which python)
    GUNICORN_CMD="$PYTHON_CMD -m gunicorn"
    echo "   ⚠️  No venv found, using system Python: $PYTHON_CMD"
fi

# Check if gunicorn exists
if [ -f "$GUNICORN_CMD" ]; then
    echo "   ✅ Found gunicorn: $GUNICORN_CMD"
elif [[ "$GUNICORN_CMD" == *"python"* ]]; then
    echo "   ✅ Will use: $GUNICORN_CMD"
else
    echo "   ❌ gunicorn not found!"
    echo "   Installing gunicorn..."
    if [ ! -z "$VENV_DIR" ]; then
        $VENV_DIR/bin/pip install gunicorn[gevent] "uvicorn[standard]"
    else
        sudo $PYTHON_CMD -m pip install gunicorn[gevent] "uvicorn[standard]"
    fi
fi
echo ""

# Check if port 8001 is already in use
echo "3. Checking if port 8001 is available..."
if command -v lsof &> /dev/null; then
    if sudo lsof -i :8001 | grep -q LISTEN; then
        echo "   ⚠️  Port 8001 is already in use!"
        echo "   Processes using port 8001:"
        sudo lsof -i :8001
        echo ""
        read -p "   Kill existing process? [y/N]: " KILL_PROCESS
        if [[ $KILL_PROCESS =~ ^[Yy]$ ]]; then
            sudo lsof -ti :8001 | xargs sudo kill -9 2>/dev/null
            sleep 2
            echo "   ✅ Killed processes on port 8001"
        else
            echo "   ❌ Cannot start - port 8001 is in use"
            exit 1
        fi
    else
        echo "   ✅ Port 8001 is available"
    fi
else
    echo "   ⚠️  Cannot check port (lsof not available), continuing..."
fi
echo ""

# Build gunicorn command
if [ -f "$GUNICORN_CMD" ]; then
    FULL_CMD="$GUNICORN_CMD -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app"
else
    FULL_CMD="$GUNICORN_CMD -w 2 -k uvicorn.workers.UvicornWorker --timeout 30 --preload --bind 0.0.0.0:8001 main:app"
fi

echo "4. Gunicorn command:"
echo "   $FULL_CMD"
echo ""

# Ask how to run
echo "5. How do you want to run gunicorn?"
echo "   1) Run in foreground (Ctrl+C to stop)"
echo "   2) Run in background (nohup)"
echo "   3) Run with screen (detachable)"
echo "   4) Run with tmux (detachable)"
read -p "   Choice [1-4]: " RUN_MODE

case $RUN_MODE in
    1)
        echo ""
        echo "=========================================="
        echo "Running in foreground..."
        echo "Press Ctrl+C to stop"
        echo "=========================================="
        echo ""
        exec $FULL_CMD
        ;;
    2)
        echo ""
        echo "6. Running in background with nohup..."
        nohup $FULL_CMD > "$WORKING_DIR/gunicorn.log" 2>&1 &
        GUNICORN_PID=$!
        echo "   ✅ Gunicorn started with PID: $GUNICORN_PID"
        echo "   Logs: $WORKING_DIR/gunicorn.log"
        echo ""
        echo "   To stop: kill $GUNICORN_PID"
        echo "   To view logs: tail -f $WORKING_DIR/gunicorn.log"
        echo ""
        sleep 2
        if ps -p $GUNICORN_PID > /dev/null; then
            echo "   ✅ Gunicorn is running"
        else
            echo "   ❌ Gunicorn failed to start, check logs:"
            tail -20 "$WORKING_DIR/gunicorn.log"
        fi
        ;;
    3)
        echo ""
        echo "6. Starting with screen..."
        if command -v screen &> /dev/null; then
            screen -dmS persian-speech-api bash -c "$FULL_CMD"
            sleep 2
            if screen -list | grep -q persian-speech-api; then
                echo "   ✅ Started in screen session: persian-speech-api"
                echo ""
                echo "   To attach: screen -r persian-speech-api"
                echo "   To detach: Ctrl+A then D"
                echo "   To list: screen -list"
            else
                echo "   ❌ Failed to start screen session"
            fi
        else
            echo "   ❌ screen is not installed"
            echo "   Install with: sudo apt-get install screen"
            exit 1
        fi
        ;;
    4)
        echo ""
        echo "6. Starting with tmux..."
        if command -v tmux &> /dev/null; then
            tmux new-session -d -s persian-speech-api "$FULL_CMD"
            sleep 2
            if tmux has-session -t persian-speech-api 2>/dev/null; then
                echo "   ✅ Started in tmux session: persian-speech-api"
                echo ""
                echo "   To attach: tmux attach -t persian-speech-api"
                echo "   To detach: Ctrl+B then D"
                echo "   To list: tmux ls"
            else
                echo "   ❌ Failed to start tmux session"
            fi
        else
            echo "   ❌ tmux is not installed"
            echo "   Install with: sudo apt-get install tmux"
            exit 1
        fi
        ;;
    *)
        echo "   Invalid choice, running in foreground..."
        exec $FULL_CMD
        ;;
esac

echo ""
echo "=========================================="
echo "Done!"
echo "=========================================="
echo ""
echo "Test the endpoint:"
echo "  curl http://localhost:8001/health"
echo ""

