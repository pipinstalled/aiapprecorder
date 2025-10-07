#!/bin/bash

# Deployment script for Persian Speech-to-Text FastAPI Backend
# Server: root@65.21.115.188

echo "🚀 Deploying Persian Speech-to-Text Backend to Server..."

# Configuration
SERVER_HOST="65.21.115.188"
SERVER_USER="root"
SERVER_PATH="/opt/persian-speech-api"
SERVICE_NAME="persian-speech-api"
DOMAIN="aiapp.sazjoo.com"
API_PORT="8001"  # Different port to avoid conflicts with existing FastAPI app

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 Deployment Configuration:${NC}"
echo "  Server: ${SERVER_USER}@${SERVER_HOST}"
echo "  Path: ${SERVER_PATH}"
echo "  Service: ${SERVICE_NAME}"
echo "  Domain: ${DOMAIN}"
echo "  Port: ${API_PORT}"
echo ""

# Check if we're in the backend directory
if [ ! -f "main.py" ]; then
    echo -e "${RED}❌ Error: main.py not found. Make sure you're in the backend directory.${NC}"
    exit 1
fi

echo -e "${YELLOW}📦 Preparing deployment files...${NC}"

# Create deployment package
tar -czf persian-speech-api.tar.gz \
    main.py \
    requirements.txt \
    Procfile \
    run.py \
    test_api.py \
    .python-version \
    runtime.txt

echo -e "${GREEN}✅ Deployment package created: persian-speech-api.tar.gz${NC}"

echo -e "${YELLOW}🚀 Uploading to server...${NC}"

# Upload to server
scp persian-speech-api.tar.gz ${SERVER_USER}@${SERVER_HOST}:/tmp/

echo -e "${YELLOW}📋 Running deployment commands on server...${NC}"

# Deploy on server
ssh ${SERVER_USER}@${SERVER_HOST} << EOF
set -e

# Configuration
SERVER_PATH="/opt/persian-speech-api"
SERVICE_NAME="persian-speech-api"
DOMAIN="${DOMAIN}"
API_PORT="${API_PORT}"

echo "🔧 Setting up server environment..."

# Update system
apt update

# Install Python 3.10 and pip
apt install -y python3.10 python3.10-venv python3.10-dev python3-pip

# Install system dependencies
apt install -y build-essential libffi-dev libssl-dev libasound2-dev portaudio19-dev

# Create application directory
mkdir -p \${SERVER_PATH}
cd \${SERVER_PATH}

# Extract deployment package
tar -xzf /tmp/persian-speech-api.tar.gz
rm /tmp/persian-speech-api.tar.gz

# Create virtual environment
python3.10 -m venv venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install dependencies
pip install -r requirements.txt

# Create systemd service file
cat > /etc/systemd/system/\${SERVICE_NAME}.service << 'EOL'
[Unit]
Description=Persian Speech-to-Text FastAPI Service
After=network.target

[Service]
Type=exec
User=root
WorkingDirectory=/opt/persian-speech-api
Environment=PATH=/opt/persian-speech-api/venv/bin
ExecStart=/opt/persian-speech-api/venv/bin/uvicorn main:app --host 0.0.0.0 --port \${API_PORT}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable \${SERVICE_NAME}
systemctl start \${SERVICE_NAME}

# Check service status
systemctl status \${SERVICE_NAME} --no-pager

echo "✅ Service deployed and started!"
echo "🌐 API should be available at: http://65.21.115.188:\${API_PORT}"
echo "📖 API docs at: http://65.21.115.188:\${API_PORT}/docs"
echo ""
echo "🔧 Next step: Add nginx configuration for \${DOMAIN}"
echo "   Add this to your nginx config:"
echo "   location / {"
echo "       proxy_pass http://127.0.0.1:\${API_PORT};"
echo "       proxy_set_header Host \\\$host;"
echo "       proxy_set_header X-Real-IP \\\$remote_addr;"
echo "       proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;"
echo "       proxy_set_header X-Forwarded-Proto \\\$scheme;"
echo "   }"

EOF

# Clean up local deployment package
rm persian-speech-api.tar.gz

echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo -e "${BLUE}📋 Next steps:${NC}"
echo "  1. Test the API: curl http://65.21.115.188:${API_PORT}/health"
echo "  2. View API docs: http://65.21.115.188:${API_PORT}/docs"
echo "  3. Check service status: ssh root@65.21.115.188 'systemctl status persian-speech-api'"
echo "  4. View logs: ssh root@65.21.115.188 'journalctl -u persian-speech-api -f'"
echo "  5. Add nginx config for ${DOMAIN} to proxy to port ${API_PORT}"
