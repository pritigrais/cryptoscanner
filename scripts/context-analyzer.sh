#!/bin/bash
# Context-Aware Crypto Analysis
# Reduces false positives by understanding usage context

set -e

FINDINGS_FILE="${1}"
OUTPUT_FILE="${2}"

# Analyze context of a finding
analyze_context() {
    local file="$1"
    local line_num="$2"
    local code="$3"
    local message="$4"
    local severity="$5"
    
    local context_score=0
    local context_notes=""
    local adjusted_severity="$severity"
    
    # Get surrounding lines for context (5 lines before and after)
    local start_line=$((line_num - 5))
    [ $start_line -lt 1 ] && start_line=1
    local end_line=$((line_num + 5))
    
    local context=$(sed -n "${start_line},${end_line}p" "$file" 2>/dev/null || echo "")
    local lower_context=$(echo "$context" | tr '[:upper:]' '[:lower:]')
    local lower_code=$(echo "$code" | tr '[:upper:]' '[:lower:]')
    
    # Check for comments/documentation
    if echo "$code" | grep -qE '^\s*(#|//|\*)'; then
        context_score=$((context_score - 5))
        context_notes="$context_notes; Found in comment/documentation"
        adjusted_severity="info"
    fi
    
    # Check for test code
    if echo "$lower_context" | grep -qE 'test|spec|mock|fixture|example|demo|sample'; then
        context_score=$((context_score - 3))
        context_notes="$context_notes; Test/demo code detected"
    fi
    
    # Check for MD5 in acceptable contexts
    if echo "$message" | grep -qi "md5"; then
        if echo "$lower_context" | grep -qE 'checksum|integrity|hash.*file|file.*hash|etag|content.*hash|cache.*key'; then
            context_score=$((context_score - 2))
            context_notes="$context_notes; Acceptable use: file integrity/caching"
            [ "$severity" = "critical" ] && adjusted_severity="low"
            [ "$severity" = "high" ] && adjusted_severity="medium"
        fi
    fi
    
    # Check for base64 encoding context
    if echo "$message" | grep -qi "base64"; then
        if echo "$lower_context" | grep -qE 'encode|decode|serialize|transport|header|cookie'; then
            context_score=$((context_score - 1))
            context_notes="$context_notes; Acceptable use: data encoding"
        fi
    fi
    
    # Check for HIGH RISK contexts - Long-term storage
    if echo "$lower_context" | grep -qE 'archive|backup|retention|long.term|10.year|20.year|permanent'; then
        context_score=$((context_score + 3))
        context_notes="$context_notes; HIGH RISK: Long-term data storage"
        [ "$severity" = "high" ] && adjusted_severity="critical"
    fi
    
    # Check for sensitive data
    if echo "$lower_context" | grep -qE 'password|secret|key|token|credential|ssn|credit.card|pii|phi'; then
        context_score=$((context_score + 2))
        context_notes="$context_notes; HIGH RISK: Sensitive data handling"
    fi
    
    # Check for production environment
    if echo "$lower_context" | grep -qE '\bprod\b|production|live|release'; then
        context_score=$((context_score + 2))
        context_notes="$context_notes; Production environment"
    fi
    
    # Check for authentication/authorization
    if echo "$lower_context" | grep -qE 'auth|login|signin|authenticate|authorize|session'; then
        context_score=$((context_score + 2))
        context_notes="$context_notes; Authentication/Authorization context"
    fi
    
    # Check for financial context
    if echo "$lower_context" | grep -qE 'payment|transaction|billing|invoice|bank'; then
        context_score=$((context_score + 3))
        context_notes="$context_notes; CRITICAL: Financial data"
        [ "$severity" = "high" ] && adjusted_severity="critical"
    fi
    
    # Check file path for context
    if echo "$file" | grep -qiE 'test|spec|mock|example|demo'; then
        context_score=$((context_score - 2))
        context_notes="$context_notes; Test file"
    fi
    
    if echo "$file" | grep -qiE 'prod|production|release'; then
        context_score=$((context_score + 2))
        context_notes="$context_notes; Production code"
    fi
    
    # Determine if this is a false positive
    local is_false_positive="false"
    if [ $context_score -lt -3 ]; then
        is_false_positive="likely"
    fi
    
    # Calculate risk level
    local risk_level="MEDIUM"
    if [ $context_score -ge 5 ]; then
        risk_level="CRITICAL"
    elif [ $context_score -ge 3 ]; then
        risk_level="HIGH"
    elif [ $context_score -ge 0 ]; then
        risk_level="MEDIUM"
    elif [ $context_score -ge -2 ]; then
        risk_level="LOW"
    else
        risk_level="MINIMAL"
    fi
    
    # Output JSON
    cat << EOF
{
  "file": "$file",
  "line": $line_num,
  "code": $(echo "$code" | jq -Rs .),
  "message": $(echo "$message" | jq -Rs .),
  "original_severity": "$severity",
  "adjusted_severity": "$adjusted_severity",
  "context_score": $context_score,
  "context_notes": $(echo "$context_notes" | jq -Rs .),
  "is_false_positive": "$is_false_positive",
  "risk_level": "$risk_level"
}
EOF
}

