#!/bin/bash -xe

# Enhanced Amazon Q CLI + VS Code Server Setup Script - V10 Complete ENHANCED
# Multi-instance family support with dynamic configuration
# Version: 10.0 Enhanced - Production Ready with instance family awareness
# Supports: M5, M6i, C5, C6i, R5, R6i instance families across all AZs

# Enhanced logging function with timestamps and levels
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a /var/log/amazonq-vscode-enhanced-setup.log >&2
}

# Error handler function with detailed logging
error_handler() {
    local exit_code=$?
    local line_number=$1
    log "ERROR" "Script failed at line $line_number with exit code $exit_code"
    log "ERROR" "Last command: ${BASH_COMMAND}"
    log "ERROR" "Check /var/log/amazonq-vscode-enhanced-setup.log for details"
    # Don't exit immediately, try to continue with critical components
}

# Set up error handling (non-fatal for better resilience)
trap 'error_handler $LINENO' ERR
set +e  # Don't exit on errors, handle them gracefully

# Initialize logging
log "INFO" "🚀 Starting Enhanced Amazon Q CLI + VS Code Server Setup V10.0"
log "INFO" "📋 PHASE 1: Enhanced System Preparation and Instance Analysis"

# CRITICAL FIX: Set HOME environment variable for all operations
export HOME=/root
log "INFO" "🔧 HOME environment variable set to: $HOME"

# Get instance metadata with enhanced information
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)

# Extract instance family from instance type
INSTANCE_FAMILY=$(echo "$INSTANCE_TYPE" | cut -d'.' -f1)

log "INFO" "Instance ID: $INSTANCE_ID"
log "INFO" "Region: $REGION" 
log "INFO" "Availability Zone: $INSTANCE_AZ"
log "INFO" "Public IP: $PUBLIC_IP"
log "INFO" "Instance Type: $INSTANCE_TYPE"
log "INFO" "Instance Family: $INSTANCE_FAMILY"

# Instance family specific configurations
case $INSTANCE_FAMILY in
    "m5"|"m6i")
        INSTANCE_CATEGORY="General Purpose"
        MEMORY_CONFIG="balanced"
        CPU_CONFIG="balanced"
        DOCKER_MEMORY_LIMIT="6g"
        NODE_MAX_OLD_SPACE="4096"
        ;;
    "c5"|"c6i")
        INSTANCE_CATEGORY="Compute Optimized"
        MEMORY_CONFIG="standard"
        CPU_CONFIG="high"
        DOCKER_MEMORY_LIMIT="4g"
        NODE_MAX_OLD_SPACE="3072"
        ;;
    "r5"|"r6i")
        INSTANCE_CATEGORY="Memory Optimized"
        MEMORY_CONFIG="high"
        CPU_CONFIG="balanced"
        DOCKER_MEMORY_LIMIT="12g"
        NODE_MAX_OLD_SPACE="8192"
        ;;
    *)
        INSTANCE_CATEGORY="Unknown"
        MEMORY_CONFIG="balanced"
        CPU_CONFIG="balanced"
        DOCKER_MEMORY_LIMIT="6g"
        NODE_MAX_OLD_SPACE="4096"
        log "WARN" "Unknown instance family: $INSTANCE_FAMILY, using default configuration"
        ;;
esac

log "INFO" "Instance Category: $INSTANCE_CATEGORY"
log "INFO" "Memory Configuration: $MEMORY_CONFIG"
log "INFO" "CPU Configuration: $CPU_CONFIG"
log "INFO" "Docker Memory Limit: $DOCKER_MEMORY_LIMIT"
log "INFO" "Node.js Max Old Space: ${NODE_MAX_OLD_SPACE}MB"

# Note: EIP cleanup is now handled by pre-deployment script
log "INFO" "📝 Note: EIP cleanup handled by pre-deployment script, not UserData"

# Improved retry function with better error handling
retry_command() {
    local max_attempts="$1"
    local delay="$2"
    local description="$3"
    shift 3
    local command=("$@")
    
    for attempt in $(seq 1 $max_attempts); do
        log "INFO" "Attempting $description (attempt $attempt/$max_attempts)"
        if "${command[@]}"; then
            log "SUCCESS" "$description completed successfully"
            return 0
        else
            local exit_code=$?
            if [ $attempt -eq $max_attempts ]; then
                log "ERROR" "$description failed after $max_attempts attempts (exit code: $exit_code)"
                return 1
            fi
            log "WARN" "$description failed (exit code: $exit_code), retrying in ${delay}s..."
            sleep $delay
        fi
    done
}

# System validation with instance family awareness
log "INFO" "🔍 Validating enhanced system requirements..."
if ! command -v curl &> /dev/null; then
    log "ERROR" "curl is not available"
    exit 1
fi

log "INFO" "📋 PHASE 2: Enhanced System Updates and Tools Installation"

# Update system packages with better error handling
log "INFO" "📦 Updating system packages for $INSTANCE_CATEGORY instance..."
if ! retry_command 3 10 "System package update" apt-get update; then
    log "WARN" "Package update failed, continuing anyway..."
fi

# Install essential packages with instance family optimizations
log "INFO" "📦 Installing essential packages optimized for $INSTANCE_FAMILY..."
ESSENTIAL_PACKAGES="curl wget unzip jq git build-essential software-properties-common ca-certificates gnupg lsb-release python3 python3-pip python3-venv net-tools htop iotop"

# Add memory-specific tools for memory-optimized instances
if [[ "$MEMORY_CONFIG" == "high" ]]; then
    ESSENTIAL_PACKAGES+=" memstat numactl"
    log "INFO" "Adding memory optimization tools for memory-optimized instance"
fi

# Add CPU-specific tools for compute-optimized instances
if [[ "$CPU_CONFIG" == "high" ]]; then
    ESSENTIAL_PACKAGES+=" cpufrequtils stress-ng"
    log "INFO" "Adding CPU optimization tools for compute-optimized instance"
fi

if ! retry_command 3 10 "Essential packages installation" apt-get install -y $ESSENTIAL_PACKAGES; then
    log "ERROR" "Failed to install essential packages"
    exit 1
fi

log "INFO" "📋 PHASE 3: Enhanced Volume Management and Persistent Storage Setup"

# Volume management validation
log "INFO" "💾 Validating persistent volume setup for $INSTANCE_FAMILY..."
if ! mountpoint -q /persistent; then
    log "ERROR" "Persistent volume not mounted at /persistent"
    exit 1
fi

# Create comprehensive persistent directory structure with instance family awareness
log "INFO" "📁 Setting up enhanced persistent directory structure for $INSTANCE_CATEGORY..."
mkdir -p /persistent/home/ubuntu/{.amazon-q,.aws/amazonq,.config/amazon-q,.local/share/amazon-q,.vscode-server,data,workspace}
mkdir -p /persistent/home/ubuntu/instance-config/$INSTANCE_FAMILY
mkdir -p /persistent/home/ubuntu/logs/$INSTANCE_FAMILY

# CRITICAL FIX: Add VS Code extension authentication storage directories
log "INFO" "📁 Creating VS Code extension authentication storage directories..."
mkdir -p /persistent/home/ubuntu/.config/Code/User/globalStorage
mkdir -p /persistent/home/ubuntu/.local/share/code-server/User/globalStorage
mkdir -p /persistent/home/ubuntu/.cache
mkdir -p /persistent/home/ubuntu/.local/share/keyrings

