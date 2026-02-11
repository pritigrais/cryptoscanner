#!/bin/bash
# Crypto Posture Scanner - Main Orchestrator
# Comprehensive cryptographic security analysis for IBM SPS pipelines

set -e

VERSION="1.0.0"
SCAN_PATH="${1:-.}"
REPORT_DIR="reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
echo -e "${PURPLE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   🔐  CRYPTO POSTURE SCANNER v1.0.0                      ║
║   End-to-End Cryptographic Security Analysis             ║
║   IBM Secure Pipelines Service Integration               ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check dependencies
echo -e "${CYAN}🔧 Checking dependencies...${NC}"
MISSING_DEPS=()

if ! command -v jq &> /dev/null; then
    MISSING_DEPS+=("jq")
fi

if ! command -v grep &> /dev/null; then
    MISSING_DEPS+=("grep")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "${RED}❌ Missing required dependencies: ${MISSING_DEPS[*]}${NC}"
    echo -e "${YELLOW}Please install missing dependencies and try again.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All dependencies satisfied${NC}"
echo ""

# Validate scan path
if [ ! -d "$SCAN_PATH" ]; then
    echo -e "${RED}❌ Error: Scan path does not exist: $SCAN_PATH${NC}"
    exit 1
fi

echo -e "${BLUE}📂 Scan Target:${NC} $(cd "$SCAN_PATH" && pwd)"
echo -e "${BLUE}📅 Timestamp:${NC} $(date)"
echo -e "${BLUE}🆔 Scan ID:${NC} $TIMESTAMP"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""

# Create report directory
mkdir -p "$REPORT_DIR"

# Phase 1: Pattern Scanning
echo -e "${CYAN}🔍 Phase 1: Scanning for cryptographic patterns...${NC}"
echo "───────────────────────────────────────────────────────────"
if ./scripts/scan-patterns.sh "$SCAN_PATH" > "$REPORT_DIR/patterns_$TIMESTAMP.json"; then
    echo -e "${GREEN}✅ Pattern scan completed${NC}"
else
    echo -e "${YELLOW}⚠️  Pattern scan completed with warnings${NC}"
fi
echo ""

# Phase 2: Dependency Scanning
echo -e "${CYAN}📦 Phase 2: Analyzing cryptographic dependencies...${NC}"
echo "───────────────────────────────────────────────────────────"
if ./scripts/scan-dependencies.sh "$SCAN_PATH" > "$REPORT_DIR/deps_$TIMESTAMP.json"; then
    echo -e "${GREEN}✅ Dependency scan completed${NC}"
else
    echo -e "${YELLOW}⚠️  Dependency scan completed with warnings${NC}"
fi
echo ""

# Phase 3: PQC Readiness Assessment
echo -e "${CYAN}🔮 Phase 3: Assessing Post-Quantum Cryptography readiness...${NC}"
echo "───────────────────────────────────────────────────────────"
if ./scripts/scan-pqc-readiness.sh "$SCAN_PATH" > "$REPORT_DIR/pqc_$TIMESTAMP.json"; then
    echo -e "${GREEN}✅ PQC readiness scan completed${NC}"
else
    echo -e "${YELLOW}⚠️  PQC readiness scan completed with warnings${NC}"
fi
echo ""

# Phase 4: Context-Aware Analysis
echo -e "${CYAN}🧠 Phase 4: Performing context-aware analysis...${NC}"
echo "───────────────────────────────────────────────────────────"
if ./scripts/context-analyzer.sh "$REPORT_DIR/patterns_$TIMESTAMP.json" "$REPORT_DIR/context_$TIMESTAMP.json"; then
    echo -e "${GREEN}✅ Context analysis completed${NC}"
else
    echo -e "${YELLOW}⚠️  Context analysis completed with warnings${NC}"
fi
echo ""

# Phase 5: Report Generation
echo -e "${CYAN}📊 Phase 5: Generating comprehensive reports...${NC}"
echo "───────────────────────────────────────────────────────────"
if ./scripts/generate-report.sh "$REPORT_DIR" "$TIMESTAMP"; then
    echo -e "${GREEN}✅ Report generation completed${NC}"
else
    echo -e "${RED}❌ Report generation failed${NC}"
    exit 1
fi
echo ""

# Parse results
JSON_REPORT="$REPORT_DIR/crypto-report.json"

if [ ! -f "$JSON_REPORT" ]; then
    echo -e "${RED}❌ Error: Report file not found${NC}"
    exit 1
fi

TOTAL=$(jq -r '.summary.total_issues' "$JSON_REPORT")
CRITICAL=$(jq -r '.summary.critical' "$JSON_REPORT")
HIGH=$(jq -r '.summary.high' "$JSON_REPORT")
MEDIUM=$(jq -r '.summary.medium' "$JSON_REPORT")
LOW=$(jq -r '.summary.low' "$JSON_REPORT")
RISK_SCORE=$(jq -r '.risk_score' "$JSON_REPORT")
COMPLIANCE=$(jq -r '.compliance_status' "$JSON_REPORT")

# Parse PQC results
PQC_REPORT="$REPORT_DIR/pqc_$TIMESTAMP.json"
if [ -f "$PQC_REPORT" ]; then
    PQC_READINESS=$(jq -r '.pqc_readiness.readiness_level' "$PQC_REPORT" 2>/dev/null || echo "UNKNOWN")
    PQC_RISK=$(jq -r '.pqc_readiness.quantum_risk_score' "$PQC_REPORT" 2>/dev/null || echo "0")
    PQC_LIBS=$(jq -r '.pqc_readiness.pqc_libraries_detected' "$PQC_REPORT" 2>/dev/null || echo "0")
    QUANTUM_VULN=$(jq -r '.pqc_readiness.quantum_vulnerable_algorithms' "$PQC_REPORT" 2>/dev/null || echo "0")
