#!/bin/bash
# Script to fix PyTorch installation error

echo "=========================================="
echo "Fixing PyTorch ModuleNotFoundError"
echo "=========================================="
echo ""

# Check Python version
echo "1. Checking Python version..."
PYTHON_CMD=$(which python3)
PYTHON_VERSION=$($PYTHON_CMD --version 2>&1)
echo "   Python: $PYTHON_CMD"
echo "   Version: $PYTHON_VERSION"
echo ""

# Check current PyTorch installation
echo "2. Checking current PyTorch installation..."
if $PYTHON_CMD -c "import torch" 2>/dev/null; then
    TORCH_VERSION=$($PYTHON_CMD -c "import torch; print(torch.__version__)" 2>&1)
    echo "   ⚠️  PyTorch is installed but broken (version: $TORCH_VERSION)"
else
    echo "   ❌ PyTorch is not installed or broken"
fi
echo ""

# Ask for confirmation
read -p "3. Do you want to reinstall PyTorch? [y/N]: " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "   Cancelled"
    exit 0
fi
echo ""

# Uninstall old PyTorch
echo "4. Uninstalling old PyTorch..."
pip3 uninstall torch torchvision torchaudio -y 2>/dev/null
echo "   ✅ Uninstalled"
echo ""

# Ask for CPU or GPU version
echo "5. Which PyTorch version do you want?"
echo "   1) CPU only (recommended for most servers)"
echo "   2) GPU with CUDA (if you have NVIDIA GPU)"
read -p "   Choice [1-2]: " TORCH_CHOICE

case $TORCH_CHOICE in
    1)
        echo ""
        echo "6. Installing PyTorch (CPU version)..."
        pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
        ;;
    2)
        echo ""
        echo "6. Installing PyTorch (GPU version)..."
        echo "   Checking CUDA version..."
        if command -v nvidia-smi &> /dev/null; then
            nvidia-smi | grep "CUDA Version" || echo "   Could not detect CUDA version"
        fi
        read -p "   Enter CUDA version [11.8/12.1]: " CUDA_VERSION
        CUDA_VERSION=${CUDA_VERSION:-11.8}
        if [ "$CUDA_VERSION" = "11.8" ]; then
            pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
        elif [ "$CUDA_VERSION" = "12.1" ]; then
            pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
        else
            echo "   Invalid CUDA version, using 11.8"
            pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
        fi
        ;;
    *)
        echo "   Invalid choice, installing CPU version"
        pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
        ;;
esac

echo ""

# Verify installation
echo "7. Verifying installation..."
if $PYTHON_CMD -c "import torch" 2>/dev/null; then
    TORCH_VERSION=$($PYTHON_CMD -c "import torch; print(torch.__version__)" 2>&1)
    echo "   ✅ PyTorch installed successfully!"
    echo "   Version: $TORCH_VERSION"
    
    # Test torch._C
    if $PYTHON_CMD -c "import torch._C" 2>/dev/null; then
        echo "   ✅ torch._C module is available"
    else
        echo "   ⚠️  torch._C still not available, may need to restart Python"
    fi
else
    echo "   ❌ PyTorch installation failed"
    exit 1
fi
echo ""

# Check other dependencies
echo "8. Checking other dependencies..."
for package in transformers pydub scipy numpy fastapi uvicorn; do
    if $PYTHON_CMD -c "import $package" 2>/dev/null; then
        echo "   ✅ $package is installed"
    else
        echo "   ⚠️  $package is missing"
    fi
done
echo ""

# Restart service
echo "9. Restarting service..."
SERVICE_NAME=$(systemctl list-units --type=service --all --no-legend | awk '{print $1}' | grep -iE "sazjoo|api|backend" | head -1)
if [ ! -z "$SERVICE_NAME" ]; then
    echo "   Restarting: $SERVICE_NAME"
    sudo systemctl restart "$SERVICE_NAME"
    sleep 2
    sudo systemctl status "$SERVICE_NAME" --no-pager | head -10
else
    echo "   ⚠️  Could not find service to restart"
    echo "   Please restart manually:"
    echo "   sudo systemctl restart sazjoo.service"
fi
echo ""

echo "=========================================="
echo "Done!"
echo "=========================================="
echo ""
echo "To verify, check logs:"
if [ ! -z "$SERVICE_NAME" ]; then
    echo "  sudo journalctl -u $SERVICE_NAME -f"
fi
echo ""
echo "Or test the service:"
echo "  curl http://localhost:8001/health"
echo ""


