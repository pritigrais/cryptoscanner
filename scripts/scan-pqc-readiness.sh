#!/bin/bash
# PQC Readiness Scanner
# Analyzes post-quantum cryptography adoption and quantum vulnerability

set -e

SCAN_PATH="${1:-.}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Initialize counters
pqc_libs_found=0
quantum_vulnerable=0
hybrid_implementations=0
total_crypto_usage=0

# Output JSON structure
output_json() {
    # Clean up trailing commas
    local clean_pqc_libs=$(echo "$pqc_libs_json" | sed 's/,$//')
    local clean_quantum_vuln=$(echo "$quantum_vuln_json" | sed 's/,$//')
    local clean_hybrid=$(echo "$hybrid_json" | sed 's/,$//')
    local clean_recs=$(echo "$recommendations_json" | sed 's/,$//')
    
    cat << EOF
{
  "scan_id": "$TIMESTAMP",
  "scan_path": "$SCAN_PATH",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "pqc_readiness": {
    "pqc_libraries_detected": $pqc_libs_found,
    "quantum_vulnerable_algorithms": $quantum_vulnerable,
    "hybrid_implementations": $hybrid_implementations,
    "total_crypto_usage": $total_crypto_usage,
    "readiness_level": "$readiness_level",
    "quantum_risk_score": $quantum_risk_score,
    "crypto_agility_score": $crypto_agility_score,
    "crypto_agility_issues": "$crypto_agility_issues"
  },
  "pqc_libraries": [${clean_pqc_libs}],
  "quantum_vulnerable": [${clean_quantum_vuln}],
  "hybrid_crypto": [${clean_hybrid}],
  "recommendations": [${clean_recs}],
  "pqc_algorithm_comparison": $(echo "$pqc_performance_json" | jq -c '.pqc_algorithms'),
  "quantum_threat_timeline": $(echo "$quantum_timeline_json" | jq -c '.quantum_threat_timeline'),
  "harvest_now_decrypt_later": $(echo "$quantum_timeline_json" | jq -c '.harvest_now_decrypt_later'),
  "migration_roadmap": $(echo "$migration_roadmap_json" | jq -c '.migration_roadmap'),
  "compliance_requirements": $(echo "$migration_roadmap_json" | jq -c '.compliance_requirements'),
  "priority_actions": $(echo "$migration_roadmap_json" | jq -c '.priority_actions')
}
EOF
}

# Check for PQC libraries in Python
check_python_pqc() {
    local findings=""
    
    # Check requirements.txt
    if find "$SCAN_PATH" -name "requirements.txt" -type f 2>/dev/null | grep -q .; then
        while IFS= read -r req_file; do
            if grep -iE "liboqs|pqcrypto|kyber|dilithium|sphincs|falcon" "$req_file" 2>/dev/null; then
                pqc_libs_found=$((pqc_libs_found + 1))
                findings="$findings{\"file\":\"$req_file\",\"type\":\"python_requirements\",\"status\":\"PQC_DETECTED\"},"
            fi
        done < <(find "$SCAN_PATH" -name "requirements.txt" -type f 2>/dev/null)
    fi
    
    # Check Python imports
    if find "$SCAN_PATH" -name "*.py" -type f 2>/dev/null | grep -q .; then
        while IFS= read -r py_file; do
            if grep -E "^import (liboqs|pqcrypto)|^from (liboqs|pqcrypto)" "$py_file" 2>/dev/null; then
                pqc_libs_found=$((pqc_libs_found + 1))
                findings="$findings{\"file\":\"$py_file\",\"type\":\"python_import\",\"status\":\"PQC_DETECTED\"},"
            fi
        done < <(find "$SCAN_PATH" -name "*.py" -type f 2>/dev/null)
    fi
    
    echo "$findings"
}

# Check for PQC libraries in JavaScript/Node.js
check_javascript_pqc() {
    local findings=""
    
    # Check package.json
    if find "$SCAN_PATH" -name "package.json" -type f 2>/dev/null | grep -q .; then
        while IFS= read -r pkg_file; do
            if grep -iE "pqc-kyber|@stablelib/kyber|liboqs|post-quantum" "$pkg_file" 2>/dev/null; then
                pqc_libs_found=$((pqc_libs_found + 1))
                findings="$findings{\"file\":\"$pkg_file\",\"type\":\"npm_package\",\"status\":\"PQC_DETECTED\"},"
            fi
        done < <(find "$SCAN_PATH" -name "package.json" -type f 2>/dev/null)
    fi
    
    # Check JavaScript imports
    if find "$SCAN_PATH" -name "*.js" -type f 2>/dev/null | grep -q .; then
        while IFS= read -r js_file; do
            if grep -E "require.*pqc|import.*kyber|import.*dilithium" "$js_file" 2>/dev/null; then
                pqc_libs_found=$((pqc_libs_found + 1))
                findings="$findings{\"file\":\"$js_file\",\"type\":\"javascript_import\",\"status\":\"PQC_DETECTED\"},"
            fi
        done < <(find "$SCAN_PATH" -name "*.js" -type f 2>/dev/null)
    fi
    
    echo "$findings"
}