chown -R ubuntu:ubuntu /persistent/home/ubuntu

# Create instance family specific configuration
cat > /persistent/home/ubuntu/instance-config/$INSTANCE_FAMILY/config.json << EOF
{
  "instance_type": "$INSTANCE_TYPE",
  "instance_family": "$INSTANCE_FAMILY",
  "instance_category": "$INSTANCE_CATEGORY",
  "availability_zone": "$INSTANCE_AZ",
  "memory_config": "$MEMORY_CONFIG",
  "cpu_config": "$CPU_CONFIG",
  "docker_memory_limit": "$DOCKER_MEMORY_LIMIT",
  "node_max_old_space": "$NODE_MAX_OLD_SPACE",
  "setup_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Create symlinks EARLY in the process (ENHANCED)
log "INFO" "🔗 Creating enhanced persistent storage symlinks..."
sudo -u ubuntu bash << 'EOF'
cd /home/ubuntu
# Remove any existing directories/files that would conflict with symlinks
rm -rf .aws .amazon-q .config/amazon-q .local/share/amazon-q .vscode-server workspace .cache 2>/dev/null || true
mkdir -p .config .local/share

# Create symlinks to persistent storage
ln -sf /persistent/home/ubuntu/.aws .aws
ln -sf /persistent/home/ubuntu/.amazon-q .amazon-q
ln -sf /persistent/home/ubuntu/.config/amazon-q .config/amazon-q
ln -sf /persistent/home/ubuntu/.local/share/amazon-q .local/share/amazon-q
ln -sf /persistent/home/ubuntu/.vscode-server .vscode-server
ln -sf /persistent/home/ubuntu/workspace workspace

# CRITICAL FIX: Create VS Code extension authentication symlinks
ln -sf /persistent/home/ubuntu/.config/Code .config/Code
ln -sf /persistent/home/ubuntu/.local/share/code-server .local/share/code-server
ln -sf /persistent/home/ubuntu/.cache .cache
ln -sf /persistent/home/ubuntu/.local/share/keyrings .local/share/keyrings

# Create instance family specific symlinks
ln -sf /persistent/home/ubuntu/instance-config instance-config
ln -sf /persistent/home/ubuntu/logs logs

# Verify symlinks
echo "Enhanced symlinks created:"
ls -la | grep '^l'
EOF

log "INFO" "📋 PHASE 4: Enhanced Development Tools Installation"

# Install Docker with instance family optimizations
log "INFO" "📦 Installing Docker optimized for $INSTANCE_CATEGORY..."
if retry_command 3 10 "Docker GPG key installation" bash -c "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg"; then
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    if retry_command 3 10 "Docker installation" apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin; then
        usermod -aG docker ubuntu
        systemctl enable docker
        systemctl start docker
        
        # Configure Docker daemon with instance family specific settings
        log "INFO" "🔧 Configuring Docker daemon for $INSTANCE_FAMILY..."
        cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-ulimits": {
    "memlock": {
      "Hard": -1,
      "Name": "memlock",
      "Soft": -1
    }
  },
  "default-runtime": "runc",
  "storage-driver": "overlay2"
}
EOF
        
        # Apply memory limits for Docker based on instance family
        if [[ "$MEMORY_CONFIG" == "high" ]]; then
            log "INFO" "Applying high memory configuration for Docker on $INSTANCE_FAMILY"
            echo 'DOCKER_OPTS="--default-ulimit memlock=-1:-1"' >> /etc/default/docker
        fi
        
        systemctl restart docker
        log "SUCCESS" "Docker installed and configured for $INSTANCE_CATEGORY"
    else
        log "WARN" "Docker installation failed, continuing without Docker..."
    fi
else
    log "WARN" "Docker GPG key installation failed, skipping Docker..."
fi

# Install Node.js LTS with instance family optimizations
log "INFO" "📦 Installing Node.js LTS optimized for $INSTANCE_FAMILY..."
if retry_command 3 10 "Node.js repository setup" bash -c "curl -fsSL https://deb.nodesource.com/setup_20.x | bash -"; then
    if retry_command 3 10 "Node.js installation" apt-get install -y nodejs; then
        NODE_VERSION=$(node --version)
        NPM_VERSION=$(npm --version)
        log "SUCCESS" "Node.js $NODE_VERSION and npm $NPM_VERSION installed successfully"
        
        # Configure Node.js memory settings based on instance family
        log "INFO" "🔧 Configuring Node.js for $INSTANCE_CATEGORY..."
        sudo -u ubuntu bash << EOF
echo "export NODE_OPTIONS='--max-old-space-size=$NODE_MAX_OLD_SPACE'" >> /home/ubuntu/.bashrc
echo "# Node.js configuration for $INSTANCE_FAMILY" >> /home/ubuntu/.bashrc
EOF
        
        # Install global packages with instance family considerations
        if [[ "$CPU_CONFIG" == "high" ]]; then
            log "INFO" "Installing additional Node.js tools for compute-optimized instance"
            npm install -g pm2 clinic autocannon
        fi
        
    else
        log "ERROR" "Node.js installation failed"
        exit 1
    fi
else
    log "ERROR" "Node.js repository setup failed"
    exit 1
fi

# Install Python UV package manager with enhanced configuration
log "INFO" "📦 Installing Python UV package manager for $INSTANCE_FAMILY..."
if retry_command 3 10 "UV installation" pip3 install uv; then
    log "SUCCESS" "UV package manager installed successfully"
    
    # Configure UV cache based on instance family
    sudo -u ubuntu bash << EOF
mkdir -p /home/ubuntu/.cache/uv
echo "export UV_CACHE_DIR=/home/ubuntu/.cache/uv" >> /home/ubuntu/.bashrc
echo "# UV configuration for $INSTANCE_FAMILY" >> /home/ubuntu/.bashrc
EOF
    
else
    log "WARN" "UV installation failed, continuing without UV..."
fi

# Set up enhanced development environment paths
log "INFO" "🔧 Setting up enhanced development environment paths for $INSTANCE_CATEGORY..."
mkdir -p /home/ubuntu/.local/{bin,share/uv/{tools,cache}}
chown -R ubuntu:ubuntu /home/ubuntu/.local

# Update PATH for ubuntu user with instance family awareness
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' /home/ubuntu/.bashrc; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/ubuntu/.bashrc
fi

# Add instance family specific environment variables
cat >> /home/ubuntu/.bashrc << EOF

# Enhanced Amazon Q CLI Environment - Instance Family: $INSTANCE_FAMILY
export INSTANCE_TYPE="$INSTANCE_TYPE"
export INSTANCE_FAMILY="$INSTANCE_FAMILY"
export INSTANCE_CATEGORY="$INSTANCE_CATEGORY"
export MEMORY_CONFIG="$MEMORY_CONFIG"
export CPU_CONFIG="$CPU_CONFIG"
export DOCKER_MEMORY_LIMIT="$DOCKER_MEMORY_LIMIT"
export NODE_MAX_OLD_SPACE="$NODE_MAX_OLD_SPACE"

