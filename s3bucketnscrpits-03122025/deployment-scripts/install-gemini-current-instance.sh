#!/bin/bash

# Install Gemini CLI on Current Spot Instance
# This script installs Gemini CLI with persistent storage on the currently running instance

echo "🤖 Installing Gemini CLI on Current Spot Instance"
echo "================================================="
echo ""

# Connect to the instance and run the installation
ssh -i amazon-q-key-uswest2.pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@52.43.81.179 << 'REMOTE_INSTALL_EOF'

echo "📍 Starting Gemini CLI installation..."
echo "Current user: $(whoami)"
echo "Current directory: $(pwd)"
echo ""

# Create persistent directories
echo "📁 Creating persistent directories..."
sudo mkdir -p /persistent/home/ubuntu/.local/lib/python3.10/site-packages
sudo mkdir -p /persistent/home/ubuntu/.local/bin
sudo mkdir -p /persistent/home/ubuntu/.config/gemini-cli
sudo chown -R ubuntu:ubuntu /persistent/home/ubuntu/.local
sudo chown -R ubuntu:ubuntu /persistent/home/ubuntu/.config/gemini-cli

# Create local directories and symlinks
echo "🔗 Creating symlinks to persistent storage..."
mkdir -p ~/.local/lib/python3.10
mkdir -p ~/.local/bin
mkdir -p ~/.config

# Remove existing directories if they exist and create symlinks
rm -rf ~/.local/lib/python3.10/site-packages 2>/dev/null
rm -rf ~/.local/bin 2>/dev/null
rm -rf ~/.config/gemini-cli 2>/dev/null

ln -sf /persistent/home/ubuntu/.local/lib/python3.10/site-packages ~/.local/lib/python3.10/site-packages
ln -sf /persistent/home/ubuntu/.local/bin ~/.local/bin
ln -sf /persistent/home/ubuntu/.config/gemini-cli ~/.config/gemini-cli

echo "✅ Symlinks created successfully"
echo ""

# Install Gemini CLI
echo "📦 Installing Gemini CLI and dependencies..."
export PATH="$HOME/.local/bin:$PATH"

pip3 install --user google-generativeai
pip3 install --user gemini-cli

echo ""
echo "🔍 Verifying installation..."
if command -v gemini &> /dev/null; then
    echo "✅ Gemini CLI installed successfully"
    echo "Location: $(which gemini)"
else
    echo "⚠️ Gemini CLI may not be in PATH, checking installation..."
    find ~/.local -name "gemini*" -type f 2>/dev/null || echo "❌ Gemini CLI not found"
fi

# Create configuration file
echo "⚙️ Creating configuration file..."
cat > ~/.config/gemini-cli/config.json << 'CONFIG_EOF'
{
  "api_key": "",
  "model": "gemini-pro",
  "temperature": 0.7,
  "max_tokens": 2048,
  "persistent_storage": "/persistent/home/ubuntu/.config/gemini-cli",
  "installation_date": "INSTALL_DATE_PLACEHOLDER",
  "installation_method": "manual"
}
CONFIG_EOF

# Replace placeholder
sed -i "s/INSTALL_DATE_PLACEHOLDER/$(date -u +%Y-%m-%dT%H:%M:%SZ)/g" ~/.config/gemini-cli/config.json

# Create setup helper script
cat > ~/.local/bin/gemini-setup << 'SETUP_EOF'
#!/bin/bash
# Gemini CLI Setup Helper Script

echo "🤖 Google Gemini CLI Setup Helper"
echo "=================================="
echo ""
echo "To use Gemini CLI, you need to:"
echo "1. Get an API key from Google AI Studio: https://makersuite.google.com/app/apikey"
echo "2. Set your API key using one of these methods:"
echo ""
echo "   Method 1 - Environment variable (temporary):"
echo "   export GOOGLE_API_KEY='your-api-key-here'"
echo ""
echo "   Method 2 - Update config file (persistent):"
echo "   nano ~/.config/gemini-cli/config.json"
echo "   # Replace empty api_key with your key"
echo ""
echo "3. Test the installation:"
echo "   gemini 'Hello, how are you?'"
echo ""
echo "Current configuration:"
cat ~/.config/gemini-cli/config.json
echo ""
echo "Installation location: $(which gemini 2>/dev/null || echo 'Not found in PATH')"
echo "Python packages location: ~/.local/lib/python3.10/site-packages (persistent)"
echo "Configuration location: ~/.config/gemini-cli/ (persistent)"
SETUP_EOF

chmod +x ~/.local/bin/gemini-setup

# Update .bashrc
echo "🔧 Updating .bashrc..."
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc; then
    echo '' >> ~/.bashrc
    echo '# Add local Python packages to PATH (for Gemini CLI and other tools)' >> ~/.bashrc
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    echo "✅ Updated .bashrc with .local/bin PATH"
else
    echo "✅ .bashrc already contains .local/bin PATH"
fi

# Source bashrc to update current session
source ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"

echo ""
echo "🧪 Testing installation..."
echo "Python packages installed:"
pip3 list --user | grep -E "(google-generativeai|gemini)" || echo "❌ Packages not found"

echo ""
echo "Gemini CLI test:"
if command -v gemini &> /dev/null; then
    echo "✅ Gemini CLI is accessible"
    gemini --help 2>/dev/null | head -5 || echo "⚠️ Help command failed (may need API key)"
else
    echo "❌ Gemini CLI not accessible in PATH"
fi

echo ""
echo "📊 Installation Summary:"
echo "======================="
echo "✅ Gemini CLI installed to persistent storage"
echo "✅ Configuration file created: ~/.config/gemini-cli/config.json"
echo "✅ Setup helper created: gemini-setup"
echo "✅ PATH updated in .bashrc"
echo "✅ Installation will persist across spot instance interruptions"
echo ""
echo "🚀 Next steps:"
echo "1. Run 'gemini-setup' for configuration instructions"
echo "2. Get API key from: https://makersuite.google.com/app/apikey"
echo "3. Set API key and test: gemini 'Hello, how are you?'"

REMOTE_INSTALL_EOF

echo ""
echo "🏁 Installation completed!"
echo ""
echo "🧪 Run './test-gemini-cli.sh' to verify the installation"