# Check for PQC libraries in Java
check_java_pqc() {
    local findings=""
    
    # Check pom.xml
    if find "$SCAN_PATH" -name "pom.xml" -type f 2>/dev/null | grep -q .; then
        while IFS= read -r pom_file; do
            if grep -iE "bouncycastle.*pqc|org.bouncycastle.pqc" "$pom_file" 2>/dev/null; then
                pqc_libs_found=$((pqc_libs_found + 1))
                findings="$findings{\"file\":\"$pom_file\",\"type\":\"maven_dependency\",\"status\":\"PQC_DETECTED\"},"
            fi
        done < <(find "$SCAN_PATH" -name "pom.xml" -type f 2>/dev/null)
    fi
    
    # Check Java imports
    if find "$SCAN_PATH" -name "*.java" -type f 2>/dev/null | grep -q .; then
        while IFS= read -r java_file; do
            if grep -E "import org.bouncycastle.pqc" "$java_file" 2>/dev/null; then
                pqc_libs_found=$((pqc_libs_found + 1))
                findings="$findings{\"file\":\"$java_file\",\"type\":\"java_import\",\"status\":\"PQC_DETECTED\"},"
            fi
        done < <(find "$SCAN_PATH" -name "*.java" -type f 2>/dev/null)
    fi
    
    echo "$findings"
}

# Detect quantum-vulnerable algorithms
detect_quantum_vulnerable() {
    local findings=""
    local file_list=$(find "$SCAN_PATH" -type f \( -name "*.py" -o -name "*.js" -o -name "*.java" -o -name "*.go" \) 2>/dev/null)
    
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        
        # Count RSA usage
        local rsa_count=$(grep -c -E "\bRSA\b" "$file" 2>/dev/null || echo 0)
        rsa_count=$(echo "$rsa_count" | tr -d '\n\r' | xargs)
        if [ "$rsa_count" -gt 0 ] 2>/dev/null; then
            quantum_vulnerable=$((quantum_vulnerable + rsa_count))
            total_crypto_usage=$((total_crypto_usage + rsa_count))
            findings="$findings{\"file\":\"$file\",\"algorithm\":\"RSA\",\"count\":$rsa_count,\"risk\":\"HIGH\"},"
        fi
        
        # Count ECDSA/ECC usage
        local ecc_count=$(grep -c -E "\bECDSA\b|\bECC\b|\bECDH\b" "$file" 2>/dev/null || echo 0)
        ecc_count=$(echo "$ecc_count" | tr -d '\n\r' | xargs)
        if [ "$ecc_count" -gt 0 ] 2>/dev/null; then
            quantum_vulnerable=$((quantum_vulnerable + ecc_count))
            total_crypto_usage=$((total_crypto_usage + ecc_count))
            findings="$findings{\"file\":\"$file\",\"algorithm\":\"ECC/ECDSA\",\"count\":$ecc_count,\"risk\":\"HIGH\"},"
        fi
        
        # Count DH usage
        local dh_count=$(grep -c -E "\bDH\b|Diffie-Hellman" "$file" 2>/dev/null || echo 0)
        dh_count=$(echo "$dh_count" | tr -d '\n\r' | xargs)
        if [ "$dh_count" -gt 0 ] 2>/dev/null; then
            quantum_vulnerable=$((quantum_vulnerable + dh_count))
            total_crypto_usage=$((total_crypto_usage + dh_count))
            findings="$findings{\"file\":\"$file\",\"algorithm\":\"Diffie-Hellman\",\"count\":$dh_count,\"risk\":\"HIGH\"},"
        fi
    done <<< "$file_list"
    
    echo "$findings"
}

