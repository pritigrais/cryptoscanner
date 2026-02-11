# Feature Documentation

## Feature 1: AI-Powered Remediation

### How It Works
1. Scans code for vulnerabilities
2. Sends vulnerable code + context to Claude API
3. Receives secure replacement code
4. Generates patch files
5. Optionally creates pull request

### Configuration
```json
{
  "ai_remediation": {
    "provider": "anthropic",  // or "openai", "local"
    "auto_fix": false,        // true to auto-apply
    "generate_pr": false      // true to create PR
  }
}
```

### Example Output
```json
{
  "file": "auth.py",
  "line": 15,
  "issue": "MD5 password hashing",
  "ai_remediation": {
    "explanation": "MD5 is cryptographically broken...",
    "fixed_code": "import bcrypt\npassword_hash = bcrypt.hashpw(...)",
    "security_rationale": "bcrypt is designed for password hashing..."
  }
}
```

## Feature 2: Crypto Drift Detection

### How It Works
1. Scans current branch
2. Compares with base branch (e.g., main)
3. Calculates crypto health score difference
4. Identifies new vulnerabilities
5. Sends alerts if regressed

### Usage
```bash
# Compare branches
./crypto-scan-enhanced.sh --compare origin/main..HEAD .

# Historical trend (30 days)
./crypto-scan-enhanced.sh --historical 30 .
```

### Slack Integration
```bash
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
# Scanner will auto-send alerts on regressions
```

## Feature 3: Supply Chain Analysis

### Supported Ecosystems
- npm (package.json, package-lock.json)
- pip (requirements.txt, Pipfile)
- maven (pom.xml)
- gradle (build.gradle)
- go (go.mod)

### SBOM Generation
Generates CycloneDX-compliant Software Bill of Materials listing all crypto dependencies.

## Feature 5: Compliance Mapping

### Supported Standards
1. **PCI-DSS v4.0**: Payment card data protection
2. **HIPAA**: Healthcare data encryption
3. **GDPR Article 32**: State-of-the-art encryption
4. **SOC 2 Type II**: Trust services criteria
5. **NIST SP 800-175B**: Cryptographic algorithms
6. **FedRAMP**: Federal cloud security

### Example Report
```json
{
  "pci_dss": {
    "status": "FAIL",
    "violations": [
      "PCI-DSS 3.4.1: TLS 1.0 detected",
      "PCI-DSS 8.3.2: MD5 password hashing"
    ]
  }
}
```

## Feature 9: Quantum Attack Simulator

### Timeline Projections
- **2026**: 1000+ qubit computers (current)
- **2030**: RSA-2048 theoretically breakable
- **2033**: RSA-4096 at risk
- **2035**: All classical crypto vulnerable

### "Harvest Now, Decrypt Later"
Identifies data encrypted today that will be vulnerable in 5-10 years:
- Medical records (6+ year retention)
- Financial records (7+ year retention)
- State secrets (50+ year classification)

## Feature 10: Performance Analysis

### Benchmarks Included
- MD5, SHA-256, SHA-3
- bcrypt, scrypt, Argon2
- RSA-2048, RSA-4096
- ECDSA, Ed25519
- Kyber, Dilithium (PQC)

### Migration Impact Calculator
Shows exact performance cost of switching algorithms:
```
MD5 → SHA-256: +50% CPU, +1ms latency
RSA-2048 → Kyber: -95% CPU, -9.8ms latency
```

---

For complete documentation, see README.md
