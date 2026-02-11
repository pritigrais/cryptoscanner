#!/bin/bash
# JIRA Ticket Creator for Crypto Vulnerabilities
# Automatically creates JIRA tickets from scan results

set -e

# Configuration
REPORT_FILE="${1:-reports/crypto-report.json}"
PATTERNS_FILE="${2}"
JIRA_URL="${JIRA_URL:-https://jira.company.com}"
JIRA_PROJECT="${JIRA_PROJECT:-SEC}"
JIRA_USER="${JIRA_USER}"
JIRA_TOKEN="${JIRA_TOKEN}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   🎫  JIRA TICKET CREATOR                                ║
║   Crypto Vulnerability Tracking Automation               ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Validate configuration
if [ -z "$JIRA_USER" ] || [ -z "$JIRA_TOKEN" ]; then
    echo -e "${RED}❌ Error: JIRA credentials not configured${NC}"
    echo ""
    echo "Setup Instructions:"
    echo "1. Generate JIRA API token: https://id.atlassian.com/manage-profile/security/api-tokens"
    echo "2. Set environment variables:"
    echo ""
    echo "   export JIRA_USER='your.email@company.com'"
    echo "   export JIRA_TOKEN='your-jira-api-token'"
    echo "   export JIRA_URL='https://your-company.atlassian.net'"
    echo "   export JIRA_PROJECT='SEC'"
    echo ""
    exit 1
fi

if [ ! -f "$REPORT_FILE" ]; then
    echo -e "${RED}❌ Error: Report file not found: $REPORT_FILE${NC}"
    echo "Run a scan first: ./crypto-scan.sh /path/to/code"
    exit 1
fi

# Get scan metadata
SCAN_ID=$(jq -r '.scan_metadata.report_id' "$REPORT_FILE" 2>/dev/null || echo "unknown")
TIMESTAMP=$(jq -r '.scan_metadata.timestamp' "$REPORT_FILE" 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)

# Get summary
CRITICAL=$(jq -r '.summary.critical' "$REPORT_FILE" 2>/dev/null || echo 0)
HIGH=$(jq -r '.summary.high' "$REPORT_FILE" 2>/dev/null || echo 0)
MEDIUM=$(jq -r '.summary.medium' "$REPORT_FILE" 2>/dev/null || echo 0)
LOW=$(jq -r '.summary.low' "$REPORT_FILE" 2>/dev/null || echo 0)
TOTAL=$(jq -r '.summary.total_issues' "$REPORT_FILE" 2>/dev/null || echo 0)

echo ""
echo "Scan Summary:"
echo "  Scan ID: $SCAN_ID"
echo "  Timestamp: $TIMESTAMP"
echo "  Total Issues: $TOTAL"
echo "  Critical: $CRITICAL | High: $HIGH | Medium: $MEDIUM | Low: $LOW"
echo ""

if [ $TOTAL -eq 0 ]; then
    echo -e "${GREEN}✅ No vulnerabilities found. No tickets to create.${NC}"
    exit 0
fi

# Find patterns file if not provided
if [ -z "$PATTERNS_FILE" ] || [ ! -f "$PATTERNS_FILE" ]; then
    PATTERNS_FILE=$(ls -t reports/patterns_*.json 2>/dev/null | head -1)
    if [ -z "$PATTERNS_FILE" ] || [ ! -f "$PATTERNS_FILE" ]; then
        echo -e "${RED}❌ Error: Patterns file not found${NC}"
        exit 1
    fi
fi

echo "Using patterns file: $PATTERNS_FILE"
echo ""

# Ask for confirmation
read -p "Create JIRA tickets for these findings? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Creating JIRA tickets..."
echo "========================"

# Create Python script for JIRA integration
python3 - "$PATTERNS_FILE" "$SCAN_ID" "$JIRA_URL" "$JIRA_PROJECT" "$JIRA_USER" "$JIRA_TOKEN" << 'PYTHON_SCRIPT'
import json
import sys
import requests
from requests.auth import HTTPBasicAuth
from datetime import datetime