# Main processing
echo "🧠 Analyzing context for findings..." >&2

if [ ! -f "$FINDINGS_FILE" ]; then
    echo "Error: Findings file not found: $FINDINGS_FILE" >&2
    exit 1
fi

# Read findings and analyze each one
findings_count=$(jq '.findings | length' "$FINDINGS_FILE" 2>/dev/null || echo 0)

if [ "$findings_count" -eq 0 ]; then
    echo '{"context_analyzed_findings": [], "summary": {"total_analyzed": 0, "likely_false_positives": 0, "severity_adjusted": 0, "false_positive_rate": 0}}' > "$OUTPUT_FILE"
    echo "✅ Context analysis complete (no findings)" >&2
    exit 0
fi

analyzed_findings="["
false_positive_count=0
severity_adjusted_count=0

for i in $(seq 0 $((findings_count - 1))); do
    file=$(jq -r ".findings[$i].file" "$FINDINGS_FILE")
    line=$(jq -r ".findings[$i].line" "$FINDINGS_FILE")
    code=$(jq -r ".findings[$i].code" "$FINDINGS_FILE")
    message=$(jq -r ".findings[$i].message" "$FINDINGS_FILE")
    severity=$(jq -r ".findings[$i].severity" "$FINDINGS_FILE")
    
    # Analyze context
    result=$(analyze_context "$file" "$line" "$code" "$message" "$severity")
    
    # Check if false positive
    if echo "$result" | jq -e '.is_false_positive == "likely"' > /dev/null 2>&1; then
        false_positive_count=$((false_positive_count + 1))
    fi
    
    # Check if severity adjusted
    original=$(echo "$result" | jq -r '.original_severity')
    adjusted=$(echo "$result" | jq -r '.adjusted_severity')
    if [ "$original" != "$adjusted" ]; then
        severity_adjusted_count=$((severity_adjusted_count + 1))
    fi
    
    analyzed_findings="$analyzed_findings$result"
    
    if [ $i -lt $((findings_count - 1)) ]; then
        analyzed_findings="$analyzed_findings,"
    fi
done

analyzed_findings="$analyzed_findings]"

# Calculate false positive rate
if [ $findings_count -gt 0 ]; then
    fp_rate=$(awk "BEGIN {printf \"%.2f\", ($false_positive_count * 100 / $findings_count)}")
else
    fp_rate="0"
fi

# Generate output
cat > "$OUTPUT_FILE" << EOF
{
  "context_analyzed_findings": $analyzed_findings,
  "summary": {
    "total_analyzed": $findings_count,
    "likely_false_positives": $false_positive_count,
    "severity_adjusted": $severity_adjusted_count,
    "false_positive_rate": $fp_rate
  }
}
EOF

echo "✅ Context analysis complete" >&2
echo "   • Total findings: $findings_count" >&2
echo "   • Likely false positives: $false_positive_count" >&2
echo "   • Severity adjusted: $severity_adjusted_count" >&2