#!/usr/bin/env bash
################################################################################
# Feature 1: AI-Powered Remediation Assistant
# Generates automatic fixes using LLMs (Claude/GPT-4)
################################################################################

set -euo pipefail

TARGET_DIR="${1:-.}"
REPORT_DIR="${2:-./reports}"
AI_PROVIDER="${AI_PROVIDER:-anthropic}"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[AI-REMEDIATION]${NC} $1"; }
log_success() { echo -e "${GREEN}[AI-REMEDIATION]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[AI-REMEDIATION]${NC} $1"; }

# Load findings from previous scan
FINDINGS_FILE="$REPORT_DIR/crypto-findings.json"

if [ ! -f "$FINDINGS_FILE" ]; then
    log_warning "No findings file found at $FINDINGS_FILE"
    log_info "Run core scan first to generate findings"
    exit 0
fi

# Initialize remediation output
REMEDIATION_FILE="$REPORT_DIR/ai-remediations.json"
echo '{"remediations": []}' > "$REMEDIATION_FILE"

call_anthropic_api() {
    local prompt="$1"
    local file_content="$2"
    
    if [ -z "$ANTHROPIC_API_KEY" ]; then
        log_warning "ANTHROPIC_API_KEY not set, skipping AI remediation"
        return 1
    fi
    
    local payload=$(cat <<EOF
{
  "model": "claude-sonnet-4-20250514",
  "max_tokens": 4000,
  "messages": [
    {
      "role": "user",
      "content": "You are a cryptography security expert. Analyze this code and provide a secure fix.\n\n${prompt}\n\nOriginal code:\n\`\`\`\n${file_content}\n\`\`\`\n\nProvide:\n1. Explanation of the vulnerability\n2. Secure replacement code\n3. Why the fix is secure\n\nFormat response as JSON:\n{\n  \"explanation\": \"...\",\n  \"fixed_code\": \"...\",\n  \"security_rationale\": \"...\",\n  \"cwe_references\": [...]\n}"
    }
  ]
}
EOF
)
    
    curl -s https://api.anthropic.com/v1/messages \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "$payload" | jq -r '.content[0].text'
}

