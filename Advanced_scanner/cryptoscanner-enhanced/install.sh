#!/usr/bin/env bash
################################################################################
# Enhanced Crypto Scanner Installation Script
################################################################################

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INSTALL]${NC} $1"; }
log_success() { echo -e "${GREEN}[INSTALL]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[INSTALL]${NC} $1"; }

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║   Enhanced Crypto Posture Scanner v3.0 - Installation           ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Check dependencies
log_info "Checking dependencies..."

check_command() {
    if command -v "$1" &> /dev/null; then
        log_success "$1 found"
        return 0
    else
        log_warning "$1 not found"
        return 1
    fi
}

# Required
check_command bash || { echo "bash required"; exit 1; }
check_command jq || { echo "Install jq: apt-get install jq"; exit 1; }
check_command git || { echo "Install git"; exit 1; }

# Optional
check_command npm || log_warning "npm not found (optional for npm scanning)"
check_command pip || log_warning "pip not found (optional for Python scanning)"
check_command mvn || log_warning "maven not found (optional for Java scanning)"
check_command docker || log_warning "docker not found (optional for container scanning)"

# Make scripts executable
log_info "Making scripts executable..."
chmod +x crypto-scan-enhanced.sh
chmod +x scripts/*.sh 2>/dev/null || true

# Create necessary directories
log_info "Creating directories..."
mkdir -p reports .cache config templates docs

# Install optional Python packages
if command -v pip &> /dev/null; then
    log_info "Installing optional Python packages..."
    pip install --break-system-packages pipdeptree 2>/dev/null || \
        log_warning "Could not install pipdeptree"
fi

# Test installation
log_info "Testing installation..."
if [ -f "demo/vulnerable-app/auth.py" ]; then
    log_info "Running test scan on demo app..."
    ./crypto-scan-enhanced.sh demo/vulnerable-app --disable-ai 2>/dev/null && \
        log_success "Test scan completed!" || \
        log_warning "Test scan had warnings (this is expected for demo)"
fi

echo ""
log_success "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Run your first scan:"
echo "     ./crypto-scan-enhanced.sh /path/to/your/code"
echo ""
echo "  2. Enable AI remediation (optional):"
echo "     export ANTHROPIC_API_KEY=\"your_key_here\""
echo "     ./crypto-scan-enhanced.sh --auto-fix /path/to/code"
echo ""
echo "  3. View quick start guide:"
echo "     cat QUICKSTART.md"
echo ""
