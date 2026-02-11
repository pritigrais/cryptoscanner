#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${2:-./reports}"

cat > "$REPORT_DIR/incident-response-playbook.md" <<'EOFPLAY'
# Crypto Incident Response Playbook

## Scenario 1: MD5 Collision Detected in Production

### Immediate Actions (0-1 hour)
1. **Isolate affected systems**
   - Take affected services offline
   - Block incoming traffic
   
2. **Assess impact**
   - How many users affected?
   - What data was compromised?
   
3. **Emergency contacts**
   - Notify CISO
   - Alert DevOps team
   - Prepare customer communication

### Short-term Response (1-24 hours)
1. **Deploy hotfix**
   - Replace MD5 with SHA256
   - Force password reset for all users
   
2. **Forensics**
   - Review access logs
   - Identify compromised accounts
   
3. **Communication**
   - Internal: Security bulletin
   - External: Customer notification (if required)

### Long-term Recovery (1-7 days)
1. **Root cause analysis**
   - Why was MD5 still in use?
   - How did it pass code review?
   
2. **Prevention**
   - Add crypto scanning to CI/CD
   - Update security guidelines
   - Training for developers

## Scenario 2: Hardcoded API Key Leaked to GitHub

### Immediate Actions
1. **Rotate compromised key** (within 5 minutes)
2. **Review audit logs** for unauthorized access
3. **Remove from git history**: `git filter-repo --path secrets.py --invert-paths`

### Prevention
1. Install git hooks: `crypto-scan --enable-secret-prevention`
2. Use secret managers: AWS Secrets Manager, HashiCorp Vault
3. Enable GitHub secret scanning

## Scenario 3: Quantum Computer Breakthrough Announced

### Immediate Actions
1. **Assess quantum vulnerability**
   - Inventory RSA/ECDSA usage
   - Identify critical systems
   
2. **Activate PQC migration plan**
   - Prioritize high-value data
   - Deploy hybrid schemes
   
3. **Emergency PQC deployment** (if attack imminent)

### Contacts
- Security Team: security@company.com
- On-call: +1-555-CRYPTO
- CISO: ciso@company.com
EOFPLAY

echo "Incident response playbook: $REPORT_DIR/incident-response-playbook.md"