else
    PQC_READINESS="UNKNOWN"
    PQC_RISK="0"
    PQC_LIBS="0"
    QUANTUM_VULN="0"
fi

# Parse context analysis results
CONTEXT_REPORT="$REPORT_DIR/context_$TIMESTAMP.json"
if [ -f "$CONTEXT_REPORT" ]; then
    FALSE_POSITIVES=$(jq -r '.summary.likely_false_positives' "$CONTEXT_REPORT" 2>/dev/null || echo "0")
    SEVERITY_ADJUSTED=$(jq -r '.summary.severity_adjusted' "$CONTEXT_REPORT" 2>/dev/null || echo "0")
    FP_RATE=$(jq -r '.summary.false_positive_rate' "$CONTEXT_REPORT" 2>/dev/null || echo "0")
else
    FALSE_POSITIVES="0"
    SEVERITY_ADJUSTED="0"
    FP_RATE="0"
fi

# Display summary
echo "═══════════════════════════════════════════════════════════"
echo -e "${PURPLE}                    SCAN SUMMARY                          ${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo -e "${BLUE}Total Issues Found:${NC} $TOTAL"
echo -e "${RED}  • Critical:${NC} $CRITICAL"
echo -e "${YELLOW}  • High:${NC} $HIGH"
echo -e "${CYAN}  • Medium:${NC} $MEDIUM"
echo -e "${GREEN}  • Low:${NC} $LOW"
echo ""
echo -e "${BLUE}Risk Score:${NC} $RISK_SCORE"
echo ""
echo -e "${PURPLE}🧠 Context-Aware Analysis:${NC}"
echo -e "${BLUE}  • Likely False Positives:${NC} $FALSE_POSITIVES ($FP_RATE%)"
echo -e "${BLUE}  • Severity Adjusted:${NC} $SEVERITY_ADJUSTED"
echo ""
echo -e "${PURPLE}🔮 Post-Quantum Cryptography Status:${NC}"
echo -e "${BLUE}  • Readiness Level:${NC} $PQC_READINESS"
echo -e "${BLUE}  • Quantum Risk Score:${NC} $PQC_RISK/100"
echo -e "${BLUE}  • PQC Libraries Found:${NC} $PQC_LIBS"
echo -e "${BLUE}  • Quantum-Vulnerable Algorithms:${NC} $QUANTUM_VULN"
echo ""

# Compliance status
if [ "$COMPLIANCE" = "PASS" ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}║              ✅  COMPLIANCE STATUS: PASSED                ║${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                           ║${NC}"
    echo -e "${RED}║              ❌  COMPLIANCE STATUS: FAILED                ║${NC}"
    echo -e "${RED}║                                                           ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo -e "${CYAN}📄 Reports Generated:${NC}"
echo "───────────────────────────────────────────────────────────"
echo -e "  • JSON Report: ${BLUE}$REPORT_DIR/crypto-report.json${NC}"
echo -e "  • HTML Report: ${BLUE}$REPORT_DIR/crypto-report.html${NC}"
echo -e "  • PQC Report: ${BLUE}$REPORT_DIR/pqc_$TIMESTAMP.json${NC}"
echo ""

# Recommendations
if [ $CRITICAL -gt 0 ] || [ $HIGH -gt 0 ] || [ "$PQC_READINESS" = "HIGH_RISK" ]; then
    echo -e "${YELLOW}⚠️  RECOMMENDATIONS:${NC}"
    echo "───────────────────────────────────────────────────────────"
    
    if [ $CRITICAL -gt 0 ]; then
        echo -e "${RED}  🚨 CRITICAL: Address $CRITICAL critical issue(s) immediately${NC}"
        echo "     - These represent severe security vulnerabilities"
        echo "     - Block deployment until resolved"
        echo ""
    fi
    
    if [ $HIGH -gt 0 ]; then
        echo -e "${YELLOW}  ⚠️  HIGH: Plan remediation for $HIGH high-severity issue(s)${NC}"
        echo "     - Schedule fixes within current sprint"
        echo "     - Review with security team"
        echo ""
    fi
    
    if [ "$PQC_READINESS" = "HIGH_RISK" ] || [ "$PQC_READINESS" = "MODERATE_RISK" ]; then
        echo -e "${PURPLE}  🔮 QUANTUM RISK: $QUANTUM_VULN quantum-vulnerable algorithm(s) detected${NC}"
        echo "     - Plan migration to post-quantum cryptography"
        echo "     - Consider hybrid classical+PQC implementations"
        echo "     - Timeline: 2025-2030 for full PQC adoption"
        echo ""
    fi
    
    echo -e "${CYAN}  💡 Best Practices:${NC}"
    echo "     - Use AES-256-GCM for encryption"
    echo "     - Use SHA-256 or SHA-3 for hashing"
    echo "     - Use bcrypt/scrypt/Argon2 for passwords"
    echo "     - Never hardcode secrets or keys"
    echo "     - Adopt PQC algorithms (Kyber, Dilithium, SPHINCS+)"
    echo "     - Use RSA-4096 minimum until PQC migration"
    echo ""
fi

echo "═══════════════════════════════════════════════════════════"
echo -e "${PURPLE}Scan completed at $(date)${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Exit with appropriate code
if [ "$COMPLIANCE" = "PASS" ]; then
    echo -e "${GREEN}✅ SUCCESS: No critical issues found${NC}"
    echo -e "${GREEN}Pipeline can proceed to next stage${NC}"
    exit 0
else
    echo -e "${RED}❌ FAILURE: $CRITICAL critical issue(s) found${NC}"
    echo -e "${RED}Pipeline blocked - fix critical issues before deployment${NC}"
    exit 1
fi