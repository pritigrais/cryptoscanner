# 🚀 Quick Start Guide

## 5-Minute Setup

### 1. Install
```bash
git clone https://github.com/yourusername/cryptoscanner-enhanced
cd cryptoscanner-enhanced
chmod +x crypto-scan-enhanced.sh scripts/*.sh
```

### 2. First Scan
```bash
# Basic scan (no AI, no cloud)
./crypto-scan-enhanced.sh /path/to/your/code
```

Output:
```
╔═══════════════════════════════════════════════════════════════════╗
║     🔐  ENHANCED CRYPTO POSTURE SCANNER v3.0.0                   ║
╚═══════════════════════════════════════════════════════════════════╝

[████████████████████████████████████████████████] 100% - Generating Report

✓ Scan completed successfully!
ℹ View reports at: ./reports
```

### 3. View Results
```bash
# HTML report (recommended)
open reports/crypto-report.html

# JSON report (for CI/CD)
cat reports/crypto-report.json | jq '.summary'
```

---

## Common Commands

### Compliance Audit
```bash
./crypto-scan-enhanced.sh --compliance pci-dss,hipaa /path/to/code
```

### AI-Powered Fix
```bash
# Set API key first
export ANTHROPIC_API_KEY="your_key_here"

# Run with auto-fix
./crypto-scan-enhanced.sh --auto-fix --generate-pr /path/to/code
```

### Git Comparison
```bash
# Compare feature branch vs main
./crypto-scan-enhanced.sh --compare origin/main..HEAD /path/to/code
```

### Cloud Scan
```bash
# Requires AWS CLI configured
./crypto-scan-enhanced.sh --cloud aws --regions us-east-1 .
```

---

## Understanding Results

### Severity Levels

| Severity | Meaning | Examples |
|----------|---------|----------|
| 🔴 CRITICAL | Immediate fix required | Hardcoded secrets, MD5 passwords |
| 🟠 HIGH | Fix within 1 week | Weak RNG, ECB mode, quantum-vulnerable |
| 🟡 MEDIUM | Fix within 1 month | Deprecated algorithms |
| 🟢 LOW | Consider fixing | MD5 for checksums |

### Crypto Health Score

- **0-30**: 🔴 Critical - Immediate action required
- **31-60**: 🟠 Poor - Major improvements needed  
- **61-80**: 🟡 Fair - Some issues to address
- **81-95**: 🟢 Good - Minor improvements
- **96-100**: ✅ Excellent - Well secured

---

## Next Steps

1. **Fix Critical Issues First**
   ```bash
   # View only critical findings
   jq '.findings[] | select(.severity == "CRITICAL")' reports/crypto-report.json
   ```

2. **Enable AI Remediation**
   - Get API key from https://console.anthropic.com
   - Set `export ANTHROPIC_API_KEY="sk-ant-..."`
   - Run with `--auto-fix`

3. **Integrate with CI/CD**
   ```yaml
   # Example GitHub Actions
   - name: Crypto Scan
     run: ./crypto-scan-enhanced.sh . || exit 1
   ```

4. **Review Migration Plan**
   ```bash
   cat reports/migration-plan.json | jq '.phases'
   ```

---

## Troubleshooting

### "Command not found: jq"
```bash
# Install jq
brew install jq  # macOS
apt-get install jq  # Ubuntu
```

### "AI remediation failed"
```bash
# Check API key
echo $ANTHROPIC_API_KEY

# Test API
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-sonnet-4-20250514","max_tokens":10,"messages":[{"role":"user","content":"Hi"}]}'
```

### Scan too slow?
```bash
# Disable AI and cloud scanning
./crypto-scan-enhanced.sh --disable-ai /path/to/code
```

---

## Getting Help

- 📖 Full docs: [README.md](README.md)
- 🐛 Report bugs: [GitHub Issues](https://github.com/yourusername/cryptoscanner-enhanced/issues)
- 💬 Questions: security@yourcompany.com