# Detect hybrid implementations
detect_hybrid_crypto() {
    local findings=""
    local file_list=$(find "$SCAN_PATH" -type f \( -name "*.py" -o -name "*.js" -o -name "*.java" \) 2>/dev/null)
    
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        
        # Look for hybrid patterns
        if grep -qE "hybrid.*crypto|classical.*quantum|RSA.*Kyber|ECDSA.*Dilithium" "$file" 2>/dev/null; then
            hybrid_implementations=$((hybrid_implementations + 1))
            findings="$findings{\"file\":\"$file\",\"type\":\"hybrid_implementation\",\"status\":\"RECOMMENDED\"},"
        fi
    done <<< "$file_list"
    
    echo "$findings"
}

# Calculate readiness level
calculate_readiness() {
    if [ $pqc_libs_found -gt 0 ] && [ $hybrid_implementations -gt 0 ]; then
        echo "HYBRID_READY"
    elif [ $pqc_libs_found -gt 0 ]; then
        echo "PQC_PARTIAL"
    elif [ $quantum_vulnerable -eq 0 ]; then
        echo "NEUTRAL"
    elif [ $total_crypto_usage -gt 0 ]; then
        local risk_percent=$((quantum_vulnerable * 100 / total_crypto_usage))
        if [ $risk_percent -gt 75 ]; then
            echo "HIGH_RISK"
        elif [ $risk_percent -gt 50 ]; then
            echo "MODERATE_RISK"
        else
            echo "LOW_RISK"
        fi
    else
        echo "UNKNOWN"
    fi
}

# Assess crypto-agility (how easy to swap algorithms)
assess_crypto_agility() {
    local agility_score=100
    local issues=""
    
    # Check for hardcoded algorithm names
    local hardcoded=$(find "$SCAN_PATH" -type f \( -name "*.py" -o -name "*.js" -o -name "*.java" \) -exec grep -l "algorithm.*=.*['\"]RSA['\"]\\|algorithm.*=.*['\"]AES['\"]\\|algorithm.*=.*['\"]SHA" {} \; 2>/dev/null | wc -l | xargs)
    if [ "$hardcoded" -gt 0 ]; then
        agility_score=$((agility_score - 30))
        issues="${issues}Hardcoded algorithms found ($hardcoded files); "
    fi
    
    # Check for crypto abstraction layers
    local has_abstraction=$(find "$SCAN_PATH" -type f \( -name "*crypto*config*" -o -name "*cipher*factory*" -o -name "*crypto*provider*" \) 2>/dev/null | wc -l | xargs)
    if [ "$has_abstraction" -eq 0 ]; then
        agility_score=$((agility_score - 25))
        issues="${issues}No crypto abstraction layer detected; "
    fi
    
    # Check for configuration-driven crypto
    local has_config=$(find "$SCAN_PATH" -type f \( -name "*crypto*.json" -o -name "*crypto*.yaml" -o -name "*crypto*.conf" \) 2>/dev/null | wc -l | xargs)
    if [ "$has_config" -eq 0 ]; then
        agility_score=$((agility_score - 20))
        issues="${issues}No crypto configuration files; "
    fi
    
    # Check for direct crypto library calls (bad for agility)
    local direct_calls=$(find "$SCAN_PATH" -type f \( -name "*.py" -o -name "*.js" \) -exec grep -l "from Crypto\\|require('crypto')\\|import hashlib" {} \; 2>/dev/null | wc -l | xargs)
    if [ "$direct_calls" -gt 5 ]; then
        agility_score=$((agility_score - 15))
        issues="${issues}Many direct crypto library calls ($direct_calls files); "
    fi
    
    # Ensure score is between 0-100
    if [ $agility_score -lt 0 ]; then
        agility_score=0
    fi
    
    echo "$agility_score|$issues"
}