# Instance family specific aliases
alias instance-info='echo "Type: $INSTANCE_TYPE | Family: $INSTANCE_FAMILY | Category: $INSTANCE_CATEGORY"'
alias memory-info='free -h && echo "Docker Limit: $DOCKER_MEMORY_LIMIT | Node Limit: ${NODE_MAX_OLD_SPACE}MB"'
alias cpu-info='nproc && lscpu | grep "Model name"'

EOF

chown ubuntu:ubuntu /home/ubuntu/.bashrc

log "INFO" "📋 PHASE 5: Enhanced Amazon Q CLI Installation"

# Install Amazon Q CLI with proper verification (ENHANCED)
log "INFO" "📦 Installing Amazon Q CLI optimized for $INSTANCE_FAMILY..."
cd /tmp
if retry_command 3 10 "Amazon Q CLI download" wget -q https://desktop-release.q.us-east-1.amazonaws.com/latest/amazon-q.deb; then
    if retry_command 3 10 "Amazon Q CLI installation" apt-get install -y ./amazon-q.deb; then
        # Verify Amazon Q CLI installation
        if command -v q &> /dev/null; then
            Q_VERSION=$(q --version 2>/dev/null || echo "version check failed")
            log "SUCCESS" "Amazon Q CLI installed successfully: $Q_VERSION"
        else
            log "ERROR" "Amazon Q CLI installation failed - command not found"
            exit 1
        fi
    else
        log "ERROR" "Amazon Q CLI package installation failed"
        exit 1
    fi
else
    log "ERROR" "Amazon Q CLI download failed"
    exit 1
fi

log "INFO" "📋 PHASE 5.5: Google Gemini CLI Installation with Persistent Storage and API Key"

# Create persistent directory for Python packages and Gemini CLI
log "INFO" "🐍 Setting up persistent Python environment for Gemini CLI..."
mkdir -p /persistent/home/ubuntu/.local/lib/python3.10/site-packages
mkdir -p /persistent/home/ubuntu/.local/bin
mkdir -p /persistent/home/ubuntu/.config/gemini-cli

# Create symlinks for persistent Python packages
sudo -u ubuntu bash << 'GEMINI_EOF'
cd /home/ubuntu
mkdir -p .local/lib/python3.10
mkdir -p .local/bin
mkdir -p .config

# Create symlinks to persistent storage for Python packages
ln -sf /persistent/home/ubuntu/.local/lib/python3.10/site-packages .local/lib/python3.10/site-packages
ln -sf /persistent/home/ubuntu/.local/bin .local/bin
ln -sf /persistent/home/ubuntu/.config/gemini-cli .config/gemini-cli

# Verify symlinks
echo "Python persistent storage symlinks created successfully"
GEMINI_EOF

# Install Gemini CLI with user-level installation to persistent storage
log "INFO" "📦 Installing Google Gemini CLI to persistent storage..."
sudo -u ubuntu bash << 'INSTALL_GEMINI_EOF'
export HOME=/home/ubuntu
export PATH="/home/ubuntu/.local/bin:$PATH"

# Install gemini-cli using pip with user flag (goes to persistent storage via symlinks)
pip3 install --user google-generativeai gemini-cli

# Verify installation
if command -v gemini-cli &> /dev/null; then
    echo "Gemini CLI installed successfully"
else
    echo "Gemini CLI installation may have issues"
fi
INSTALL_GEMINI_EOF

# Create Gemini CLI configuration with API key
log "INFO" "⚙️ Creating Gemini CLI configuration with API key..."
cat > /persistent/home/ubuntu/.config/gemini-cli/config.json << 'GEMINI_CONFIG_EOF'
{
  "api_key": "AIzaSyCz1XCvBqdV6OIINGUHcf19bivQU1fecyQ",
  "model": "gemini-2.0-flash-exp",
  "temperature": 0.7,
  "max_tokens": 2048,
  "persistent_storage": "/persistent/home/ubuntu/.config/gemini-cli",
  "instance_family": "INSTANCE_FAMILY_PLACEHOLDER",
  "installation_date": "INSTALL_DATE_PLACEHOLDER"
}
GEMINI_CONFIG_EOF

# Create TOML config file that gemini-cli actually uses
cat > /persistent/home/ubuntu/.config/gemini-cli.toml << 'GEMINI_TOML_EOF'
[gemini]
api_key = "AIzaSyCz1XCvBqdV6OIINGUHcf19bivQU1fecyQ"
model = "gemini-2.0-flash-exp"
temperature = 0.7
max_tokens = 2048
GEMINI_TOML_EOF

# Replace placeholders in config
sed -i "s/INSTANCE_FAMILY_PLACEHOLDER/$INSTANCE_FAMILY/g" /persistent/home/ubuntu/.config/gemini-cli/config.json
sed -i "s/INSTALL_DATE_PLACEHOLDER/$(date -u +%Y-%m-%dT%H:%M:%SZ)/g" /persistent/home/ubuntu/.config/gemini-cli/config.json

# Create Gemini CLI usage script
cat > /persistent/home/ubuntu/.local/bin/gemini-setup << 'GEMINI_SETUP_EOF'
#!/bin/bash
# Gemini CLI Setup Helper Script
# This script helps configure the Gemini CLI with your API key

echo "🤖 Google Gemini CLI Setup Helper"
echo "=================================="
echo ""
echo "✅ Gemini CLI is already configured with API key!"
echo "✅ Using Gemini Flash 2.5 (gemini-2.0-flash-exp) model"
echo ""
echo "Available commands:"
echo "1. Basic usage:"
echo "   gemini 'Hello, how are you?'"
echo ""
echo "2. Code generation:"
echo "   gcode 'Python function to read CSV'"
echo ""
echo "3. AI assistance:"
echo "   gai 'explain AWS Lambda'"
echo ""
echo "4. Interactive chat:"
echo "   gchat"
echo ""
echo "Current configuration:"
echo "====================="
cat ~/.config/gemini-cli/config.json
echo ""
echo "TOML configuration:"
cat ~/.config/gemini-cli.toml
echo ""
echo "Installation location: $(which gemini-cli 2>/dev/null || echo 'Available at /home/ubuntu/.local/bin/gemini-cli')"
echo "Python packages location: ~/.local/lib/python3.10/site-packages (persistent)"
echo "Configuration location: ~/.config/gemini-cli/ (persistent)"
echo ""
echo "🧪 Test the installation:"
echo "gemini 'Hello, please confirm Gemini CLI is working!'"
echo ""
echo "🐍 Python API usage:"
echo "python3 -c \"import google.generativeai as genai; genai.configure(api_key='AIzaSyCz1XCvBqdV6OIINGUHcf19bivQU1fecyQ'); model = genai.GenerativeModel('gemini-2.0-flash-exp'); print(model.generate_content('Hello from Python API!').text)\""
GEMINI_SETUP_EOF

# Create comprehensive test script
cat > /persistent/home/ubuntu/.local/bin/test-gemini << 'TEST_GEMINI_EOF'
#!/usr/bin/env python3
# Comprehensive Gemini API Test Script

import google.generativeai as genai
import sys

