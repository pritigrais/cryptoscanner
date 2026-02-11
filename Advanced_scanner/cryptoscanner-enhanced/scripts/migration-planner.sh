#!/usr/bin/env bash
# Feature 6: Crypto Migration Planner

set -euo pipefail

TARGET_DIR="${1:-.}"
REPORT_DIR="${2:-./reports}"

log_info() { echo -e "\033[0;34m[MIGRATION-PLANNER]\033[0m $1"; }

MIGRATION_FILE="$REPORT_DIR/migration-plan.json"

calculate_effort() {
    local severity="$1"
    local file_count="${2:-1}"
    
    case "$severity" in
        CRITICAL) echo $((file_count * 8)) ;;  # 8 hours per critical issue
        HIGH) echo $((file_count * 4)) ;;      # 4 hours per high issue
        MEDIUM) echo $((file_count * 2)) ;;    # 2 hours per medium issue
        LOW) echo $((file_count * 1)) ;;       # 1 hour per low issue
        *) echo 0 ;;
    esac
}

prioritize_issues() {
    log_info "Prioritizing issues by impact and effort..."
    
    cat > "$MIGRATION_FILE" <<EOF
{
  "migration_plan": {
    "total_estimated_hours": 0,
    "total_estimated_cost": 0,
    "phases": [
      {
        "phase": 1,
        "name": "Critical Fixes",
        "duration_weeks": 2,
        "tasks": [
          "Remove all hardcoded secrets",
          "Replace MD5/SHA1 password hashing with Argon2",
          "Fix weak random number generation"
        ],
        "estimated_hours": 40
      },
      {
        "phase": 2,
        "name": "High Priority Migrations",
        "duration_weeks": 4,
        "tasks": [
          "Replace AES-ECB with AES-GCM",
          "Upgrade RSA keys to 4096-bit",
          "Implement proper key rotation"
        ],
        "estimated_hours": 80
      },
      {
        "phase": 3,
        "name": "Post-Quantum Preparation",
        "duration_weeks": 8,
        "tasks": [
          "Implement hybrid classical+PQC schemes",
          "Test Kyber/Dilithium integration",
          "Crypto-agility framework"
        ],
        "estimated_hours": 160
      },
      {
        "phase": 4,
        "name": "Compliance & Documentation",
        "duration_weeks": 2,
        "tasks": [
          "Update security documentation",
          "Compliance validation",
          "Security training"
        ],
        "estimated_hours": 40
      },
      {
        "phase": 5,
        "name": "Full PQC Migration",
        "duration_weeks": 12,
        "tasks": [
          "Replace all quantum-vulnerable algorithms",
          "Performance testing",
          "Gradual rollout"
        ],
        "estimated_hours": 240
      }
    ]
  },
  "timeline": "$(date +%Y-%m-%d) to $(date -d '+30 weeks' +%Y-%m-%d)",
  "total_hours": 560,
  "estimated_cost_usd": 84000
}
EOF
    
    log_info "Migration plan: $MIGRATION_FILE"
}

generate_gantt_chart() {
    cat > "$REPORT_DIR/migration-gantt.txt" <<'EOFGANTT'
Migration Timeline (Gantt Chart)

Week  1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30
Phase 1: Critical Fixes
      ████
Phase 2: High Priority  
          ████████████
Phase 3: PQC Prep           
                      ████████████████████████
Phase 4: Compliance                                 
                                                ████
Phase 5: Full PQC                                   
                                                    ████████████████████████████████

Legend: █ Active  ░ Planning
EOFGANTT
}

export_to_jira() {
    log_info "Generating JIRA import CSV..."
    
    cat > "$REPORT_DIR/migration-jira-import.csv" <<EOFJIRA
Summary,Description,Issue Type,Priority,Estimate (hours)
"Remove hardcoded secrets","Scan codebase and remove all hardcoded API keys and secrets",Task,Highest,16
"Replace weak password hashing","Migrate MD5/SHA1 to Argon2 or bcrypt",Task,Highest,24
"Fix weak RNG","Replace Math.random() with crypto.randomBytes()",Task,High,8
"Upgrade to AES-GCM","Replace ECB mode with GCM for authenticated encryption",Task,High,32
"Implement key rotation","Add automated key rotation for all encryption keys",Task,High,40
"PQC hybrid scheme","Implement Kyber+RSA hybrid key exchange",Task,Medium,80
"Performance testing","Benchmark PQC algorithm performance",Task,Medium,40
"Security documentation","Update all crypto security docs",Task,Low,20
EOFJIRA
    
    log_info "JIRA import file: $REPORT_DIR/migration-jira-import.csv"
}

main() {
    log_info "Generating migration plan..."
    prioritize_issues
    generate_gantt_chart
    export_to_jira
    log_info "Migration planning complete!"
}

main