# Generate PQC algorithm performance comparison
generate_pqc_performance_table() {
    cat << 'EOF'
{
  "pqc_algorithms": {
    "kyber_512": {
      "security_level": "128-bit quantum security (NIST Level 1)",
      "key_size": "800 bytes public, 1632 bytes private",
      "ciphertext_size": "768 bytes",
      "performance": "Very Fast (10,000+ ops/sec)",
      "use_case": "IoT, mobile, resource-constrained devices",
      "nist_status": "FIPS 203 (ML-KEM-512)"
    },
    "kyber_768": {
      "security_level": "192-bit quantum security (NIST Level 3)",
      "key_size": "1184 bytes public, 2400 bytes private",
      "ciphertext_size": "1088 bytes",
      "performance": "Fast (8,000+ ops/sec)",
      "use_case": "General purpose, recommended for most applications",
      "nist_status": "FIPS 203 (ML-KEM-768)"
    },
    "kyber_1024": {
      "security_level": "256-bit quantum security (NIST Level 5)",
      "key_size": "1568 bytes public, 3168 bytes private",
      "ciphertext_size": "1568 bytes",
      "performance": "Fast (6,000+ ops/sec)",
      "use_case": "High security, long-term data protection (10+ years)",
      "nist_status": "FIPS 203 (ML-KEM-1024)"
    },
    "dilithium_2": {
      "security_level": "128-bit quantum security (NIST Level 2)",
      "key_size": "1312 bytes public, 2528 bytes private",
      "signature_size": "2420 bytes",
      "performance": "Moderate (2,000 sign/sec, 5,000 verify/sec)",
      "use_case": "Code signing, certificates, general signatures",
      "nist_status": "FIPS 204 (ML-DSA-44)"
    },
    "dilithium_3": {
      "security_level": "192-bit quantum security (NIST Level 3)",
      "key_size": "1952 bytes public, 4000 bytes private",
      "signature_size": "3293 bytes",
      "performance": "Moderate (1,500 sign/sec, 4,000 verify/sec)",
      "use_case": "Recommended for most signature applications",
      "nist_status": "FIPS 204 (ML-DSA-65)"
    },
    "dilithium_5": {
      "security_level": "256-bit quantum security (NIST Level 5)",
      "key_size": "2592 bytes public, 4864 bytes private",
      "signature_size": "4595 bytes",
      "performance": "Moderate (1,000 sign/sec, 3,000 verify/sec)",
      "use_case": "Maximum security, government/military applications",
      "nist_status": "FIPS 204 (ML-DSA-87)"
    },
    "sphincs_plus": {
      "security_level": "128-256 bit quantum security",
      "key_size": "32-64 bytes public, 64-128 bytes private",
      "signature_size": "7856-49856 bytes (large!)",
      "performance": "Slow signing (10-100 sign/sec), Fast verify (1,000+ verify/sec)",
      "use_case": "Stateless signatures, firmware signing, long-term verification",
      "nist_status": "FIPS 205 (SLH-DSA)"
    },
    "falcon": {
      "security_level": "128-256 bit quantum security",
      "key_size": "897-1793 bytes public, 1281-2305 bytes private",
      "signature_size": "666-1280 bytes (compact!)",
      "performance": "Fast (1,000+ sign/sec, 2,000+ verify/sec)",
      "use_case": "Compact signatures, TLS certificates, constrained bandwidth",
      "nist_status": "NIST Round 3 Finalist (not yet standardized)"
    }
  },
  "comparison_notes": {
    "vs_rsa_2048": "RSA-2048: 256 bytes public key, 2048 bytes signature, ~500 sign/sec, ~10,000 verify/sec",
    "vs_ecdsa_p256": "ECDSA P-256: 64 bytes public key, 64 bytes signature, ~5,000 sign/sec, ~2,000 verify/sec",
    "migration_impact": "PQC algorithms are 2-10x larger and 2-5x slower than classical algorithms. Plan for increased bandwidth and storage."
  }
}
EOF
}

# Generate quantum threat timeline
generate_quantum_timeline() {
    cat << 'EOF'
{
  "quantum_threat_timeline": {
    "2024": {
      "status": "Harvest Now, Decrypt Later attacks ongoing",
      "threat_level": "HIGH for long-term data",
      "action": "Begin PQC migration planning and inventory",
      "quantum_capability": "50-100 qubits (not cryptographically relevant)"
    },
    "2025": {
      "status": "CNSA 2.0 migration deadline begins",
      "threat_level": "HIGH",
      "action": "Start hybrid crypto implementation for critical systems",
      "quantum_capability": "100-200 qubits, improved error correction"
    },
    "2027": {
      "status": "Critical systems should be PQC-protected",
      "threat_level": "CRITICAL for unprotected long-term data",
      "action": "Complete hybrid deployment, begin full PQC migration",
      "quantum_capability": "500-1000 qubits, early cryptanalytic capability"
    },
    "2030": {
      "status": "CNSA 2.0 full compliance deadline",
      "threat_level": "CRITICAL",
      "action": "All systems must use quantum-resistant algorithms",
      "quantum_capability": "1000-2000 qubits, RSA-1024 breakable"
    },
    "2033": {
      "status": "Quantum computers approaching cryptanalytic capability",
      "threat_level": "SEVERE",
      "action": "Classical algorithms deprecated, PQC-only",
      "quantum_capability": "5000+ qubits, RSA-2048 at risk"
    },
    "2035": {
      "status": "Quantum computers can break RSA-2048/ECC-256",
      "threat_level": "CATASTROPHIC for classical crypto",
      "action": "Classical crypto completely insecure",
      "quantum_capability": "10,000+ qubits, full Shor's algorithm capability"
    }
  },
  "harvest_now_decrypt_later": {
    "description": "Adversaries are collecting encrypted data NOW to decrypt with future quantum computers",
    "at_risk": [
      "Medical records (50-100 year retention)",
      "Financial records (7-10 year retention)",
      "State secrets (25+ year classification)",
      "Personal data (GDPR 'right to be forgotten' doesn't apply to stolen data)",
      "Intellectual property (patent lifetime 20 years)"
    ],
    "urgency": "Data encrypted today with RSA/ECC will be decryptable by 2035. Start PQC migration NOW for data with 10+ year lifetime."
  }
}
EOF
}