# Get arguments
patterns_file = sys.argv[1]
scan_id = sys.argv[2]
jira_url = sys.argv[3]
jira_project = sys.argv[4]
jira_user = sys.argv[5]
jira_token = sys.argv[6]

# Load findings
try:
    with open(patterns_file, 'r') as f:
        data = json.load(f)
        findings = data.get('findings', [])
except Exception as e:
    print(f"❌ Error loading findings: {e}")
    sys.exit(1)

if not findings:
    print("✅ No findings to process")
    sys.exit(0)

# JIRA configuration
api_url = f"{jira_url}/rest/api/2/issue"
auth = HTTPBasicAuth(jira_user, jira_token)
headers = {"Content-Type": "application/json"}

# Severity mappings
priority_map = {
    'critical': 'Highest',
    'high': 'High',
    'medium': 'Medium',
    'low': 'Low'
}

# Group findings by type
grouped = {}
for finding in findings:
    sev = finding.get('severity', 'unknown')
    msg = finding.get('message', 'Unknown')
    key = f"{sev}_{msg}"
    
    if key not in grouped:
        grouped[key] = {
            'severity': sev,
            'message': msg,
            'cwe': finding.get('cwe', 'N/A'),
            'pattern': finding.get('pattern', ''),
            'occurrences': []
        }
    
    grouped[key]['occurrences'].append({
        'file': finding.get('file', ''),
        'line': finding.get('line', 0),
        'code': finding.get('code', '')
    })

print(f"\n📊 Grouped {len(findings)} findings into {len(grouped)} unique issues\n")

created = []
failed = []

