# Fix PyTorch ModuleNotFoundError

## Error
```
ModuleNotFoundError: No module named 'torch._C'
```

This error means PyTorch is not properly installed or there's a version mismatch.

## Solution: Reinstall PyTorch

### Step 1: Check Python Version
```bash
python3 --version
# Or
python3.10 --version
```

### Step 2: Uninstall Old PyTorch
```bash
# Uninstall torch and torchvision
pip3 uninstall torch torchvision torchaudio -y

# Or if using pip
pip uninstall torch torchvision torchaudio -y
```

### Step 3: Install PyTorch (CPU Version)
```bash
# For Python 3.10 on Linux (CPU only - recommended for server)
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Or using pip
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
```

### Step 4: Install PyTorch (GPU Version - if you have CUDA)
```bash
# Only if you have NVIDIA GPU with CUDA
# Check CUDA version first:
nvidia-smi

# For CUDA 11.8:
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# For CUDA 12.1:
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
```

### Step 5: Verify Installation
```bash
python3 -c "import torch; print(torch.__version__)"
python3 -c "import torch; print('PyTorch installed successfully')"
```

### Step 6: Reinstall Other Dependencies (if needed)
```bash
# Make sure transformers is compatible
pip3 install --upgrade transformers

# Reinstall other dependencies
pip3 install -r requirements.txt
```

### Step 7: Restart Service
```bash
sudo systemctl restart sazjoo.service
```

## Alternative: Use Virtual Environment

If you're not using a virtual environment, it's recommended:

```bash
# Create virtual environment
python3 -m venv /root/sazjoo/aiapprecorder/venv

# Activate it
source /root/sazjoo/aiapprecorder/venv/bin/activate

# Install PyTorch
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Install other dependencies
pip install transformers pydub scipy numpy fastapi uvicorn

# Update your service file to use the venv
```

## Quick Fix Script

```bash
#!/bin/bash
# Quick fix for PyTorch error

echo "Fixing PyTorch installation..."

# Uninstall
pip3 uninstall torch torchvision torchaudio -y

# Reinstall CPU version
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Verify
python3 -c "import torch; print('PyTorch version:', torch.__version__)"

# Restart service
sudo systemctl restart sazjoo.service

echo "Done! Check logs: sudo journalctl -u sazjoo.service -f"
```

## Check Current Installation

```bash
# Check if PyTorch is installed
python3 -c "import torch" 2>&1

# Check PyTorch version
python3 -c "import torch; print(torch.__version__)" 2>&1

# Check Python version
python3 --version

# List installed packages
pip3 list | grep torch
```

## Common Issues

### Issue 1: Wrong Python Version
```bash
# Make sure you're using the same Python that runs the service
# Check what Python the service uses
ps aux | grep uvicorn | grep python

# Use that specific Python version
python3.10 -m pip install torch ...
```

### Issue 2: Permission Denied
```bash
# Use sudo if needed (not recommended, better to use venv)
sudo pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Or install for current user
pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
```

### Issue 3: Still Getting Error After Reinstall
```bash
# Clear pip cache
pip3 cache purge

# Reinstall with --force-reinstall
pip3 install --force-reinstall torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
```

## Recommended: Use Requirements File

Create a `requirements.txt`:

```txt
torch==2.1.0
torchvision==0.16.0
torchaudio==2.1.0
transformers>=4.30.0
pydub>=0.25.1
scipy>=1.10.0
numpy>=1.24.0
fastapi>=0.100.0
uvicorn[standard]>=0.23.0
```

Then install:
```bash
pip3 install -r requirements.txt
```