# Generate migration roadmap
generate_migration_roadmap() {
    local readiness_level=$1
    local quantum_risk=$2
    
    cat << EOF
{
  "migration_roadmap": {
    "current_state": {
      "readiness_level": "$readiness_level",
      "quantum_risk_score": $quantum_risk,
      "assessment_date": "$(date -u +%Y-%m-%d)"
    },
    "phase_1_inventory": {
      "timeline": "2024 Q1-Q2 (3-6 months)",
      "status": "COMPLETED",
      "tasks": [
        "✅ Identify all cryptographic usage",
        "✅ Assess quantum vulnerability",
        "✅ Prioritize critical systems",
        "✅ Calculate crypto-agility score"
      ],
      "deliverables": "Crypto inventory, risk assessment, migration priority list"
    },
    "phase_2_planning": {
      "timeline": "2024 Q3-Q4 (6 months)",
      "status": "IN_PROGRESS",
      "tasks": [
        "Select PQC algorithms (Kyber, Dilithium, SPHINCS+)",
        "Design hybrid crypto architecture",
        "Update security policies and standards",
        "Train development teams on PQC",
        "Establish testing and validation procedures"
      ],
      "deliverables": "PQC architecture design, updated policies, training materials"
    },
    "phase_3_hybrid_implementation": {
      "timeline": "2025-2027 (24 months)",
      "status": "PLANNED",
      "tasks": [
        "Implement hybrid crypto (classical + PQC)",
        "Deploy to critical systems first (long-term data)",
        "Gradual rollout to all systems",
        "Maintain backward compatibility",
        "Monitor performance impact"
      ],
      "deliverables": "Hybrid crypto deployment, performance metrics, compatibility testing"
    },
    "phase_4_full_pqc_migration": {
      "timeline": "2027-2030 (36 months)",
      "status": "PLANNED",
      "tasks": [
        "Transition from hybrid to PQC-only",
        "Deprecate classical algorithms",
        "Update all certificates and keys",
        "Complete CNSA 2.0 compliance",
        "Final security audits"
      ],
      "deliverables": "Full PQC deployment, CNSA 2.0 compliance certification"
    },
    "phase_5_maintenance": {
      "timeline": "2030+ (ongoing)",
      "status": "PLANNED",
      "tasks": [
        "Monitor NIST PQC standards updates",
        "Regular security assessments",
        "Algorithm agility maintenance",
        "Respond to new quantum threats",
        "Continuous improvement"
      ],
      "deliverables": "Ongoing security posture, compliance maintenance"
    }
  },
  "priority_actions": {
    "immediate": [
      "Protect long-term data (10+ year retention) with PQC NOW",
      "Implement hybrid crypto for critical systems",
      "Stop using RSA-1024 and RSA-2048 for new deployments"
    ],
    "short_term": [
      "Deploy Kyber-768 for key exchange",
      "Deploy Dilithium-3 for signatures",
      "Update TLS to support hybrid ciphersuites"
    ],
    "long_term": [
      "Complete CNSA 2.0 compliance by 2030",
      "Deprecate all classical algorithms",
      "Maintain crypto-agility for future algorithm changes"
    ]
  },
  "compliance_requirements": {
    "cnsa_2_0": {
      "deadline": "2030",
      "requirement": "All NSS systems must use quantum-resistant algorithms",
      "applies_to": "Government, defense, critical infrastructure"
    },
    "nist_pqc": {
      "status": "FIPS 203/204/205 published 2024",
      "algorithms": "Kyber (ML-KEM), Dilithium (ML-DSA), SPHINCS+ (SLH-DSA)"
    },
    "industry_specific": {
      "healthcare": "HIPAA + 50-100 year data retention requires PQC",
      "finance": "PCI DSS 4.0 preparing for PQC requirements",
      "government": "CNSA 2.0 mandatory for NSS by 2030"
    }
  }
}
EOF
}