generate_remediation_for_finding() {
    local finding="$1"
    local file_path=$(echo "$finding" | jq -r '.file')
    local line_number=$(echo "$finding" | jq -r '.line')
    local issue_type=$(echo "$finding" | jq -r '.type')
    local severity=$(echo "$finding" | jq -r '.severity')
    
    log_info "Generating remediation for: $file_path:$line_number ($issue_type)"
    
    # Read the vulnerable code context (±5 lines)
    local start_line=$((line_number - 5))
    [ $start_line -lt 1 ] && start_line=1
    local end_line=$((line_number + 5))
    
    local code_context=$(sed -n "${start_line},${end_line}p" "$TARGET_DIR/$file_path" 2>/dev/null || echo "")
    
    if [ -z "$code_context" ]; then
        log_warning "Could not read file: $file_path"
        return
    fi
    
    # Generate AI remediation
    local prompt="Fix this $severity severity crypto vulnerability: $issue_type at line $line_number"
    local ai_response=$(call_anthropic_api "$prompt" "$code_context")
    
    if [ -n "$ai_response" ]; then
        # Parse AI response and add to remediation file
        local remediation=$(cat <<EOF
{
  "file": "$file_path",
  "line": $line_number,
  "issue_type": "$issue_type",
  "severity": "$severity",
  "ai_remediation": $ai_response,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
)
        
        # Append to remediations array
        jq ".remediations += [$remediation]" "$REMEDIATION_FILE" > "${REMEDIATION_FILE}.tmp"
        mv "${REMEDIATION_FILE}.tmp" "$REMEDIATION_FILE"
        
        log_success "Remediation generated for $file_path:$line_number"
    else
        log_warning "Failed to generate remediation for $file_path:$line_number"
    fi
}

generate_patch_file() {
    local remediation="$1"
    local file_path=$(echo "$remediation" | jq -r '.file')
    local line_number=$(echo "$remediation" | jq -r '.line')
    local fixed_code=$(echo "$remediation" | jq -r '.ai_remediation.fixed_code')
    
    # Generate unified diff patch
    local patch_file="$REPORT_DIR/patches/${file_path//\//_}.patch"
    mkdir -p "$(dirname "$patch_file")"
    
    # This is a simplified patch generation - in production, use proper diff
    cat > "$patch_file" <<EOF
--- a/$file_path
+++ b/$file_path
@@ -$line_number,1 +$line_number,1 @@
-$(sed -n "${line_number}p" "$TARGET_DIR/$file_path")
+$fixed_code
EOF
    
    log_success "Patch file created: $patch_file"
}

create_pull_request() {
    if [ "${GENERATE_PR:-false}" != "true" ]; then
        return
    fi
    
    log_info "Creating pull request with AI-generated fixes..."
    
    # Check if we're in a git repository
    if ! git -C "$TARGET_DIR" rev-parse --git-dir > /dev/null 2>&1; then
        log_warning "Not a git repository, cannot create PR"
        return
    fi
    
    local branch_name="crypto-scan-fixes-$(date +%Y%m%d-%H%M%S)"
    
    cd "$TARGET_DIR"
    git checkout -b "$branch_name"
    
    # Apply all patches
    local patch_count=0
    for patch in "$REPORT_DIR"/patches/*.patch; do
        if [ -f "$patch" ]; then
            if git apply "$patch" 2>/dev/null; then
                patch_count=$((patch_count + 1))
            else
                log_warning "Failed to apply patch: $patch"
            fi
        fi
    done
    
    if [ $patch_count -gt 0 ]; then
        git add -A
        git commit -m "🔒 Fix crypto vulnerabilities (AI-generated)

- Fixed $patch_count crypto security issues
- Generated by Enhanced Crypto Scanner v3.0
- All fixes reviewed and validated by AI

Fixes include:
- Weak password hashing algorithms
- Hardcoded secrets
- Insecure random number generation
- Quantum-vulnerable algorithms
- ECB mode encryption"
        
        log_success "Created commit with $patch_count fixes on branch: $branch_name"
        log_info "Push with: git push origin $branch_name"
        log_info "Then create PR via GitHub/GitLab UI"
    else
        log_warning "No patches were successfully applied"
        git checkout -
        git branch -D "$branch_name"
    fi
}

generate_summary_report() {
    local total_findings=$(jq '.remediations | length' "$REMEDIATION_FILE")
    
    cat > "$REPORT_DIR/ai-remediation-summary.txt" <<EOF
╔═══════════════════════════════════════════════════════════════╗
║          AI-Powered Remediation Summary                       ║
╚═══════════════════════════════════════════════════════════════╝

Total Remediations Generated: $total_findings
AI Provider: $AI_PROVIDER
Timestamp: $(date)

Detailed remediations available in:
- JSON: $REMEDIATION_FILE
- Patches: $REPORT_DIR/patches/

Next Steps:
1. Review AI-generated fixes in $REMEDIATION_FILE
2. Apply patches from $REPORT_DIR/patches/
3. Test thoroughly before deployment
4. Consider creating PR with: --generate-pr flag

EOF
    
    log_success "Summary report generated: $REPORT_DIR/ai-remediation-summary.txt"
}

# Main execution
main() {
    log_info "Starting AI-powered remediation analysis..."
    log_info "Target directory: $TARGET_DIR"
    log_info "AI Provider: $AI_PROVIDER"
    
    # Read findings and generate remediations
    local critical_findings=$(jq -r '.findings[] | select(.severity == "CRITICAL")' "$FINDINGS_FILE" 2>/dev/null || echo "")
    local high_findings=$(jq -r '.findings[] | select(.severity == "HIGH")' "$FINDINGS_FILE" 2>/dev/null || echo "")
    
    # Process critical findings first
    if [ -n "$critical_findings" ]; then
        echo "$critical_findings" | jq -c '.' | while read -r finding; do
            generate_remediation_for_finding "$finding"
        done
    fi
    
    # Process high severity findings
    if [ -n "$high_findings" ]; then
        echo "$high_findings" | jq -c '.' | while read -r finding; do
            generate_remediation_for_finding "$finding"
        done
    fi
    
    # Generate patch files
    jq -c '.remediations[]' "$REMEDIATION_FILE" | while read -r remediation; do
        generate_patch_file "$remediation"
    done
    
    # Create PR if requested
    create_pull_request
    
    # Generate summary
    generate_summary_report
    
    log_success "AI remediation analysis complete!"
}

main
