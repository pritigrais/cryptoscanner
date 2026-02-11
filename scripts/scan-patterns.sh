#!/bin/bash
# Crypto Pattern Scanner - Production Ready
# Scans source code for cryptographic vulnerabilities and insecure patterns

set -e

SCAN_PATH="${1:-.}"
CONFIG="config/crypto-rules.json"
TEMP_DIR=$(mktemp -d)
OUTPUT_FILE="${TEMP_DIR}/patterns_output.json"
FINDINGS_FILE="${TEMP_DIR}/findings.json"

# Color codes for output (to stderr)
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# All console output goes to stderr
exec 3>&1  # Save stdout
exec 1>&2  # Redirect stdout to stderr

echo "🔍 Scanning for crypto patterns in: $SCAN_PATH"
echo "----------------------------------------"

# Initialize findings array
echo "[]" > "$FINDINGS_FILE"

# Function to escape JSON strings properly
escape_json() {
    local str="$1"
    # Use Python for reliable JSON escaping
    python3 -c "import json, sys; print(json.dumps(sys.argv[1]))" "$str" 2>/dev/null || echo "\"$str\""
}

# Function to add finding to JSON array
add_finding() {
    local severity="$1"
    local message="$2"
    local cwe="$3"
    local file="$4"
    local line="$5"
    local code="$6"
    local pattern="$7"
    local remediation="$8"
    
    # Escape all fields
    local msg_json=$(escape_json "$message")
    local file_json=$(escape_json "$file")
    local code_json=$(escape_json "$code")
    local pattern_json=$(escape_json "$pattern")
    
    # Ensure remediation is valid JSON (default to empty object if not provided)
    if [ -z "$remediation" ] || [ "$remediation" = "null" ]; then
        remediation="{}"
    fi
    
    # Create finding object with remediation using jq to ensure valid JSON
    local finding_json=$(jq -n \
        --arg sev "$severity" \
        --arg msg "$message" \
        --arg cwe "$cwe" \
        --arg file "$file" \
        --argjson line "$line" \
        --arg code "$code" \
        --arg pattern "$pattern" \
        --argjson rem "$remediation" \
        '{
            severity: $sev,
            message: $msg,
            cwe: $cwe,
            file: $file,
            line: $line,
            code: $code,
            pattern: $pattern,
            remediation: $rem
        }' 2>/dev/null)
    
    # Add to findings array using jq
    if [ -n "$finding_json" ]; then
        local temp_file="${TEMP_DIR}/temp_findings.json"
        echo "$finding_json" | jq -s ". as \$new | $(cat "$FINDINGS_FILE") + \$new" > "$temp_file" 2>/dev/null && mv "$temp_file" "$FINDINGS_FILE"
    fi
}

# Function to scan for patterns
scan_severity_level() {
    local severity=$1
    local count=0
    
    # Get patterns for this severity level
    local patterns=$(jq -r ".${severity}[]? | @json" "$CONFIG" 2>/dev/null || echo "")
    
    if [ -z "$patterns" ]; then
        return 0
    fi
    
    echo "$patterns" | while IFS= read -r rule_json; do
        if [ -z "$rule_json" ] || [ "$rule_json" = "null" ]; then
            continue
        fi
        
        pattern=$(echo "$rule_json" | jq -r '.pattern' 2>/dev/null || echo "")
        message=$(echo "$rule_json" | jq -r '.message' 2>/dev/null || echo "")
        cwe=$(echo "$rule_json" | jq -r '.cwe // "N/A"' 2>/dev/null || echo "N/A")
        remediation=$(echo "$rule_json" | jq -c '.remediation // {}' 2>/dev/null || echo "{}")
        
        if [ -z "$pattern" ] || [ "$pattern" = "null" ]; then
            continue
        fi
        
        # Search for pattern in source files
        grep -rn -E "$pattern" \
            --include="*.py" \
            --include="*.js" \
            --include="*.java" \
            --include="*.go" \
            --include="*.rb" \
            --include="*.php" \
            --include="*.cs" \
            --include="*.cpp" \
            --include="*.c" \
            --include="*.ts" \
            "$SCAN_PATH" 2>/dev/null | while IFS=: read -r file line content; do
            
            if [ -n "$file" ] && [ -n "$line" ] && [ "$line" -eq "$line" ] 2>/dev/null; then
                # Add finding with remediation
                add_finding "$severity" "$message" "$cwe" "$file" "$line" "$content" "$pattern" "$remediation"
                
                # Console output with color
                case $severity in
                    critical)
                        echo -e "${RED}[CRITICAL]${NC} $file:$line - $message"
                        ;;
                    high)
                        echo -e "${YELLOW}[HIGH]${NC} $file:$line - $message"
                        ;;
                    medium)
                        echo -e "${BLUE}[MEDIUM]${NC} $file:$line - $message"
                        ;;
                    low)
                        echo -e "${GREEN}[LOW]${NC} $file:$line - $message"
                        ;;
                esac
                
                count=$((count + 1))
            fi
        done
    done
    
    return 0
}

# Scan all severity levels
scan_severity_level "critical"
scan_severity_level "high"
scan_severity_level "medium"
scan_severity_level "low"

# Count total findings
TOTAL_FINDINGS=$(jq 'length' "$FINDINGS_FILE" 2>/dev/null || echo 0)

# Build final JSON output
cat > "$OUTPUT_FILE" << EOF
{
  "scan_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "scan_path": "$SCAN_PATH",
  "findings": $(cat "$FINDINGS_FILE"),
  "total_findings": $TOTAL_FINDINGS
}
EOF

echo "----------------------------------------"
echo "✅ Pattern scan complete: $TOTAL_FINDINGS findings"

# Output JSON to original stdout (fd 3)
cat "$OUTPUT_FILE" >&3

# Cleanup
rm -rf "$TEMP_DIR"

exit 0