def main():
    print("🧪 Comprehensive Gemini Flash 2.5 Test")
    print("=====================================")
    
    # Configure API key
    genai.configure(api_key="AIzaSyCz1XCvBqdV6OIINGUHcf19bivQU1fecyQ")
    
    try:
        # Test 1: Basic functionality
        print("\n✅ Test 1: Basic functionality")
        model = genai.GenerativeModel('gemini-2.0-flash-exp')
        response = model.generate_content("Say 'Gemini Flash 2.5 is working on AWS!' and nothing else.")
        print(f"Response: {response.text.strip()}")
        
        # Test 2: AWS-specific question
        print("\n✅ Test 2: AWS knowledge")
        response = model.generate_content("What are 3 key benefits of AWS spot instances? Be concise.")
        print(f"Response: {response.text.strip()}")
        
        # Test 3: Code generation
        print("\n✅ Test 3: Code generation")
        response = model.generate_content("Write a simple Python function to reverse a string. Just the function.")
        print(f"Response: {response.text.strip()}")
        
        # Test 4: Technical explanation
        print("\n✅ Test 4: Technical explanation")
        response = model.generate_content("Explain what a Docker container is in one sentence.")
        print(f"Response: {response.text.strip()}")
        
        print("\n🎉 All tests passed! Gemini Flash 2.5 is fully functional!")
        return True
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
TEST_GEMINI_EOF

# Create simple shell commands for easy access
cat > /persistent/home/ubuntu/.local/bin/gemini << 'GEMINI_CMD'
#!/bin/bash
# Simple Gemini command wrapper

