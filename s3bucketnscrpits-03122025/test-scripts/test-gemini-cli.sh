#!/bin/bash

# Test script for Gemini CLI installation on spot instance
# This script verifies that Gemini CLI is properly installed with persistent storage

echo "🧪 Testing Gemini CLI Installation"
echo "=================================="
echo ""

# Test SSH connection and run verification
ssh -i amazon-q-key-uswest2.pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@44.250.94.216 << 'REMOTE_TEST_EOF'

echo "📍 Current user and location:"
whoami
pwd
echo ""

echo "🔍 Checking Python environment:"
python3 --version
pip3 --version
echo ""

echo "🔍 Checking PATH configuration:"
echo "Current PATH: $PATH"
echo ""

echo "🔍 Checking persistent storage symlinks:"
echo "Python packages symlink:"
ls -la ~/.local/lib/python3.10/site-packages 2>/dev/null || echo "❌ Python packages symlink not found"
echo "Local bin symlink:"
ls -la ~/.local/bin 2>/dev/null || echo "❌ Local bin symlink not found"
echo "Gemini config symlink:"
ls -la ~/.config/gemini-cli 2>/dev/null || echo "❌ Gemini config symlink not found"
echo ""

echo "🔍 Checking Gemini CLI installation:"
which gemini 2>/dev/null && echo "✅ Gemini CLI found in PATH" || echo "❌ Gemini CLI not found in PATH"
echo ""

echo "🔍 Checking installed Python packages:"
pip3 list --user | grep -E "(google-generativeai|gemini)" || echo "❌ Gemini packages not found"
echo ""

echo "🔍 Checking Gemini CLI configuration:"
if [ -f ~/.config/gemini-cli/config.json ]; then
    echo "✅ Configuration file exists:"
    cat ~/.config/gemini-cli/config.json
else
    echo "❌ Configuration file not found"
fi
echo ""

echo "🔍 Checking setup helper script:"
if [ -f ~/.local/bin/gemini-setup ]; then
    echo "✅ Setup helper script exists and is executable:"
    ls -la ~/.local/bin/gemini-setup
else
    echo "❌ Setup helper script not found"
fi
echo ""

echo "🔍 Checking persistent storage locations:"
echo "Persistent Python packages:"
ls -la /persistent/home/ubuntu/.local/lib/python3.10/site-packages/ 2>/dev/null | head -5 || echo "❌ Persistent Python packages directory not found"
echo ""
echo "Persistent bin directory:"
ls -la /persistent/home/ubuntu/.local/bin/ 2>/dev/null || echo "❌ Persistent bin directory not found"
echo ""
echo "Persistent config directory:"
ls -la /persistent/home/ubuntu/.config/gemini-cli/ 2>/dev/null || echo "❌ Persistent config directory not found"
echo ""

echo "🔍 Testing Gemini CLI (without API key):"
# Source bashrc to get updated PATH
source ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"

if command -v gemini &> /dev/null; then
    echo "✅ Gemini CLI is accessible"
    gemini --help 2>/dev/null | head -10 || echo "⚠️ Gemini CLI help command failed (may need API key)"
else
    echo "❌ Gemini CLI not accessible"
fi
echo ""

echo "🔍 Checking .bashrc PATH update:"
if grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc; then
    echo "✅ .bashrc updated with .local/bin PATH"
else
    echo "❌ .bashrc not updated with PATH"
fi
echo ""

echo "📊 Summary:"
echo "==========="
ISSUES=0

# Check each component
if [ ! -L ~/.local/lib/python3.10/site-packages ]; then
    echo "❌ Python packages symlink missing"
    ((ISSUES++))
fi

if [ ! -L ~/.local/bin ]; then
    echo "❌ Local bin symlink missing"
    ((ISSUES++))
fi

if [ ! -L ~/.config/gemini-cli ]; then
    echo "❌ Gemini config symlink missing"
    ((ISSUES++))
fi

if ! command -v gemini &> /dev/null; then
    echo "❌ Gemini CLI not accessible"
    ((ISSUES++))
fi

if [ ! -f ~/.config/gemini-cli/config.json ]; then
    echo "❌ Configuration file missing"
    ((ISSUES++))
fi

if [ ! -f ~/.local/bin/gemini-setup ]; then
    echo "❌ Setup helper script missing"
    ((ISSUES++))
fi

if [ $ISSUES -eq 0 ]; then
    echo "✅ All components installed correctly!"
    echo "✅ Gemini CLI is ready for use (API key required)"
    echo "✅ Installation will persist across spot instance interruptions"
    echo ""
    echo "🚀 Next steps:"
    echo "1. Run 'gemini-setup' for configuration instructions"
    echo "2. Get API key from: https://makersuite.google.com/app/apikey"
    echo "3. Set API key and test: gemini 'Hello, how are you?'"
else
    echo "❌ Found $ISSUES issues with the installation"
fi

REMOTE_TEST_EOF

echo ""
echo "🏁 Test completed!"
