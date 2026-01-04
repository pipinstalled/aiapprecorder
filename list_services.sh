#!/bin/bash
# Script to list all systemd services

echo "=========================================="
echo "Systemd Services List"
echo "=========================================="
echo ""

echo "1. All Services (Running and Stopped):"
echo "-----------------------------------"
sudo systemctl list-units --type=service --all --no-legend | awk '{print $1}' | head -20
echo "... (showing first 20, use full command to see all)"
echo ""

echo "2. Only Running Services:"
echo "-----------------------------------"
sudo systemctl list-units --type=service --state=running --no-legend | awk '{print $1}'
echo ""

echo "3. Services Related to Backend/API:"
echo "-----------------------------------"
sudo systemctl list-units --type=service --all --no-legend | awk '{print $1}' | grep -iE "sazjoo|api|backend|fastapi|python|uvicorn|recorder|transcribe" || echo "No matching services found"
echo ""

echo "4. Service Files in /etc/systemd/system/:"
echo "-----------------------------------"
ls -1 /etc/systemd/system/*.service 2>/dev/null | xargs -n1 basename || echo "No service files found"
echo ""

echo "5. Check if sazjoo.service exists:"
echo "-----------------------------------"
if systemctl list-unit-files | grep -q sazjoo.service; then
    echo "✅ sazjoo.service exists"
    sudo systemctl status sazjoo.service --no-pager | head -10
else
    echo "❌ sazjoo.service not found"
fi
echo ""

echo "=========================================="
echo "To restart a service, use:"
echo "  sudo systemctl restart <service-name>"
echo "=========================================="