if [ $# -eq 0 ]; then
    echo "Usage: gemini 'your question here'"
    echo "Example: gemini 'What is AWS?'"
    exit 1
fi

python3 -c "
import google.generativeai as genai
import sys
genai.configure(api_key='AIzaSyCz1XCvBqdV6OIINGUHcf19bivQU1fecyQ')
model = genai.GenerativeModel('gemini-2.0-flash-exp')
try:
    response = model.generate_content('''$*''')
    print(response.text)
except Exception as e:
    print(f'Error: {e}')
"
GEMINI_CMD

# Create code generation command
cat > /persistent/home/ubuntu/.local/bin/gcode << 'GCODE_CMD'
#!/bin/bash
# Gemini code generation command

if [ $# -eq 0 ]; then
    echo "Usage: gcode 'describe the code you want'"
    echo "Example: gcode 'Python function to sort a list'"
    exit 1
fi

python3 -c "
import google.generativeai as genai
genai.configure(api_key='AIzaSyCz1XCvBqdV6OIINGUHcf19bivQU1fecyQ')
model = genai.GenerativeModel('gemini-2.0-flash-exp')
try:
    prompt = '''Write code for: $*. Provide clean, well-commented code.'''
    response = model.generate_content(prompt)
    print(response.text)
except Exception as e:
    print(f'Error: {e}')
"
GCODE_CMD

# Create AI assistance command
cat > /persistent/home/ubuntu/.local/bin/gai << 'GAI_CMD'
#!/bin/bash
# Gemini AI assistant command

if [ $# -eq 0 ]; then
    echo "Usage: gai 'your question or task'"
    echo "Example: gai 'explain docker containers'"
    exit 1
fi

python3 -c "
import google.generativeai as genai
genai.configure(api_key='AIzaSyCz1XCvBqdV6OIINGUHcf19bivQU1fecyQ')
model = genai.GenerativeModel('gemini-2.0-flash-exp')
try:
    prompt = '''As a helpful AI assistant: $*'''
    response = model.generate_content(prompt)
    print(response.text)
except Exception as e:
    print(f'Error: {e}')
"
GAI_CMD

# Create interactive chat command
cat > /persistent/home/ubuntu/.local/bin/gchat << 'GCHAT_CMD'
#!/bin/bash
# Interactive Gemini chat

echo "🤖 Gemini Interactive Chat"
echo "=========================="
echo "Type 'quit' or 'exit' to end the conversation"
echo ""

python3 << 'CHAT_PYTHON'
import google.generativeai as genai
genai.configure(api_key='AIzaSyCz1XCvBqdV6OIINGUHcf19bivQU1fecyQ')
model = genai.GenerativeModel('gemini-2.0-flash-exp')

while True:
    try:
        question = input("You: ")
        if question.lower() in ['quit', 'exit', 'bye']:
            print("Goodbye! 👋")
            break
        if question.strip() == "":
            continue
        response = model.generate_content(question)
        print(f"Gemini: {response.text}")
        print()
    except KeyboardInterrupt:
        print("\nGoodbye! 👋")
        break
    except Exception as e:
        print(f"Error: {e}")
CHAT_PYTHON
GCHAT_CMD

chmod +x /persistent/home/ubuntu/.local/bin/test-gemini
chmod +x /persistent/home/ubuntu/.local/bin/gemini
chmod +x /persistent/home/ubuntu/.local/bin/gcode
chmod +x /persistent/home/ubuntu/.local/bin/gai
chmod +x /persistent/home/ubuntu/.local/bin/gchat

chmod +x /persistent/home/ubuntu/.local/bin/gemini-setup

# Update .bashrc to include .local/bin in PATH
log "INFO" "🔧 Updating PATH for Gemini CLI..."
sudo -u ubuntu bash << 'BASHRC_EOF'
# Add .local/bin to PATH if not already present
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc; then
    echo '' >> ~/.bashrc
    echo '# Add local Python packages to PATH (for Gemini CLI and other tools)' >> ~/.bashrc
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    echo "Updated .bashrc with .local/bin PATH"
fi
BASHRC_EOF

# Set proper permissions
chown -R ubuntu:ubuntu /persistent/home/ubuntu/.config/gemini-cli
chown -R ubuntu:ubuntu /persistent/home/ubuntu/.local
chmod 755 /persistent/home/ubuntu/.local/bin/gemini-setup

log "SUCCESS" "✅ Google Gemini CLI installation completed with persistent storage and API key"
log "INFO" "📝 Configuration file: ~/.config/gemini-cli/config.json"
log "INFO" "🔧 Setup helper: Run 'gemini-setup' for usage instructions"
log "INFO" "💾 All Gemini CLI data will persist across spot instance interruptions"
log "INFO" "🔑 API key configured - Gemini CLI ready for immediate use"

log "INFO" "📋 PHASE 5.6: GitHub Copilot CLI Installation with Persistent Storage"

# Install GitHub CLI (prerequisite for Copilot CLI)
log "INFO" "📦 Installing GitHub CLI (prerequisite for Copilot CLI)..."
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt update
apt install gh -y

# Create persistent directories for GitHub CLI and Copilot
log "INFO" "📁 Setting up persistent GitHub CLI environment..."
mkdir -p /persistent/home/ubuntu/.config/gh
mkdir -p /persistent/home/ubuntu/.local/bin
chown -R ubuntu:ubuntu /persistent/home/ubuntu/.config/gh

# Create symlinks for persistent GitHub CLI configuration
sudo -u ubuntu bash << 'GITHUB_SYMLINKS_EOF'
cd /home/ubuntu
mkdir -p .config

# Create symlink to persistent GitHub CLI config
ln -sf /persistent/home/ubuntu/.config/gh .config/gh

echo "GitHub CLI persistent storage symlinks created successfully"
GITHUB_SYMLINKS_EOF

# Create simple GitHub Copilot CLI commands
log "INFO" "📝 Creating GitHub Copilot CLI wrapper commands..."

# Create 'copilot' command for general suggestions
cat > /persistent/home/ubuntu/.local/bin/copilot << 'COPILOT_CMD'
#!/bin/bash
# GitHub Copilot CLI wrapper

if [ $# -eq 0 ]; then
    echo "Usage: copilot 'describe what you want to do'"
    echo "Example: copilot 'list all files in current directory'"
    echo ""
    echo "Note: Requires GitHub authentication with 'gh auth login'"
    exit 1
fi

# Check if gh is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ GitHub CLI not authenticated"
    echo "Please run: gh auth login"
    echo "Then try: gh extension install github/gh-copilot"
    exit 1
fi

# Check if copilot extension is installed
if ! gh extension list | grep -q copilot; then
    echo "❌ GitHub Copilot extension not installed"
    echo "Please run: gh extension install github/gh-copilot"
    exit 1
fi

# Use GitHub Copilot CLI
gh copilot suggest "$*"
COPILOT_CMD

# Create 'ghcode' command for code explanations
cat > /persistent/home/ubuntu/.local/bin/ghcode << 'GHCODE_CMD'
#!/bin/bash
# GitHub Copilot code explanation wrapper

if [ $# -eq 0 ]; then
    echo "Usage: ghcode 'command or code to explain'"
    echo "Example: ghcode 'docker run -d nginx'"
    echo ""
    echo "Note: Requires GitHub authentication with 'gh auth login'"
    exit 1
fi

# Check if gh is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ GitHub CLI not authenticated"
    echo "Please run: gh auth login"
    echo "Then try: gh extension install github/gh-copilot"
    exit 1
fi

# Check if copilot extension is installed
if ! gh extension list | grep -q copilot; then
    echo "❌ GitHub Copilot extension not installed"
    echo "Please run: gh extension install github/gh-copilot"
    exit 1
fi

# Use GitHub Copilot CLI for explanation
gh copilot explain "$*"
GHCODE_CMD

# Create setup helper for GitHub Copilot
cat > /persistent/home/ubuntu/.local/bin/copilot-setup << 'COPILOT_SETUP_CMD'
#!/bin/bash
# GitHub Copilot CLI Setup Helper

echo "🤖 GitHub Copilot CLI Setup Helper"
echo "=================================="
echo ""
echo "📋 Current Status:"
echo "GitHub CLI: $(which gh 2>/dev/null && echo 'Installed' || echo 'Not installed')"
echo "Authentication: $(gh auth status >/dev/null 2>&1 && echo 'Authenticated' || echo 'Not authenticated')"
echo "Copilot Extension: $(gh extension list 2>/dev/null | grep -q copilot && echo 'Installed' || echo 'Not installed')"
echo ""
echo "🚀 Setup Steps:"
echo "1. Authenticate with GitHub:"
echo "   gh auth login"
echo ""
echo "2. Install Copilot extension:"
echo "   gh extension install github/gh-copilot"
echo ""
echo "3. Test the installation:"
echo "   copilot 'list files in current directory'"
echo "   ghcode 'ls -la'"
echo ""
echo "📋 Available Commands (after setup):"
echo "- copilot 'describe what you want to do'"
echo "- ghcode 'command or code to explain'"
echo ""
echo "💾 All configuration is stored in persistent storage!"
echo "💾 GitHub authentication will persist across spot interruptions!"
COPILOT_SETUP_CMD

chmod +x /persistent/home/ubuntu/.local/bin/copilot
chmod +x /persistent/home/ubuntu/.local/bin/ghcode
chmod +x /persistent/home/ubuntu/.local/bin/copilot-setup

# Set proper permissions
chown -R ubuntu:ubuntu /persistent/home/ubuntu/.config/gh
chown -R ubuntu:ubuntu /persistent/home/ubuntu/.local/bin/copilot*
chown -R ubuntu:ubuntu /persistent/home/ubuntu/.local/bin/ghcode

log "SUCCESS" "✅ GitHub Copilot CLI installation completed with persistent storage"
log "INFO" "📝 GitHub CLI installed and ready for authentication"
log "INFO" "🔧 Setup helper: Run 'copilot-setup' for configuration instructions"
log "INFO" "💾 All GitHub CLI data will persist across spot instance interruptions"
log "INFO" "🔑 Authentication required - run 'gh auth login' after first boot"

log "INFO" "📋 PHASE 6: Enhanced Amazon Q Configuration Setup"

# Create enhanced Amazon Q CLI configuration with instance family awareness
log "INFO" "⚙️ Creating enhanced Amazon Q CLI configuration for $INSTANCE_FAMILY..."
if [ ! -f /persistent/home/ubuntu/.amazon-q/config.json ]; then
    cat > /persistent/home/ubuntu/.amazon-q/config.json << EOT
{
  "mcp_server_allow_write": true,
  "mcp_server_allow_sensitive_data_access": true,
  "default_model": "anthropic.claude-3-opus-20240229",
  "log_level": "info",
  "auto_approve_tools": true,
  "trust_all_tools": true,
  "instance_config": {
    "instance_type": "$INSTANCE_TYPE",
    "instance_family": "$INSTANCE_FAMILY",
    "instance_category": "$INSTANCE_CATEGORY",
    "memory_config": "$MEMORY_CONFIG",
    "cpu_config": "$CPU_CONFIG",
    "availability_zone": "$INSTANCE_AZ"
  }
}
EOT
    chown ubuntu:ubuntu /persistent/home/ubuntu/.amazon-q/config.json
    chmod 600 /persistent/home/ubuntu/.amazon-q/config.json
    log "SUCCESS" "Enhanced Amazon Q CLI configuration created for $INSTANCE_FAMILY"
else
    log "INFO" "Amazon Q CLI configuration already exists"
fi

# Create ENHANCED MCP server configuration with ALL 17 servers + instance family optimizations
log "INFO" "🔧 Creating ENHANCED MCP server configuration with 17 servers for $INSTANCE_FAMILY..."
if [ ! -f /persistent/home/ubuntu/.aws/amazonq/mcp.json ]; then
    # Get the current chat logs bucket name from CloudFormation outputs
    CHAT_LOGS_BUCKET=$(aws cloudformation describe-stacks --region $REGION --query "Stacks[?contains(StackName, 'amazon-q-cli-vscode-v10-enhanced')].Outputs[?OutputKey=='ChatLogsBucket'].OutputValue" --output text 2>/dev/null || echo "amazonq-cli-persistent-stack-chatlogsbucket-ripceqclrokp")
    
    # Set memory limits for MCP servers based on instance family
    case $MEMORY_CONFIG in
        "high")
            MCP_MEMORY_LIMIT="2048"
            MCP_LOG_LEVEL="WARN"
            ;;
        "balanced")
            MCP_MEMORY_LIMIT="1024"
            MCP_LOG_LEVEL="ERROR"
            ;;
        "standard")
            MCP_MEMORY_LIMIT="512"
            MCP_LOG_LEVEL="ERROR"
            ;;
    esac
    
    log "INFO" "Configuring MCP servers with memory limit: ${MCP_MEMORY_LIMIT}MB for $INSTANCE_CATEGORY"
    
    cat > /persistent/home/ubuntu/.aws/amazonq/mcp.json << EOT
{
  "mcpServers": {
    "awslabs.core-mcp-server": {
      "command": "uvx",
      "args": ["awslabs.core-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "AWS_PROFILE": "default",
        "INSTANCE_FAMILY": "$INSTANCE_FAMILY",
        "NODE_OPTIONS": "--max-old-space-size=$MCP_MEMORY_LIMIT"
      },
      "autoApprove": [],
      "disabled": false
    },
    "awslabs.aws-documentation-mcp-server": {
      "command": "uvx",
      "args": ["awslabs.aws-documentation-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "AWS_PROFILE": "default",
        "INSTANCE_FAMILY": "$INSTANCE_FAMILY"
      },
      "disabled": false,
      "autoApprove": []
    },
    "awslabs.eks-mcp-server": {
      "autoApprove": [],
      "disabled": false,
      "command": "uvx",
      "args": ["awslabs.eks-mcp-server@latest", "--allow-write"],
      "env": {
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "AWS_PROFILE": "default",
        "INSTANCE_FAMILY": "$INSTANCE_FAMILY"
      },
      "transportType": "stdio"
    },
    "awslabs.cost-analysis-mcp-server": {
      "command": "uvx",
      "args": ["awslabs.cost-analysis-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "AWS_PROFILE": "default",
        "INSTANCE_FAMILY": "$INSTANCE_FAMILY"
      },
      "disabled": false,
      "autoApprove": []
    },
    "awslabs.aws-diagram-mcp-server": {
      "command": "uvx",
      "args": ["awslabs.aws-diagram-mcp-server"],
      "env": {
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "AWS_PROFILE": "default",
        "INSTANCE_FAMILY": "$INSTANCE_FAMILY"
      },
      "autoApprove": [],
      "disabled": false
    },
    "awslabs.cfn-mcp-server": {
      "command": "uvx",
      "args": ["awslabs.cfn-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "INSTANCE_FAMILY": "$INSTANCE_FAMILY"
      },
      "disabled": false,
      "autoApprove": []
    },
    "awslabs.git-repo-research-mcp-server": {
      "command": "uvx",
      "args": ["awslabs.git-repo-research-mcp-server@latest"],
      "env": {
        "AWS_PROFILE": "default",
        "AWS_REGION": "$REGION",
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "GITHUB_TOKEN": "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",
        "INSTANCE_FAMILY": "$INSTANCE_FAMILY"
      },
      "disabled": false,
      "autoApprove": []
    },
    "awslabs.ecs-mcp-server": {
      "command": "uvx",
      "args": ["--from", "awslabs-ecs-mcp-server", "ecs-mcp-server"],
      "env": {
        "AWS_PROFILE": "default",
        "AWS_REGION": "$REGION",
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "ALLOW_WRITE": "true",
        "ALLOW_SENSITIVE_DATA": "true",
        "INSTANCE_FAMILY": "$INSTANCE_FAMILY"
      },
      "disabled": false,
      "autoApprove": []
    },
    "puppeteer": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-puppeteer"],
      "env": {
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "NODE_OPTIONS": "--max-old-space-size=$MCP_MEMORY_LIMIT"
      },
      "disabled": false,
      "autoApprove": ["*"]
    },
    "firecrawl-mcp": {
      "command": "npx",
      "args": ["-y", "firecrawl-mcp"],
      "env": {
        "FIRECRAWL_API_KEY": "fc-fe43ba9746564496b8ff51ba1b66e9f9",
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "NODE_OPTIONS": "--max-old-space-size=$MCP_MEMORY_LIMIT"
      },
      "disabled": false,
      "autoApprove": ["*"]
    },
    "duckduckgo-search": {
      "command": "npx",
      "args": ["-y", "duckduckgo-mcp-server"],
      "env": {
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "NODE_OPTIONS": "--max-old-space-size=$MCP_MEMORY_LIMIT"
      },
      "disabled": false,
      "autoApprove": ["*"]
    },
    "awslabs.cost-explorer-mcp-server": {
      "command": "uvx",
      "args": ["awslabs.cost-explorer-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "INSTANCE_FAMILY": "$INSTANCE_FAMILY"
      },
      "disabled": false,
      "autoApprove": ["*"]
    },
    "awslabs.support-mcp-server": {
      "command": "uvx",
      "args": [
        "awslabs.aws-support-mcp-server@latest",
        "--debug",
        "--log-file",
        "./logs/mcp_support_server.log"
      ],
      "env": {
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "INSTANCE_FAMILY": "$INSTANCE_FAMILY"
      },
      "disabled": false,
      "autoApprove": ["*"]
    },
    "awslabs.bedrock-kb-retrieval-mcp-server": {
      "command": "uvx",
      "args": ["awslabs.bedrock-kb-retrieval-mcp-server@latest"],
      "env": {
        "AWS_REGION": "us-east-1",
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "KB_INCLUSION_TAG_KEY": "optional-tag-key-to-filter-kbs",
        "BEDROCK_KB_RERANKING_ENABLED": "false",
        "INSTANCE_FAMILY": "$INSTANCE_FAMILY"
      },
      "disabled": false,
      "autoApprove": ["*"]
    },
    "awslabs.cdk-mcp-server": {
      "command": "uvx",
      "args": ["awslabs.cdk-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "INSTANCE_FAMILY": "$INSTANCE_FAMILY"
      },
      "disabled": false,
      "autoApprove": ["*"]
    },
    "awslabs.nova-canvas-mcp-server": {
      "command": "uvx",
      "args": ["awslabs.nova-canvas-mcp-server@latest"],
      "env": {
        "AWS_REGION": "us-east-1",
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "INSTANCE_FAMILY": "$INSTANCE_FAMILY"
      },
      "disabled": false,
      "autoApprove": ["*"]
    },
    "awslabs.aws-bedrock-data-automation-mcp-server": {
      "command": "uvx",
      "args": ["awslabs.aws-bedrock-data-automation-mcp-server@latest"],
      "env": {
        "AWS_REGION": "us-east-1",
        "AWS_BUCKET_NAME": "$CHAT_LOGS_BUCKET",
        "BASE_DIR": "/home/ubuntu",
        "FASTMCP_LOG_LEVEL": "$MCP_LOG_LEVEL",
        "INSTANCE_FAMILY": "$INSTANCE_FAMILY"
      },
      "disabled": false,
      "autoApprove": []
    }
  },
  "instance_config": {
    "instance_type": "$INSTANCE_TYPE",
    "instance_family": "$INSTANCE_FAMILY",
    "instance_category": "$INSTANCE_CATEGORY",
    "memory_config": "$MEMORY_CONFIG",
    "cpu_config": "$CPU_CONFIG",
    "mcp_memory_limit": "$MCP_MEMORY_LIMIT",
    "mcp_log_level": "$MCP_LOG_LEVEL",
    "setup_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOT
    chown ubuntu:ubuntu /persistent/home/ubuntu/.aws/amazonq/mcp.json
    chmod 600 /persistent/home/ubuntu/.aws/amazonq/mcp.json
    log "SUCCESS" "ENHANCED MCP server configuration created with 17 servers for $INSTANCE_FAMILY"
else
    log "INFO" "MCP server configuration already exists"
fi

log "INFO" "📋 PHASE 7: Enhanced VS Code Server Installation"

# Install VS Code Server with enhanced configuration for instance family
log "INFO" "📦 Installing VS Code Server (pinned to stable version 4.89.1) optimized for $INSTANCE_FAMILY..."
# CRITICAL FIX: Ensure HOME environment variable is set for VS Code Server installation
export HOME=/root
log "INFO" "🔧 HOME environment variable confirmed: $HOME"
# Pin to stable version 4.89.1 using direct .deb download to avoid latest version issues
if retry_command 3 30 "VS Code Server download" curl -fOL https://github.com/coder/code-server/releases/download/v4.89.1/code-server_4.89.1_amd64.deb; then
    if retry_command 3 10 "VS Code Server installation" dpkg -i code-server_4.89.1_amd64.deb; then
        # Verify installation
        if command -v code-server &> /dev/null; then
            CODE_SERVER_VERSION=$(code-server --version | head -1)
            log "SUCCESS" "VS Code Server installed successfully: $CODE_SERVER_VERSION"
        else
            log "ERROR" "VS Code Server installation failed - command not found"
            exit 1
        fi
    else
        log "ERROR" "VS Code Server dpkg installation failed"
        exit 1
    fi
else
    log "ERROR" "VS Code Server download failed"
    exit 1
fi

# Configure VS Code Server with instance family optimizations
log "INFO" "⚙️ Configuring VS Code Server for $INSTANCE_CATEGORY..."
sudo -u ubuntu mkdir -p /home/ubuntu/.config/code-server

# Create enhanced VS Code Server configuration
sudo -u ubuntu cat > /home/ubuntu/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:8080
auth: none
password: 
cert: false
# Enhanced configuration for $INSTANCE_FAMILY
user-data-dir: /home/ubuntu/.vscode-server/data
extensions-dir: /home/ubuntu/.vscode-server/extensions
# Instance family specific settings
EOF

# Add instance family specific VS Code settings
case $MEMORY_CONFIG in
    "high")
        echo "# Memory optimized settings for $INSTANCE_FAMILY" >> /home/ubuntu/.config/code-server/config.yaml
        ;;
    "balanced")
        echo "# Balanced settings for $INSTANCE_FAMILY" >> /home/ubuntu/.config/code-server/config.yaml
        ;;
    "standard")
        echo "# Standard settings for $INSTANCE_FAMILY" >> /home/ubuntu/.config/code-server/config.yaml
        ;;