# Create tickets
for idx, (key, issue) in enumerate(grouped.items(), 1):
    sev = issue['severity']
    msg = issue['message']
    cwe = issue['cwe']
    pattern = issue['pattern']
    occs = issue['occurrences']
    
    # Build description
    desc = f"""h2. 🔐 Crypto Security Vulnerability

*Scan ID:* {scan_id}
*Severity:* {sev.upper()}
*CWE:* [{cwe}|https://cwe.mitre.org/data/definitions/{cwe.replace('CWE-', '')}.html]
*Pattern:* {{code}}{pattern}{{code}}

h3. Description
{msg}

h3. Affected Locations ({len(occs)} occurrence(s))

"""
    
    # Add locations (max 10)
    for i, occ in enumerate(occs[:10], 1):
        desc += f"""*Location {i}:*
* File: {{code}}{occ['file']}{{code}}
* Line: {occ['line']}
* Code: {{code}}{occ['code'][:150]}...{{code}}

"""
    
    if len(occs) > 10:
        desc += f"\n_... and {len(occs) - 10} more. See full report._\n"
    
    # Add remediation
    desc += "\nh3. 🔧 Remediation\n\n"
    
    if 'MD5' in msg or 'SHA1' in msg:
        desc += """*Replace with secure hashing:*
{{code:python}}
# ❌ Insecure
hashlib.md5(password.encode()).hexdigest()

# ✅ Secure
import bcrypt
bcrypt.hashpw(password.encode(), bcrypt.gensalt())
{{code}}
"""
    elif 'Hardcoded' in msg:
        desc += """*Move to environment variables:*
{{code:python}}
# ❌ Insecure
API_KEY = "sk_live_12345"

# ✅ Secure
import os
API_KEY = os.getenv('API_KEY')
{{code}}

*Action Required:*
# Move secrets to environment variables
# Add to .gitignore
# Rotate compromised secrets
"""
    elif 'random' in msg.lower():
        desc += """*Use cryptographically secure random:*
{{code:python}}
# ❌ Insecure
import random
token = str(random.random())

# ✅ Secure
import secrets
token = secrets.token_hex(32)
{{code}}
"""
    elif 'ECB' in msg:
        desc += """*Use authenticated encryption:*
{{code:python}}
# ❌ Insecure (ECB mode)
cipher = AES.new(key, AES.MODE_ECB)

# ✅ Secure (GCM mode)
cipher = AES.new(key, AES.MODE_GCM)
ciphertext, tag = cipher.encrypt_and_digest(data)
{{code}}
"""
    else:
        desc += f"See REMEDIATION_GUIDE.md for detailed fix instructions.\n"
    
    desc += f"""
h3. 📚 References
* [OWASP Crypto Storage|https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html]
* [CWE-{cwe.replace('CWE-', '')}|https://cwe.mitre.org/data/definitions/{cwe.replace('CWE-', '')}.html]

---
_Auto-generated by Crypto Posture Scanner_
"""
    
    # Create ticket
    ticket = {
        "fields": {
            "project": {"key": jira_project},
            "summary": f"[Crypto-{sev.upper()}] {msg} ({len(occs)} occurrence(s))",
            "description": desc,
            "issuetype": {"name": "Bug"},
            "priority": {"name": priority_map.get(sev, 'Medium')},
            "labels": [
                "crypto-vulnerability",
                "security",
                f"crypto-{sev}",
                f"scan-{scan_id}",
                "auto-generated"
            ]
        }
    }
    
    try:
        resp = requests.post(api_url, auth=auth, headers=headers, json=ticket, timeout=30)
        
        if resp.status_code == 201:
            ticket_key = resp.json().get('key')
            ticket_url = f"{jira_url}/browse/{ticket_key}"
            created.append({'key': ticket_key, 'url': ticket_url, 'severity': sev, 'message': msg})
            print(f"✅ [{idx}/{len(grouped)}] {ticket_key}: {msg[:50]}...")
        else:
            error = resp.json().get('errors', resp.text)
            failed.append({'severity': sev, 'message': msg, 'error': str(error)})
            print(f"❌ [{idx}/{len(grouped)}] Failed: {msg[:50]}...")
            print(f"   Error: {error}")
    
    except Exception as e:
        failed.append({'severity': sev, 'message': msg, 'error': str(e)})
        print(f"❌ [{idx}/{len(grouped)}] Error: {msg[:50]}...")
        print(f"   {e}")

# Summary
print("\n" + "="*60)
print("JIRA TICKET CREATION SUMMARY")
print("="*60)
print(f"✅ Created: {len(created)} tickets")
print(f"❌ Failed: {len(failed)} tickets")
print("")

if created:
    print("Created Tickets:")
    for t in created:
        print(f"  • {t['key']}: {t['message']}")
        print(f"    {t['url']}")
    print("")

if failed:
    print("Failed Tickets:")
    for t in failed:
        print(f"  • [{t['severity']}] {t['message']}")
        print(f"    {t['error']}")
    print("")

# Save summary
summary_file = f"reports/jira-tickets-{scan_id}.json"
with open(summary_file, 'w') as f:
    json.dump({
        'scan_id': scan_id,
        'timestamp': datetime.now().isoformat(),
        'created': created,
        'failed': failed,
        'summary': {
            'total_issues': len(grouped),
            'tickets_created': len(created),
            'tickets_failed': len(failed)
        }
    }, f, indent=2)

print(f"📄 Summary saved: {summary_file}")
print("")

sys.exit(0 if len(failed) == 0 else 1)
PYTHON_SCRIPT

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ JIRA ticket creation completed successfully!${NC}"
else
    echo -e "${YELLOW}⚠️  JIRA ticket creation completed with some failures${NC}"
fi

echo ""
echo "Next Steps:"
echo "1. Review tickets in JIRA: $JIRA_URL/projects/$JIRA_PROJECT"
echo "2. Assign tickets to developers"
echo "3. Track remediation progress"
echo "4. Re-scan after fixes"

exit $EXIT_CODE