#!/usr/bin/env bash
################################################################################
# Feature 2: Crypto Drift Detection
# Tracks crypto posture changes over time and across git branches
################################################################################

set -euo pipefail

TARGET_DIR="${1:-.}"
REPORT_DIR="${2:-./reports}"
GIT_COMPARE="${3:-}"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[DRIFT-DETECTION]${NC} $1"; }
log_success() { echo -e "${GREEN}[DRIFT-DETECTION]${NC} $1"; }
log_error() { echo -e "${RED}[DRIFT-DETECTION]${NC} $1"; }

DRIFT_FILE="$REPORT_DIR/crypto-drift.json"
HISTORY_FILE="$REPORT_DIR/crypto-history.json"

check_git_repo() {
    if ! git -C "$TARGET_DIR" rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not a git repository: $TARGET_DIR"
        return 1
    fi
    return 0
}

calculate_crypto_score() {
    local findings_file="$1"
    
    if [ ! -f "$findings_file" ]; then
        echo "0"
        return
    fi
    
    local critical=$(jq '[.findings[] | select(.severity == "CRITICAL")] | length' "$findings_file" 2>/dev/null || echo 0)
    local high=$(jq '[.findings[] | select(.severity == "HIGH")] | length' "$findings_file" 2>/dev/null || echo 0)
    local medium=$(jq '[.findings[] | select(.severity == "MEDIUM")] | length' "$findings_file" 2>/dev/null || echo 0)
    local low=$(jq '[.findings[] | select(.severity == "LOW")] | length' "$findings_file" 2>/dev/null || echo 0)
    
    # Weighted scoring: lower is better
    local score=$((critical * 10 + high * 5 + medium * 2 + low * 1))
    echo "$score"
}

scan_commit() {
    local commit_hash="$1"
    local commit_dir="$2"
    
    cd "$TARGET_DIR"
    git checkout -q "$commit_hash" 2>/dev/null || return 1
    
    # Run a lightweight scan (pattern detection only)
    # This is a simplified version - integrate with your actual scanner
    local findings_file="$commit_dir/findings.json"
    
    # Simulate scan results (in production, call actual scanner)
    echo '{"findings": [], "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'", "commit": "'$commit_hash'"}' > "$findings_file"
    
    local score=$(calculate_crypto_score "$findings_file")
    echo "$score"
}

generate_historical_trend() {
    local days="${1:-30}"
    
    log_info "Generating $days-day historical trend..."
    
    if ! check_git_repo; then
        return 1
    fi
    
    cd "$TARGET_DIR"
    
    # Get commits from last N days
    local commits=$(git log --since="$days days ago" --format="%H|%ci|%s" --reverse)
    
    echo '{"history": []}' > "$HISTORY_FILE"
    
    local commit_count=0
    while IFS='|' read -r hash date message; do
        commit_count=$((commit_count + 1))
        
        # Create temp directory for this commit
        local temp_dir=$(mktemp -d)
        
        log_info "Analyzing commit $commit_count: ${hash:0:7}"
        
        local score=$(scan_commit "$hash" "$temp_dir")
        
        # Add to history
        jq ".history += [{
            \"commit\": \"$hash\",
            \"date\": \"$date\",
            \"message\": \"$message\",
            \"crypto_score\": $score,
            \"findings_file\": \"$temp_dir/findings.json\"
        }]" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp"
        mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
        
        rm -rf "$temp_dir"
    done <<< "$commits"
    
    # Return to original branch
    git checkout -q -
    
    log_success "Historical trend generated: $HISTORY_FILE"
}