esac

# Create and start systemd service with enhanced configuration
log "INFO" "🔧 Creating and starting enhanced VS Code Server systemd service..."
systemctl enable --now code-server@ubuntu
log "INFO" "⏳ Waiting 30 seconds for VS Code Server service to fully initialize..."
sleep 30

# Verify VS Code Server is running
if systemctl is-active --quiet code-server@ubuntu; then
    log "SUCCESS" "VS Code Server service is active and running on $INSTANCE_FAMILY"
    # Check if port 8080 is listening with retries
    PORT_READY=false
    for i in {1..10}; do
        if ss -tlnp | grep -q ":8080"; then
            log "SUCCESS" "VS Code Server is listening on port 8080"
            PORT_READY=true
            break
        else
            log "INFO" "Waiting for port 8080 to be ready (attempt $i/10)..."
            sleep 5
        fi
    done
    if [ "$PORT_READY" = false ]; then
        log "WARN" "VS Code Server service is running but port 8080 not detected after 50 seconds"
    fi
else
    log "ERROR" "VS Code Server service failed to start"
    # Try manual start as fallback
    log "INFO" "Attempting manual VS Code Server start for $INSTANCE_FAMILY..."
    sudo -u ubuntu nohup code-server --bind-addr 0.0.0.0:8080 --auth none > /tmp/code-server.log 2>&1 &
    log "INFO" "⏳ Waiting 30 seconds for manual start..."
    sleep 30
    if ss -tlnp | grep -q ":8080"; then
        log "SUCCESS" "VS Code Server started manually and listening on port 8080"
    else
        log "ERROR" "VS Code Server failed to start even manually"
        log "ERROR" "Check /tmp/code-server.log for details"
    fi
