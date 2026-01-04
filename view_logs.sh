#!/bin/bash
# Script to view service logs easily

SERVICE_NAME="sazjoo.service"

echo "=========================================="
echo "Service Logs Viewer"
echo "Service: $SERVICE_NAME"
echo "=========================================="
echo ""

# Check if service exists
if ! systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
    echo "❌ Service $SERVICE_NAME not found"
    echo ""
    echo "Available services:"
    sudo systemctl list-units --type=service --all --no-legend | awk '{print $1}' | head -10
    exit 1
fi

echo "1. Service Status:"
echo "-----------------------------------"
sudo systemctl status "$SERVICE_NAME" --no-pager | head -15
echo ""

echo "2. Recent Logs (Last 30 lines):"
echo "-----------------------------------"
sudo journalctl -u "$SERVICE_NAME" -n 30 --no-pager
echo ""

echo "3. Recent Errors (Last 20 lines):"
echo "-----------------------------------"
sudo journalctl -u "$SERVICE_NAME" -p err -n 20 --no-pager || echo "No errors found"
echo ""

echo "4. Logs from Last Hour:"
echo "-----------------------------------"
sudo journalctl -u "$SERVICE_NAME" --since "1 hour ago" --no-pager | tail -20
echo ""

echo "5. Search for Specific Terms:"
echo "-----------------------------------"
echo "Searching for: M4A, conversion, transcribe, error"
sudo journalctl -u "$SERVICE_NAME" --since "1 hour ago" --no-pager | grep -iE "m4a|conversion|convert|transcribe|error" | tail -10 || echo "No matches found"
echo ""

echo "=========================================="
echo "Useful Commands:"
echo "=========================================="
echo ""
echo "Follow logs in real-time:"
echo "  sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "View last 100 lines:"
echo "  sudo journalctl -u $SERVICE_NAME -n 100"
echo ""
echo "View logs from today:"
echo "  sudo journalctl -u $SERVICE_NAME --since today"
echo ""
echo "Search for specific term:"
echo "  sudo journalctl -u $SERVICE_NAME | grep -i 'search_term'"
echo ""
echo "View only errors:"
echo "  sudo journalctl -u $SERVICE_NAME -p err"
echo ""
echo "=========================================="
echo ""
echo "Press Enter to follow logs in real-time (Ctrl+C to exit)..."
read
sudo journalctl -u "$SERVICE_NAME" -f


