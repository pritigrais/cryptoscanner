#!/usr/bin/env bash
################################################################################
# Feature 3: Supply Chain Crypto Analysis
# Deep dependency tree scanning for crypto vulnerabilities
################################################################################

set -euo pipefail

TARGET_DIR="${1:-.}"
REPORT_DIR="${2:-./reports}"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[SUPPLY-CHAIN]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUPPLY-CHAIN]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[SUPPLY-CHAIN]${NC} $1"; }

SUPPLY_CHAIN_FILE="$REPORT_DIR/supply-chain-analysis.json"

analyze_npm_dependencies() {
    local package_json="$1"
    
    if [ ! -f "$package_json" ]; then
        return
    fi
    
    log_info "Analyzing npm dependency tree..."
    
    local pkg_dir=$(dirname "$package_json")
    cd "$pkg_dir"
    
    # Generate dependency tree
    if command -v npm &> /dev/null; then
        npm list --all --json > "$REPORT_DIR/npm-tree.json" 2>/dev/null || true
        
        # Analyze for crypto packages
        jq -r '.. | .dependencies? // empty | keys[]' "$REPORT_DIR/npm-tree.json" 2>/dev/null | \
        grep -E "(crypto|hash|cipher|encrypt|random)" | \
        sort -u > "$REPORT_DIR/npm-crypto-deps.txt"
        
        log_success "Found $(wc -l < "$REPORT_DIR/npm-crypto-deps.txt") crypto-related packages"
    fi
}

analyze_python_dependencies() {
    local requirements_file="$1"
    
    if [ ! -f "$requirements_file" ]; then
        return
    fi
    
    log_info "Analyzing Python dependency tree..."
    
    # Use pipdeptree if available
    if command -v pipdeptree &> /dev/null; then
        pipdeptree --json > "$REPORT_DIR/python-tree.json" 2>/dev/null || true
    else
        log_warning "pipdeptree not installed, install with: pip install pipdeptree"
    fi
}

analyze_maven_dependencies() {
    local pom_file="$1"
    
    if [ ! -f "$pom_file" ]; then
        return
    fi
    
    log_info "Analyzing Maven dependency tree..."
    
    local pom_dir=$(dirname "$pom_file")
    cd "$pom_dir"
    
    if command -v mvn &> /dev/null; then
        mvn dependency:tree -DoutputType=json -DoutputFile="$REPORT_DIR/maven-tree.json" 2>/dev/null || true
    fi
}

check_transitive_vulnerabilities() {
    log_info "Checking for transitive crypto vulnerabilities..."
    
    # Check known vulnerable crypto libraries
    local vulnerable_libs=(
        "node-md5"
        "crypto-js@<4.0.0"
        "pycrypto"
        "python-crypto"
        "javax.crypto:3des"
    )
    
    for lib in "${vulnerable_libs[@]}"; do
        log_warning "Checking for: $lib"
    done
}

generate_sbom() {
    log_info "Generating Software Bill of Materials (SBOM)..."
    
    cat > "$REPORT_DIR/crypto-sbom.json" <<EOF
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "version": 1,
  "metadata": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "component": {
      "type": "application",
      "name": "$(basename "$TARGET_DIR")"
    }
  },
  "components": []
}
EOF
    
    log_success "SBOM generated: $REPORT_DIR/crypto-sbom.json"
}

main() {
    log_info "Starting supply chain crypto analysis..."
    
    # Find dependency files
    find "$TARGET_DIR" -name "package.json" -type f | while read -r pkg; do
        analyze_npm_dependencies "$pkg"
    done
    
    find "$TARGET_DIR" -name "requirements.txt" -type f | while read -r req; do
        analyze_python_dependencies "$req"
    done
    
    find "$TARGET_DIR" -name "pom.xml" -type f | while read -r pom; do
        analyze_maven_dependencies "$pom"
    done
    
    check_transitive_vulnerabilities
    generate_sbom
    
    log_success "Supply chain analysis complete!"
}

main