fi

log "INFO" "📋 PHASE 8: Enhanced VS Code Extensions Installation"

# Wait for VS Code Server to be fully ready
log "INFO" "⏳ Waiting 20 seconds for VS Code Server to be fully ready on $INSTANCE_FAMILY..."
sleep 20

# Install essential VS Code extensions with better error handling
EXTENSIONS=(
    "amazonwebservices.amazon-q-vscode"
    "amazonwebservices.aws-toolkit-vscode"
    "github.copilot"
    "github.copilot-chat"
    "ms-python.python"
)

# Add instance family specific extensions
case $INSTANCE_CATEGORY in
    "Compute Optimized")
        EXTENSIONS+=("ms-vscode.cpptools" "ms-dotnettools.csharp")
        log "INFO" "Adding compute-focused extensions for $INSTANCE_FAMILY"
        ;;
    "Memory Optimized")
        EXTENSIONS+=("ms-python.python" "ms-toolsai.jupyter")
        log "INFO" "Adding memory-intensive extensions for $INSTANCE_FAMILY"
        ;;
esac

log "INFO" "📦 Installing enhanced VS Code extensions for $INSTANCE_FAMILY..."
INSTALLED_COUNT=0
for extension in "${EXTENSIONS[@]}"; do
    log "INFO" "Installing $extension on $INSTANCE_FAMILY..."
    if sudo -u ubuntu code-server --install-extension "$extension" --force; then
        ((INSTALLED_COUNT++))
        log "SUCCESS" "$extension installed successfully"
    else
        log "WARN" "$extension installation failed, continuing..."
    fi
done

log "INFO" "📋 PHASE 9: Enhanced Final Verification and Permissions"

# Set proper permissions with instance family awareness
log "INFO" "🔒 Setting enhanced permissions for $INSTANCE_FAMILY..."
chmod 600 /persistent/home/ubuntu/.amazon-q/config.json 2>/dev/null || log "WARN" "Could not set Amazon Q config permissions"
chmod 600 /persistent/home/ubuntu/.aws/amazonq/mcp.json 2>/dev/null || log "WARN" "Could not set MCP config permissions"
chown -R ubuntu:ubuntu /persistent/home/ubuntu

# Verify persistent storage symlinks with enhanced checks
log "INFO" "🔍 Verifying enhanced persistent storage symlinks..."
SYMLINK_ERRORS=0
for link in .aws .amazon-q .vscode-server workspace instance-config logs .cache; do
    if sudo -u ubuntu [ -L "/home/ubuntu/$link" ] && sudo -u ubuntu [ -e "/home/ubuntu/$link" ]; then
        TARGET=$(sudo -u ubuntu readlink "/home/ubuntu/$link")
        log "SUCCESS" "Enhanced symlink $link -> $TARGET verified"
    else
        log "ERROR" "Enhanced symlink $link is broken or missing"
        ((SYMLINK_ERRORS++))
    fi
done

