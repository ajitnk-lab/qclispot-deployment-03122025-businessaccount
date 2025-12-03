#!/bin/bash -xe

# CORRECTED Amazon Q CLI Setup Script
# Fix: Install AWS CLI BEFORE checking IAM credentials

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/amazon-q-setup.log >&2
}

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

log "🚀 Starting CORRECTED Amazon Q CLI setup on $INSTANCE_ID"

# 1. FIRST: Install essential tools and AWS CLI
log "📦 Installing essential tools..."
apt-get update
apt-get install -y unzip curl wget jq

log "📦 Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# 2. THEN: Wait for IAM credentials (now AWS CLI is available)
log "⏳ Waiting for IAM credentials to be available..."
for i in {1..30}; do
  if aws sts get-caller-identity --region $REGION >/dev/null 2>&1; then
    log "✅ IAM credentials are available"
    break
  fi
  log "⏳ Waiting for IAM credentials... attempt $i/30"
  sleep 10
done

# 3. Associate Elastic IP
log "🌐 Associating Elastic IP..."
aws ec2 associate-address \
  --region $REGION \
  --instance-id $INSTANCE_ID \
  --allocation-id eipalloc-0b8c8b8b8b8b8b8b8  # Replace with actual allocation ID

# 4. Install VS Code Server
log "🔧 Installing VS Code Server..."
curl -fsSL https://code-server.dev/install.sh | sh

# 5. Configure and start VS Code Server
mkdir -p ~/.config/code-server
cat > ~/.config/code-server/config.yaml << 'EOF'
bind-addr: 0.0.0.0:8080
auth: none
cert: false
EOF

sudo systemctl enable code-server@ubuntu
sudo systemctl start code-server@ubuntu

log "✅ Setup completed successfully!"