compare_branches() {
    local comparison="$1"
    
    log_info "Comparing: $comparison"
    
    if ! check_git_repo; then
        return 1
    fi
    
    # Parse comparison (e.g., "origin/main..HEAD")
    local base_ref=$(echo "$comparison" | cut -d'.' -f1)
    local target_ref=$(echo "$comparison" | cut -d'.' -f4)
    [ -z "$target_ref" ] && target_ref="HEAD"
    
    cd "$TARGET_DIR"
    
    # Scan base
    local base_dir=$(mktemp -d)
    log_info "Scanning base: $base_ref"
    git checkout -q "$base_ref"
    local base_score=$(scan_commit "$(git rev-parse HEAD)" "$base_dir")
    
    # Scan target
    local target_dir=$(mktemp -d)
    log_info "Scanning target: $target_ref"
    git checkout -q "$target_ref"
    local target_score=$(scan_commit "$(git rev-parse HEAD)" "$target_dir")
    
    # Calculate drift
    local drift=$((target_score - base_score))
    local drift_percentage=0
    
    if [ $base_score -ne 0 ]; then
        drift_percentage=$(echo "scale=2; ($drift * 100) / $base_score" | bc)
    fi
    
    # Identify new issues
    local new_critical=$(jq '[.findings[] | select(.severity == "CRITICAL")] | length' "$target_dir/findings.json" 2>/dev/null || echo 0)
    local new_high=$(jq '[.findings[] | select(.severity == "HIGH")] | length' "$target_dir/findings.json" 2>/dev/null || echo 0)
    
    # Generate drift report
    cat > "$DRIFT_FILE" <<EOF
{
  "comparison": "$comparison",
  "base_ref": "$base_ref",
  "target_ref": "$target_ref",
  "base_score": $base_score,
  "target_score": $target_score,
  "drift": $drift,
  "drift_percentage": $drift_percentage,
  "status": "$([ $drift -le 0 ] && echo "IMPROVED" || echo "REGRESSED")",
  "new_issues": {
    "critical": $new_critical,
    "high": $new_high
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    
    # Return to original branch
    git checkout -q -
    
    # Generate summary
    local status_icon="✓"
    local status_color="$GREEN"
    
    if [ $drift -gt 0 ]; then
        status_icon="✗"
        status_color="$RED"
    fi
    
    cat > "$REPORT_DIR/drift-summary.txt" <<EOF
╔═══════════════════════════════════════════════════════════════╗
║              Crypto Drift Detection Report                    ║
╚═══════════════════════════════════════════════════════════════╝

Comparison: $comparison

Base ($base_ref):
  Crypto Score: $base_score

Target ($target_ref):
  Crypto Score: $target_score

Drift Analysis:
  ${status_color}${status_icon}${NC} Score Change: $drift ($drift_percentage%)
  New Critical Issues: $new_critical
  New High Issues: $new_high
  
Status: $([ $drift -le 0 ] && echo "✓ IMPROVED" || echo "✗ REGRESSED")

$(if [ $drift -gt 0 ]; then
    echo "⚠️  WARNING: Crypto posture has degraded!"
    echo "   Review new issues before merging."
else
    echo "✓ Crypto posture maintained or improved."
fi)

Detailed report: $DRIFT_FILE

EOF
    
    cat "$REPORT_DIR/drift-summary.txt"
    
    rm -rf "$base_dir" "$target_dir"
    
    # Exit with error if regressed
    [ $drift -le 0 ] && return 0 || return 1
}

generate_ascii_chart() {
    local history_file="$1"
    
    # Extract scores
    local scores=$(jq -r '.history[] | .crypto_score' "$history_file")
    local dates=$(jq -r '.history[] | .date' "$history_file")
    
    # Find min/max for scaling
    local max_score=0
    while read -r score; do
        [ $score -gt $max_score ] && max_score=$score
    done <<< "$scores"
    
    # Generate ASCII chart
    local chart_height=10
    local chart_width=60
    
    echo "Crypto Score Trend (Lower is Better):"
    echo ""
    
    local i=0
    while read -r score; do
        local bar_length=$((score * chart_width / max_score))
        [ $bar_length -eq 0 ] && bar_length=1
        
        printf "%-12s " "$(echo "$dates" | sed -n "$((i+1))p" | cut -d' ' -f1)"
        printf "%3d " "$score"
        printf "%${bar_length}s\n" | tr ' ' '█'
        
        i=$((i+1))
    done <<< "$scores"
}

send_slack_alert() {
    local drift="$1"
    local webhook_url="${SLACK_WEBHOOK_URL:-}"
    
    [ -z "$webhook_url" ] && return
    
    local color="good"
    local status="improved"
    
    if [ $drift -gt 0 ]; then
        color="danger"
        status="regressed"
    fi
    
    curl -X POST "$webhook_url" \
        -H 'Content-Type: application/json' \
        -d '{
            "attachments": [{
                "color": "'$color'",
                "title": "🔐 Crypto Posture Alert",
                "text": "Crypto posture has '$status' by '$drift' points",
                "fields": [
                    {
                        "title": "Repository",
                        "value": "'$(basename "$TARGET_DIR")'",
                        "short": true
                    },
                    {
                        "title": "Status",
                        "value": "'$status'",
                        "short": true
                    }
                ]
            }]
        }' 2>/dev/null
}

main() {
    log_info "Starting crypto drift detection..."
    
    if [ -n "$GIT_COMPARE" ]; then
        # Branch comparison mode
        compare_branches "$GIT_COMPARE"
        local result=$?
        
        # Send alert if configured
        local drift=$(jq -r '.drift' "$DRIFT_FILE" 2>/dev/null || echo 0)
        send_slack_alert "$drift"
        
        exit $result
    else
        # Historical trend mode
        generate_historical_trend 30
        generate_ascii_chart "$HISTORY_FILE" > "$REPORT_DIR/crypto-trend.txt"
        
        log_success "Drift detection complete!"
        log_info "View trend: $REPORT_DIR/crypto-trend.txt"
    fi
}

main