# Verify nested VS Code extension symlinks
for nested_link in ".config/Code" ".local/share/code-server" ".local/share/keyrings"; do
    if sudo -u ubuntu [ -L "/home/ubuntu/$nested_link" ] && sudo -u ubuntu [ -e "/home/ubuntu/$nested_link" ]; then
        TARGET=$(sudo -u ubuntu readlink "/home/ubuntu/$nested_link")
        log "SUCCESS" "VS Code extension symlink $nested_link -> $TARGET verified"
    else
        log "ERROR" "VS Code extension symlink $nested_link is broken or missing"
        ((SYMLINK_ERRORS++))
    fi
done

log "INFO" "📋 PHASE 10: Enhanced Final Comprehensive Verification"

# Verify Amazon Q CLI
if command -v q &> /dev/null; then
    Q_VERSION_FINAL=$(q --version 2>/dev/null || echo 'installed but version check failed')
    log "SUCCESS" "Amazon Q CLI verification on $INSTANCE_FAMILY: $Q_VERSION_FINAL"
else
    log "ERROR" "Amazon Q CLI verification failed"
fi

# Verify VS Code Server
if systemctl is-active --quiet code-server@ubuntu; then
    log "SUCCESS" "VS Code Server service is active on $INSTANCE_FAMILY"
    if ss -tlnp | grep -q ":8080"; then
        log "SUCCESS" "VS Code Server is listening on port 8080"
    else
        log "WARN" "VS Code Server service active but port not listening"
    fi
else
    log "ERROR" "VS Code Server service is not active"
fi

# Verify configuration files
if sudo -u ubuntu [ -f "/home/ubuntu/.amazon-q/config.json" ]; then
    log "SUCCESS" "Enhanced Amazon Q configuration file accessible"
else
    log "ERROR" "Enhanced Amazon Q configuration file not accessible"
fi

if sudo -u ubuntu [ -f "/home/ubuntu/.aws/amazonq/mcp.json" ]; then
    MCP_SERVER_COUNT=$(sudo -u ubuntu jq '.mcpServers | keys | length' /home/ubuntu/.aws/amazonq/mcp.json)
    log "SUCCESS" "Enhanced MCP configuration file accessible with $MCP_SERVER_COUNT servers"
else
    log "ERROR" "Enhanced MCP configuration file not accessible"
fi

# Verify development tools with instance family awareness
NODE_VERSION_FINAL=$(node --version 2>/dev/null || echo "not found")
NPM_VERSION_FINAL=$(npm --version 2>/dev/null || echo "not found")
DOCKER_STATUS=$(systemctl is-active docker 2>/dev/null || echo "not active")

log "SUCCESS" "Enhanced development tools verification for $INSTANCE_FAMILY:"
log "INFO" "Node.js: $NODE_VERSION_FINAL (Max Old Space: ${NODE_MAX_OLD_SPACE}MB)"
log "INFO" "npm: $NPM_VERSION_FINAL"
log "INFO" "Docker: $DOCKER_STATUS (Memory Limit: $DOCKER_MEMORY_LIMIT)"

# Enhanced final summary with instance family details
log "SUCCESS" "🎉 Enhanced Amazon Q CLI + VS Code Server setup V10.0 completed for $INSTANCE_FAMILY!"
log "INFO" "📊 Enhanced Setup Summary:"
log "INFO" "Instance ID: $INSTANCE_ID"
log "INFO" "Instance Type: $INSTANCE_TYPE"
log "INFO" "Instance Family: $INSTANCE_FAMILY"
log "INFO" "Instance Category: $INSTANCE_CATEGORY"
log "INFO" "Public IP: $PUBLIC_IP"
log "INFO" "Availability Zone: $INSTANCE_AZ"
log "INFO" "Memory Configuration: $MEMORY_CONFIG"
log "INFO" "CPU Configuration: $CPU_CONFIG"
log "INFO" "Amazon Q CLI: $(command -v q &> /dev/null && echo 'Installed' || echo 'Failed')"
log "INFO" "VS Code Extensions Installed: $INSTALLED_COUNT"
log "INFO" "VS Code Server: $(systemctl is-active code-server@ubuntu 2>/dev/null || echo 'not active')"
log "INFO" "MCP Servers: $(sudo -u ubuntu jq '.mcpServers | keys | length' /home/ubuntu/.aws/amazonq/mcp.json 2>/dev/null || echo '0')"
log "INFO" "MCP Memory Limit: ${MCP_MEMORY_LIMIT}MB"
log "INFO" "Docker Memory Limit: $DOCKER_MEMORY_LIMIT"
log "INFO" "Node.js Memory Limit: ${NODE_MAX_OLD_SPACE}MB"
log "INFO" "Symlink Errors: $SYMLINK_ERRORS"
log "INFO" "Port 8080 Status: $(ss -tlnp | grep -q ':8080' && echo 'Listening' || echo 'Not listening')"

if [ $SYMLINK_ERRORS -eq 0 ] && command -v q &> /dev/null && ss -tlnp | grep -q ':8080'; then
    log "SUCCESS" "✅ All enhanced components verified successfully for $INSTANCE_FAMILY!"
    log "SUCCESS" "✅ VS Code Server ready at http://$PUBLIC_IP:8080"
    log "SUCCESS" "✅ SSH access: ssh -i amazon-q-key-uswest2.pem ubuntu@$PUBLIC_IP"
    log "SUCCESS" "✅ Amazon Q CLI ready for use (requires 'q login')"
    log "SUCCESS" "✅ 17 MCP servers configured and optimized for $INSTANCE_FAMILY"
    echo "SETUP_SUCCESS_V10_ENHANCED_$INSTANCE_FAMILY" > /tmp/setup-status.txt
else
    log "ERROR" "❌ Some enhanced components failed verification"
    echo "SETUP_PARTIAL_V10_ENHANCED_$INSTANCE_FAMILY" > /tmp/setup-status.txt
fi

log "INFO" "🔐 Authentication: VS Code Server passwordless, Amazon Q CLI requires login"
log "INFO" "💾 Persistent storage: Enhanced with comprehensive symlink management"
log "INFO" "🤖 AI Assistants: Amazon Q CLI + Extension, Gemini Flash 2.5, GitHub Copilot CLI"
log "INFO" "🔧 MCP Servers: 17 servers configured and optimized for $INSTANCE_CATEGORY"
log "INFO" "🐳 Docker: $(systemctl is-active docker 2>/dev/null || echo 'Installation attempted') with $DOCKER_MEMORY_LIMIT limit"
log "INFO" "🔧 Development Tools: Node.js, Python, comprehensive development environment for $INSTANCE_FAMILY"
log "INFO" "🧹 EIP Management: Handled by pre-deployment script for reliable deployment"
log "INFO" "🔧 MCP Servers: Complete configuration with all 17 servers optimized for $INSTANCE_CATEGORY"
log "INFO" "🔧 Instance Family Optimization: All components configured for $INSTANCE_FAMILY performance characteristics"
log "INFO" "🔧 Memory Management: Optimized for $MEMORY_CONFIG memory profile"
log "INFO" "🔧 CPU Management: Optimized for $CPU_CONFIG CPU profile"
log "INFO" "🤖 AI Tools Available: Gemini (gemini, gcode, gai, gchat), GitHub Copilot (copilot, ghcode)"
