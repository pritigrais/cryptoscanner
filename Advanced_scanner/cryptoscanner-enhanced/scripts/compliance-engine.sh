#!/usr/bin/env bash
# Feature 5: Compliance Mapping Engine

set -euo pipefail

TARGET_DIR="${1:-.}"
REPORT_DIR="${2:-./reports}"
STANDARDS="${3:-nist,pci-dss,hipaa}"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[COMPLIANCE]${NC} $1"; }
log_success() { echo -e "${GREEN}[COMPLIANCE]${NC} $1"; }
log_error() { echo -e "${RED}[COMPLIANCE]${NC} $1"; }

COMPLIANCE_FILE="$REPORT_DIR/compliance-report.json"

check_pci_dss() {
    log_info "Checking PCI-DSS v4.0 compliance..."
    
    local violations=()
    
    # PCI-DSS 3.4.1: Strong cryptography during transmission
    if grep -r "TLSv1.0\|TLSv1.1\|SSLv" "$TARGET_DIR" 2>/dev/null; then
        violations+=("PCI-DSS 3.4.1: Weak TLS/SSL versions detected")
    fi
    
    # PCI-DSS 3.5.1: Encryption key management
    if grep -r "hardcoded.*key\|secret.*=.*['\"]" "$TARGET_DIR" 2>/dev/null; then
        violations+=("PCI-DSS 3.5.1: Hardcoded encryption keys")
    fi
    
    # PCI-DSS 8.3.2: Password hashing
    if grep -r "md5(.*password\|sha1(.*password" "$TARGET_DIR" 2>/dev/null; then
        violations+=("PCI-DSS 8.3.2: Weak password hashing")
    fi
    
    local status="PASS"
    [ ${#violations[@]} -gt 0 ] && status="FAIL"
    
    cat >> "$COMPLIANCE_FILE" <<EOF
  "pci_dss": {
    "version": "4.0",
    "status": "$status",
    "violations": $(printf '%s\n' "${violations[@]}" | jq -R . | jq -s .),
    "requirements_checked": ["3.4.1", "3.5.1", "8.3.2"]
  },
EOF
}

check_hipaa() {
    log_info "Checking HIPAA compliance..."
    
    local violations=()
    
    # HIPAA 164.312(a)(2)(iv): Encryption of PHI
    if grep -r "DES\|3DES\|RC4" "$TARGET_DIR" 2>/dev/null; then
        violations+=("HIPAA 164.312: Weak encryption for PHI")
    fi
    
    # HIPAA 164.312(c)(1): Integrity controls
    if grep -r "md5.*checksum\|sha1.*checksum" "$TARGET_DIR" 2>/dev/null; then
        violations+=("HIPAA 164.312: Weak integrity mechanisms")
    fi
    
    local status="PASS"
    [ ${#violations[@]} -gt 0 ] && status="FAIL"
    
    cat >> "$COMPLIANCE_FILE" <<EOF
  "hipaa": {
    "status": "$status",
    "violations": $(printf '%s\n' "${violations[@]}" | jq -R . | jq -s .),
    "requirements_checked": ["164.312(a)(2)(iv)", "164.312(c)(1)"]
  },
EOF
}

check_nist() {
    log_info "Checking NIST SP 800-175B compliance..."
    
    local violations=()
    
    # NIST approved algorithms
    if grep -r "MD5\|SHA1.*password\|DES\|RC4" "$TARGET_DIR" 2>/dev/null; then
        violations+=("NIST 800-175B: Deprecated algorithms in use")
    fi
    
    # Post-quantum readiness
    if ! grep -r "Kyber\|Dilithium\|SPHINCS" "$TARGET_DIR" 2>/dev/null; then
        violations+=("NIST 800-175B: No PQC algorithms detected")
    fi
    
    local status="PASS"
    [ ${#violations[@]} -gt 0 ] && status="FAIL"
    
    cat >> "$COMPLIANCE_FILE" <<EOF
  "nist_800_175b": {
    "status": "$status",
    "violations": $(printf '%s\n' "${violations[@]}" | jq -R . | jq -s .),
    "pqc_ready": false
  },
EOF
}

check_gdpr() {
    log_info "Checking GDPR Article 32 compliance..."
    
    local violations=()
    
    # Art. 32: State of the art encryption
    if grep -r "AES-128\|RSA-1024\|RSA-2048" "$TARGET_DIR" 2>/dev/null; then
        violations+=("GDPR Art. 32: Encryption below state-of-the-art")
    fi
    
    local status="PASS"
    [ ${#violations[@]} -gt 0 ] && status="FAIL"
    
    cat >> "$COMPLIANCE_FILE" <<EOF
  "gdpr": {
    "article": "32",
    "status": "$status",
    "violations": $(printf '%s\n' "${violations[@]}" | jq -R . | jq -s .)
  },
EOF
}

check_soc2() {
    log_info "Checking SOC 2 Type II compliance..."
    
    local violations=()
    
    # CC6.1: Encryption requirements
    if grep -r "Math.random()\|random.random()" "$TARGET_DIR" 2>/dev/null; then
        violations+=("SOC 2 CC6.1: Weak random number generation")
    fi
    
    local status="PASS"
    [ ${#violations[@]} -gt 0 ] && status="FAIL"
    
    cat >> "$COMPLIANCE_FILE" <<EOF
  "soc2": {
    "type": "Type II",
    "status": "$status",
    "violations": $(printf '%s\n' "${violations[@]}" | jq -R . | jq -s .),
    "trust_services_criteria": ["CC6.1"]
  }
EOF
}

generate_compliance_report() {
    cat > "$COMPLIANCE_FILE" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "target": "$TARGET_DIR",
  "standards": $(echo "$STANDARDS" | tr ',' '\n' | jq -R . | jq -s .),
EOF
    
    IFS=',' read -ra STANDARD_ARRAY <<< "$STANDARDS"
    for standard in "${STANDARD_ARRAY[@]}"; do
        case "$standard" in
            pci-dss) check_pci_dss ;;
            hipaa) check_hipaa ;;
            nist) check_nist ;;
            gdpr) check_gdpr ;;
            soc2) check_soc2 ;;
        esac
    done
    
    echo "}" >> "$COMPLIANCE_FILE"
    
    log_success "Compliance report: $COMPLIANCE_FILE"
}

main() {
    log_info "Starting compliance mapping for: $STANDARDS"
    generate_compliance_report
    log_success "Compliance mapping complete!"
}

main