# Calculate quantum risk score (0-100)
calculate_risk_score() {
    if [ $total_crypto_usage -eq 0 ]; then
        echo 0
        return
    fi
    
    local base_risk=$((quantum_vulnerable * 100 / total_crypto_usage))
    
    # Adjust for PQC adoption
    if [ $pqc_libs_found -gt 0 ]; then
        base_risk=$((base_risk - 20))
    fi
    
    # Adjust for hybrid implementations
    if [ $hybrid_implementations -gt 0 ]; then
        base_risk=$((base_risk - 15))
    fi
    
    # Ensure score is between 0-100
    if [ $base_risk -lt 0 ]; then
        echo 0
    elif [ $base_risk -gt 100 ]; then
        echo 100
    else
        echo $base_risk
    fi
}

# Generate recommendations
generate_recommendations() {
    local recs=""
    
    if [ $quantum_vulnerable -gt 0 ] && [ $pqc_libs_found -eq 0 ]; then
        recs="$recs{\"priority\":\"HIGH\",\"action\":\"Adopt PQC libraries (liboqs, Bouncy Castle PQC)\",\"timeline\":\"Immediate\"},"
    fi
    
    if [ $quantum_vulnerable -gt 5 ] && [ $hybrid_implementations -eq 0 ]; then
        recs="$recs{\"priority\":\"HIGH\",\"action\":\"Implement hybrid classical+PQC schemes\",\"timeline\":\"Q1 2026\"},"
    fi
    
    if [ $pqc_libs_found -eq 0 ]; then
        recs="$recs{\"priority\":\"MEDIUM\",\"action\":\"Evaluate NIST-approved PQC algorithms (Kyber, Dilithium, SPHINCS+)\",\"timeline\":\"Q2 2026\"},"
    fi
    
    if [ $quantum_vulnerable -gt 0 ]; then
        recs="$recs{\"priority\":\"MEDIUM\",\"action\":\"Plan migration roadmap for quantum-vulnerable algorithms\",\"timeline\":\"2026-2030\"},"
    fi
    
    recs="$recs{\"priority\":\"LOW\",\"action\":\"Implement crypto agility for future algorithm transitions\",\"timeline\":\"Ongoing\"},"
    
    echo "$recs"
}

# Main execution
echo "🔍 Scanning for PQC readiness..." >&2

# Collect data
pqc_libs_json=$(check_python_pqc)$(check_javascript_pqc)$(check_java_pqc)
quantum_vuln_json=$(detect_quantum_vulnerable)
hybrid_json=$(detect_hybrid_crypto)

# Calculate metrics
readiness_level=$(calculate_readiness)
quantum_risk_score=$(calculate_risk_score)
recommendations_json=$(generate_recommendations)

# NEW: Assess crypto-agility
agility_result=$(assess_crypto_agility)
crypto_agility_score=$(echo "$agility_result" | cut -d'|' -f1)
crypto_agility_issues=$(echo "$agility_result" | cut -d'|' -f2)

# NEW: Generate enhanced reports
pqc_performance_json=$(generate_pqc_performance_table)
quantum_timeline_json=$(generate_quantum_timeline)
migration_roadmap_json=$(generate_migration_roadmap "$readiness_level" "$quantum_risk_score")

echo "" >&2
echo "📊 PQC Readiness Summary:" >&2
echo "  • PQC Libraries: $pqc_libs_found" >&2
echo "  • Quantum-Vulnerable: $quantum_vulnerable" >&2
echo "  • Hybrid Implementations: $hybrid_implementations" >&2
echo "  • Readiness Level: $readiness_level" >&2
echo "  • Quantum Risk Score: $quantum_risk_score/100" >&2
echo "  • Crypto-Agility Score: $crypto_agility_score/100" >&2

# Output results
output_json

# Summary to stderr
echo "" >&2
echo "📊 PQC Readiness Summary:" >&2
echo "  • PQC Libraries: $pqc_libs_found" >&2
echo "  • Quantum-Vulnerable: $quantum_vulnerable" >&2
echo "  • Hybrid Implementations: $hybrid_implementations" >&2
echo "  • Readiness Level: $readiness_level" >&2
echo "  • Quantum Risk Score: $quantum_risk_score/100" >&2
echo "" >&2