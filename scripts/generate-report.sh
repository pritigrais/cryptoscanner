#!/bin/bash
# Report Generator - Production Ready
# Generates comprehensive HTML and JSON reports from scan results

set -e

REPORT_DIR="${1:-reports}"
TIMESTAMP="${2:-$(date +%Y%m%d_%H%M%S)}"
PATTERNS_FILE="$REPORT_DIR/patterns_$TIMESTAMP.json"
DEPS_FILE="$REPORT_DIR/deps_$TIMESTAMP.json"
PQC_FILE="$REPORT_DIR/pqc_$TIMESTAMP.json"
CONTEXT_FILE="$REPORT_DIR/context_$TIMESTAMP.json"
JSON_REPORT="$REPORT_DIR/crypto-report.json"
HTML_REPORT="$REPORT_DIR/crypto-report.html"

echo "📊 Generating reports..."

# Initialize counters
CRITICAL=0
HIGH=0
MEDIUM=0
LOW=0
TOTAL=0
DEP_COUNT=0

# Parse pattern findings
if [ -f "$PATTERNS_FILE" ]; then
    CRITICAL=$(jq '[.findings[]? | select(.severity == "critical")] | length' "$PATTERNS_FILE" 2>/dev/null || echo "0")
    HIGH=$(jq '[.findings[]? | select(.severity == "high")] | length' "$PATTERNS_FILE" 2>/dev/null || echo "0")
    MEDIUM=$(jq '[.findings[]? | select(.severity == "medium")] | length' "$PATTERNS_FILE" 2>/dev/null || echo "0")
    LOW=$(jq '[.findings[]? | select(.severity == "low")] | length' "$PATTERNS_FILE" 2>/dev/null || echo "0")
    # Ensure numeric values
    CRITICAL=${CRITICAL:-0}
    HIGH=${HIGH:-0}
    MEDIUM=${MEDIUM:-0}
    LOW=${LOW:-0}
    TOTAL=$((CRITICAL + HIGH + MEDIUM + LOW))
fi

# Count dependencies
if [ -f "$DEPS_FILE" ]; then
    DEP_COUNT=$(jq '.total_dependencies' "$DEPS_FILE" 2>/dev/null || echo "0")
    DEP_COUNT=${DEP_COUNT:-0}
fi

# Parse PQC readiness data
PQC_READINESS="UNKNOWN"
PQC_RISK=0
PQC_LIBS=0
QUANTUM_VULN=0
HYBRID_IMPL=0
if [ -f "$PQC_FILE" ]; then
    PQC_READINESS=$(jq -r '.pqc_readiness.readiness_level' "$PQC_FILE" 2>/dev/null || echo "UNKNOWN")
    PQC_RISK=$(jq -r '.pqc_readiness.quantum_risk_score' "$PQC_FILE" 2>/dev/null || echo 0)
    PQC_LIBS=$(jq -r '.pqc_readiness.pqc_libraries_detected' "$PQC_FILE" 2>/dev/null || echo 0)
    QUANTUM_VULN=$(jq -r '.pqc_readiness.quantum_vulnerable_algorithms' "$PQC_FILE" 2>/dev/null || echo 0)
    HYBRID_IMPL=$(jq -r '.pqc_readiness.hybrid_implementations' "$PQC_FILE" 2>/dev/null || echo 0)
fi

# Parse context analysis data
CONTEXT_FP=0
CONTEXT_ADJUSTED=0
CONTEXT_FP_RATE="0"
if [ -f "$CONTEXT_FILE" ]; then
    CONTEXT_FP=$(jq -r '.summary.likely_false_positives' "$CONTEXT_FILE" 2>/dev/null || echo 0)
    CONTEXT_FP=${CONTEXT_FP:-0}
    CONTEXT_ADJUSTED=$(jq -r '.summary.severity_adjusted' "$CONTEXT_FILE" 2>/dev/null || echo 0)
    CONTEXT_ADJUSTED=${CONTEXT_ADJUSTED:-0}
    CONTEXT_FP_RATE=$(jq -r '.summary.false_positive_rate' "$CONTEXT_FILE" 2>/dev/null || echo "0")
    CONTEXT_FP_RATE=${CONTEXT_FP_RATE:-"0"}
fi

# Calculate risk score (including PQC risk)
BASE_RISK=$(( (CRITICAL * 10) + (HIGH * 5) + (MEDIUM * 2) + LOW ))
RISK_SCORE=$(( BASE_RISK + (PQC_RISK / 5) ))

# Determine compliance status
if [ "$CRITICAL" -eq 0 ] 2>/dev/null; then
    COMPLIANCE="PASS"
    STATUS_CLASS="status-pass"
    STATUS_TEXT="✅ COMPLIANCE: PASSED"
else
    COMPLIANCE="FAIL"
    STATUS_CLASS="status-fail"
    STATUS_TEXT="❌ COMPLIANCE: FAILED"
fi

# Generate JSON Report
cat > "$JSON_REPORT" << EOF
{
  "scan_metadata": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "scanner_version": "1.0.0",
    "report_id": "$TIMESTAMP"
  },
  "summary": {
    "total_issues": $TOTAL,
    "critical": $CRITICAL,
    "high": $HIGH,
    "medium": $MEDIUM,
    "low": $LOW,
    "dependencies_found": $DEP_COUNT
  },
  "pqc_readiness": {
    "readiness_level": "$PQC_READINESS",
    "quantum_risk_score": $PQC_RISK,
    "pqc_libraries_detected": $PQC_LIBS,
    "quantum_vulnerable_algorithms": $QUANTUM_VULN,
    "hybrid_implementations": $HYBRID_IMPL
  },
  "risk_score": $RISK_SCORE,
  "compliance_status": "$COMPLIANCE"
}
EOF

# Create Python script for HTML generation
cat > /tmp/generate_html_report.py << 'PYTHON_EOF'
import json
import sys
from datetime import datetime
import html

def generate_html_report(patterns_file, deps_file, pqc_file, context_file, html_file, critical, high, medium, low, total, dep_count, risk_score, status_class, status_text, compliance, pqc_readiness, pqc_risk, pqc_libs, quantum_vuln, hybrid_impl, context_fp, context_adjusted, context_fp_rate):
    # Load findings
    findings = []
    try:
        with open(patterns_file, 'r') as f:
            data = json.load(f)
            findings = data.get('findings', [])
    except Exception as e:
        print(f"Warning: Could not load findings: {e}", file=sys.stderr)

    # Load dependencies
    dependencies = {}
    try:
        with open(deps_file, 'r') as f:
            data = json.load(f)
            dependencies = data.get('dependencies', {})
    except Exception as e:
        print(f"Warning: Could not load dependencies: {e}", file=sys.stderr)
    
    # Load PQC data
    pqc_data = {}
    try:
        with open(pqc_file, 'r') as f:
            pqc_data = json.load(f)
    except Exception as e:
        print(f"Warning: Could not load PQC data: {e}", file=sys.stderr)
    
    # Load context analysis
    context_data = {}
    context_findings = {}
    try:
        with open(context_file, 'r') as f:
            context_data = json.load(f)
            # Create a lookup dict for context info by file:line
            for ctx_finding in context_data.get('context_analyzed_findings', []):
                key = f"{ctx_finding.get('file')}:{ctx_finding.get('line')}"
                context_findings[key] = ctx_finding
    except Exception as e:
        print(f"Warning: Could not load context data: {e}", file=sys.stderr)

    # Generate findings HTML
    findings_html = ""
    if findings:
        for finding in findings:
            sev = html.escape(finding.get('severity', 'unknown'))
            msg = html.escape(finding.get('message', ''))
            cwe = html.escape(finding.get('cwe', 'N/A'))
            file = html.escape(finding.get('file', ''))
            line = finding.get('line', 0)
            code = html.escape(finding.get('code', ''))
            pattern = html.escape(finding.get('pattern', ''))
            
            # Get context analysis for this finding
            ctx_key = f"{file}:{line}"
            ctx_info = context_findings.get(ctx_key, {})
            adjusted_sev = ctx_info.get('adjusted_severity', sev)
            context_score = ctx_info.get('context_score', 0)
            context_notes = ctx_info.get('context_notes', '')
            is_false_positive = ctx_info.get('is_false_positive', 'false')
            risk_level = ctx_info.get('risk_level', 'MEDIUM')
            
            # Build context badge
            context_badge = ""
            if is_false_positive == "likely":
                context_badge = '<span class="context-badge fp-badge">⚠️ Likely False Positive</span>'
            elif adjusted_sev != sev:
                context_badge = f'<span class="context-badge adjusted-badge">📊 Severity Adjusted: {sev} → {adjusted_sev}</span>'
            
            if context_notes:
                context_badge += f'<div class="context-notes">🧠 Context: {html.escape(context_notes)}</div>'
            
            remediation = finding.get('remediation', {})
            
            # Build remediation HTML if available
            remediation_html = ""
            if remediation:
                rem_title = html.escape(remediation.get('title', ''))
                rem_desc = html.escape(remediation.get('description', ''))
                fix_python = html.escape(remediation.get('fix_python', ''))
                fix_js = html.escape(remediation.get('fix_javascript', ''))
                nist_ref = html.escape(remediation.get('nist_reference', ''))
                impact = html.escape(remediation.get('impact', ''))
                
                remediation_html = f'''
                <div class="remediation-section">
                    <div class="remediation-header">
                        <strong>🔧 {rem_title}</strong>
                    </div>
                    <div class="remediation-content">
                        <p><strong>Description:</strong> {rem_desc}</p>
                        {f'<p><strong>⚠️ Impact:</strong> {impact}</p>' if impact else ''}
                        {f'<p><strong>📚 NIST Guidance:</strong> {nist_ref}</p>' if nist_ref else ''}
                        {f'<div class="fix-example"><strong>✅ Python Fix:</strong><pre>{fix_python}</pre></div>' if fix_python else ''}
                        {f'<div class="fix-example"><strong>✅ JavaScript Fix:</strong><pre>{fix_js}</pre></div>' if fix_js else ''}
                    </div>
                </div>
                '''
            
            findings_html += f'''
            <div class="finding {adjusted_sev}">
                <div class="finding-header">
                    <div class="finding-title">{msg}</div>
                    <span class="severity-badge severity-{adjusted_sev}">{adjusted_sev.upper()}</span>
                </div>
                {context_badge}
                <div class="finding-details">
                    <strong>CWE:</strong> {cwe}<br>
                    <strong>Pattern:</strong> <code>{pattern}</code><br>
                    <strong>Risk Level:</strong> <span class="risk-{risk_level.lower()}">{risk_level}</span>
                </div>
                <div class="file-location">📄 {file}:{line}</div>
                <div class="code-block">{code}</div>
                {remediation_html}
            </div>
            '''
    else:
        findings_html = '<p style="color: #28a745; font-size: 1.1em;">✅ No security issues detected!</p>'

    # Generate dependencies HTML
    deps_html = ""
    if dependencies:
        deps_html = '''
        <table class="dependency-table">
            <thead>
                <tr>
                    <th>Language</th>
                    <th>Package</th>
                    <th>Version</th>
                    <th>Risk Level</th>
                    <th>Recommendation</th>
                </tr>
            </thead>
            <tbody>
        '''
        for key, dep in dependencies.items():
            lang = html.escape(dep.get('language', ''))
            pkg = html.escape(dep.get('package', ''))
            ver = html.escape(dep.get('version', ''))
            risk = html.escape(dep.get('risk_level', ''))
            rec = html.escape(dep.get('recommendation', ''))
            deps_html += f'''
                <tr>
                    <td>{lang}</td>
                    <td>{pkg}</td>
                    <td>{ver}</td>
                    <td class="{risk.lower()}">{risk}</td>
                    <td>{rec}</td>
                </tr>
            '''
        deps_html += '</tbody></table>'
    else:
        deps_html = '<p>No cryptographic dependencies detected.</p>'

    # HTML template
    html_content = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Crypto Posture Scan Report</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 10px; color: #333; }}
        .container {{ max-width: 1200px; margin: 0 auto; background: white; border-radius: 10px; box-shadow: 0 15px 40px rgba(0,0,0,0.25); overflow: hidden; }}
        .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; text-align: center; }}
        .header h1 {{ font-size: 1.8em; margin-bottom: 6px; }}
        .header .subtitle {{ font-size: 0.9em; opacity: 0.9; }}
        
        .toolbar {{ background: #f8f9fa; padding: 12px 20px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; border-bottom: 2px solid #ddd; position: sticky; top: 0; z-index: 100; }}
        .search-box {{ padding: 8px 16px; border: 2px solid #ddd; border-radius: 20px; font-size: 0.9em; min-width: 250px; transition: all 0.3s; }}
        .search-box:focus {{ outline: none; border-color: #667eea; box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1); }}
        .btn {{ padding: 6px 14px; border: 2px solid #ddd; border-radius: 20px; background: white; color: #333; cursor: pointer; font-weight: 600; transition: all 0.3s; font-size: 0.85em; }}
        .btn:hover {{ background: #667eea; color: white; border-color: #667eea; transform: translateY(-2px); }}
        .btn.active {{ background: #667eea; color: white; border-color: #667eea; }}
        
        .summary {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; padding: 20px; background: #f8f9fa; }}
        .summary-card {{ background: white; padding: 15px; border-radius: 6px; box-shadow: 0 2px 6px rgba(0,0,0,0.08); text-align: center; transition: transform 0.2s; cursor: pointer; }}
        .summary-card:hover {{ transform: translateY(-3px); box-shadow: 0 3px 10px rgba(0,0,0,0.12); }}
        .summary-card .number {{ font-size: 2em; font-weight: bold; margin-bottom: 6px; }}
        .summary-card .label {{ font-size: 0.75em; color: #666; text-transform: uppercase; letter-spacing: 0.5px; }}
        .critical {{ color: #dc3545; }}
        .high {{ color: #fd7e14; }}
        .medium {{ color: #ffc107; }}
        .low {{ color: #28a745; }}
        .info {{ color: #17a2b8; }}
        .status-badge {{ display: inline-block; padding: 5px 15px; border-radius: 16px; font-weight: bold; font-size: 0.9em; margin-top: 6px; }}
        .status-pass {{ background: #d4edda; color: #155724; }}
        .status-fail {{ background: #f8d7da; color: #721c24; }}
        .content {{ padding: 20px; }}
        .section {{ margin-bottom: 25px; }}
        .section h2 {{ font-size: 1.4em; margin-bottom: 12px; color: #667eea; border-bottom: 2px solid #667eea; padding-bottom: 6px; }}
        .finding {{ background: #f8f9fa; border-left: 3px solid #667eea; padding: 12px; margin-bottom: 10px; border-radius: 4px; }}
        .finding.critical {{ border-left-color: #dc3545; }}
        .finding.high {{ border-left-color: #fd7e14; }}
        .finding.medium {{ border-left-color: #ffc107; }}
        .finding.low {{ border-left-color: #28a745; }}
        .finding-header {{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; }}
        .finding-title {{ font-weight: bold; font-size: 0.95em; }}
        .severity-badge {{ padding: 3px 10px; border-radius: 10px; font-size: 0.75em; font-weight: bold; text-transform: uppercase; }}
        .severity-critical {{ background: #dc3545; color: white; }}
        .severity-high {{ background: #fd7e14; color: white; }}
        .severity-medium {{ background: #ffc107; color: #333; }}
        .severity-low {{ background: #28a745; color: white; }}
        .finding-details {{ margin-top: 6px; font-size: 0.85em; color: #555; }}
        .code-block {{ background: #2d2d2d; color: #f8f8f2; padding: 10px; border-radius: 4px; overflow-x: auto; margin-top: 6px; font-family: 'Courier New', monospace; font-size: 0.8em; }}
        .file-location {{ color: #666; font-size: 0.8em; margin-top: 3px; }}
        .dependency-table {{ width: 100%; border-collapse: collapse; margin-top: 12px; }}
        .dependency-table th, .dependency-table td {{ padding: 8px; text-align: left; border-bottom: 1px solid #ddd; font-size: 0.85em; }}
        .dependency-table th {{ background: #667eea; color: white; font-weight: bold; }}
        .dependency-table tr:hover {{ background: #f8f9fa; }}
        .footer {{ background: #2d2d2d; color: white; padding: 15px; text-align: center; font-size: 0.85em; }}
        .recommendations {{ background: #e7f3ff; border-left: 3px solid #2196F3; padding: 12px; margin-top: 12px; border-radius: 4px; }}
        .recommendations h3 {{ color: #2196F3; margin-bottom: 10px; font-size: 1em; }}
        .recommendations ul {{ margin-left: 15px; }}
        .recommendations li {{ margin-bottom: 6px; line-height: 1.5; font-size: 0.85em; }}
        .remediation-section {{ background: #f0f8ff; border: 2px solid #4CAF50; border-radius: 6px; padding: 12px; margin-top: 10px; }}
        .remediation-header {{ color: #2e7d32; font-size: 0.95em; margin-bottom: 8px; display: flex; align-items: center; }}
        .remediation-content {{ color: #333; line-height: 1.5; font-size: 0.85em; }}
        .remediation-content p {{ margin: 6px 0; }}
        .fix-example {{ background: #fff; border-left: 3px solid #4CAF50; padding: 10px; margin: 6px 0; border-radius: 4px; }}
        .fix-example strong {{ color: #2e7d32; display: block; margin-bottom: 5px; font-size: 0.85em; }}
        .fix-example pre {{ background: #2d2d2d; color: #f8f8f2; padding: 8px; border-radius: 4px; overflow-x: auto; font-family: 'Courier New', monospace; font-size: 0.8em; margin: 0; }}
        .context-badge {{ display: inline-block; padding: 4px 10px; border-radius: 4px; font-size: 0.75em; font-weight: bold; margin: 6px 0; }}
        .fp-badge {{ background: #fff3cd; color: #856404; border: 1px solid #ffc107; }}
        .adjusted-badge {{ background: #d1ecf1; color: #0c5460; border: 1px solid #17a2b8; }}
        .context-notes {{ background: #f8f9fa; border-left: 2px solid #6c757d; padding: 8px; margin: 6px 0; font-size: 0.8em; color: #495057; }}
        .risk-critical {{ color: #dc3545; font-weight: bold; }}
        .risk-high {{ color: #fd7e14; font-weight: bold; }}
        .risk-medium {{ color: #ffc107; font-weight: bold; }}
        .risk-low {{ color: #28a745; font-weight: bold; }}
        .risk-minimal {{ color: #6c757d; font-weight: bold; }}
        
        .executive-summary {{ padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }}
        .executive-summary h2 {{ font-size: 1.3em; margin-bottom: 15px; color: white; text-align: center; font-weight: 800; }}
        .summary-grid {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: 15px; }}
        @media (max-width: 1200px) {{ .summary-grid {{ grid-template-columns: repeat(2, 1fr); }} }}
        @media (max-width: 768px) {{ .summary-grid {{ grid-template-columns: 1fr; }} }}
        .summary-item {{ background: white; padding: 15px 12px; border-radius: 10px; box-shadow: 0 3px 8px rgba(0,0,0,0.12); text-align: center; transition: all 0.3s; border-top: 3px solid #667eea; }}
        .summary-item:hover {{ transform: translateY(-3px); box-shadow: 0 6px 15px rgba(0,0,0,0.2); }}
        .summary-icon {{ font-size: 1.8em; line-height: 1; margin-bottom: 8px; display: block; }}
        .summary-content h3 {{ font-size: 0.65em; color: #666; margin-bottom: 6px; text-transform: uppercase; letter-spacing: 1px; font-weight: 700; }}
        .summary-value {{ font-size: 1.6em; font-weight: 900; background: linear-gradient(135deg, #667eea, #764ba2); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; margin-bottom: 6px; line-height: 1.1; }}
        .summary-desc {{ font-size: 0.7em; color: #666; line-height: 1.3; }}
        .summary-item:nth-child(3) .summary-value {{ font-size: 2em; }}
        
        .charts-section {{ padding: 20px; background: white; display: grid; grid-template-columns: repeat(2, 1fr); gap: 15px; }}
        @media (max-width: 1024px) {{ .charts-section {{ grid-template-columns: 1fr; }} }}
        .chart-container {{ background: #f8f9fa; padding: 15px; border-radius: 10px; box-shadow: 0 2px 6px rgba(0,0,0,0.08); transition: all 0.3s; }}
        .chart-container:hover {{ box-shadow: 0 3px 10px rgba(0,0,0,0.12); transform: translateY(-2px); }}
        .chart-container h3 {{ margin-bottom: 12px; color: #667eea; font-size: 1em; font-weight: 700; display: flex; align-items: center; gap: 6px; }}
        
        .action-items {{ padding: 25px 20px; background: white; }}
        .action-items h2 {{ font-size: 1.5em; margin-bottom: 20px; color: #667eea; text-align: center; }}
        .action-list {{ display: grid; gap: 15px; max-width: 1000px; margin: 0 auto; }}
        .action-card {{ background: white; padding: 18px; border-radius: 10px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); border-left: 5px solid; transition: all 0.3s; }}
        .action-card:hover {{ transform: translateX(5px); box-shadow: 0 4px 12px rgba(0,0,0,0.15); }}
        .critical-action {{ border-left-color: #dc3545; }}
        .high-action {{ border-left-color: #fd7e14; }}
        .medium-action {{ border-left-color: #ffc107; }}
        .action-header {{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }}
        .action-priority {{ padding: 4px 12px; border-radius: 16px; font-size: 0.75em; font-weight: 700; text-transform: uppercase; }}
        .critical-action .action-priority {{ background: #dc3545; color: white; }}
        .high-action .action-priority {{ background: #fd7e14; color: white; }}
        .medium-action .action-priority {{ background: #ffc107; color: #333; }}
        .action-count {{ font-weight: 700; color: #666; }}
        .action-card h3 {{ font-size: 1.1em; margin-bottom: 8px; color: #333; }}
        .action-card p {{ color: #666; line-height: 1.5; margin-bottom: 10px; font-size: 0.9em; }}
        .action-timeline {{ font-weight: 600; color: #667eea; font-size: 0.85em; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 Crypto Posture Scan Report</h1>
            <p class="subtitle">End-to-End Cryptographic Security Analysis</p>
            <p class="subtitle">Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")}</p>
        </div>
        
        <div class="toolbar">
            <div style="display: flex; gap: 10px; flex-wrap: wrap;">
                <input type="text" class="search-box" id="searchBox" placeholder="🔍 Search findings, CWE, files...">
                <button class="btn active" data-filter="all">All</button>
                <button class="btn" data-filter="critical">Critical</button>
                <button class="btn" data-filter="high">High</button>
                <button class="btn" data-filter="medium">Medium</button>
                <button class="btn" data-filter="low">Low</button>
            </div>
        </div>
        
        <div class="summary">
            <div class="summary-card" data-severity="all"><div class="number">{total}</div><div class="label">Total Issues</div></div>
            <div class="summary-card" data-severity="critical"><div class="number critical">{critical}</div><div class="label">Critical</div></div>
            <div class="summary-card" data-severity="high"><div class="number high">{high}</div><div class="label">High</div></div>
            <div class="summary-card" data-severity="medium"><div class="number medium">{medium}</div><div class="label">Medium</div></div>
            <div class="summary-card" data-severity="low"><div class="number low">{low}</div><div class="label">Low</div></div>
            <div class="summary-card" data-severity="all"><div class="number info">{dep_count}</div><div class="label">Dependencies</div></div>
        </div>
        
        <div style="text-align: center; padding: 12px; background: #f8f9fa;">
            <div class="status-badge {status_class}">{status_text}</div>
            <p style="margin-top: 6px; color: #666; font-size: 0.85em;">Risk Score: {risk_score}</p>
        </div>
        
        <div class="executive-summary">
            <h2>📋 Executive Summary</h2>
            <div class="summary-grid">
                <div class="summary-item">
                    <div class="summary-icon">🎯</div>
                    <div class="summary-content">
                        <h3>Security Posture</h3>
                        <p class="summary-value">{compliance}</p>
                        <p class="summary-desc">Overall compliance status based on critical findings</p>
                    </div>
                </div>
                <div class="summary-item">
                    <div class="summary-icon">⚠️</div>
                    <div class="summary-content">
                        <h3>Immediate Action Required</h3>
                        <p class="summary-value">{critical} Critical</p>
                        <p class="summary-desc">Must be addressed before production deployment</p>
                    </div>
                </div>
                <div class="summary-item">
                    <div class="summary-icon">📊</div>
                    <div class="summary-content">
                        <h3>Risk Score</h3>
                        <p class="summary-value">{risk_score}/100</p>
                        <p class="summary-desc">Calculated based on severity and count of issues</p>
                    </div>
                </div>
                <div class="summary-item">
                    <div class="summary-icon">⏱️</div>
                    <div class="summary-content">
                        <h3>Estimated Remediation</h3>
                        <p class="summary-value">{total * 2}-{total * 4}h</p>
                        <p class="summary-desc">Approximate time to fix all identified issues</p>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="charts-section">
            <div class="chart-container">
                <h3>📊 Severity Distribution</h3>
                <canvas id="severityChart"></canvas>
            </div>
            <div class="chart-container">
                <h3>📈 Risk Impact Analysis</h3>
                <canvas id="riskChart"></canvas>
            </div>
        </div>
        
        <div class="action-items">
            <h2>🎯 Priority Action Items</h2>
            <div class="action-list">
                <div class="action-card critical-action">
                    <div class="action-header">
                        <span class="action-priority">P0 - Critical</span>
                        <span class="action-count">{critical} issues</span>
                    </div>
                    <h3>Address Critical Vulnerabilities</h3>
                    <p>Fix all critical cryptographic issues immediately. These pose severe security risks.</p>
                    <div class="action-timeline">⏰ Timeline: Within 24 hours</div>
                </div>
                <div class="action-card high-action">
                    <div class="action-header">
                        <span class="action-priority">P1 - High</span>
                        <span class="action-count">{high} issues</span>
                    </div>
                    <h3>Remediate High-Priority Issues</h3>
                    <p>Schedule fixes for high-severity findings in current sprint.</p>
                    <div class="action-timeline">⏰ Timeline: Within 1 week</div>
                </div>
                <div class="action-card medium-action">
                    <div class="action-header">
                        <span class="action-priority">P2 - Medium</span>
                        <span class="action-count">{medium} issues</span>
                    </div>
                    <h3>Plan Medium-Priority Fixes</h3>
                    <p>Include in next release cycle planning.</p>
                    <div class="action-timeline">⏰ Timeline: Within 2-4 weeks</div>
                </div>
            </div>
        </div>
        <div style="background: #f0f4ff; padding: 15px; border-top: 2px solid #667eea;">
            <h2 style="color: #667eea; margin-bottom: 12px; text-align: center; font-size: 1.2em;">🔮 Post-Quantum Cryptography Status</h2>
            <div class="summary" style="padding: 0; gap: 10px;">
                <div class="summary-card"><div class="number" style="color: #667eea;">{pqc_readiness}</div><div class="label">Readiness Level</div></div>
                <div class="summary-card"><div class="number" style="color: #fd7e14;">{pqc_risk}/100</div><div class="label">Quantum Risk</div></div>
                <div class="summary-card"><div class="number" style="color: #28a745;">{pqc_libs}</div><div class="label">PQC Libraries</div></div>
                <div class="summary-card"><div class="number" style="color: #dc3545;">{quantum_vuln}</div><div class="label">Quantum-Vulnerable</div></div>
                <div class="summary-card"><div class="number" style="color: #17a2b8;">{hybrid_impl}</div><div class="label">Hybrid Implementations</div></div>
            </div>
        </div>
        <div style="background: #e8f5e9; padding: 15px; border-top: 2px solid #4caf50;">
            <h2 style="color: #2e7d32; margin-bottom: 12px; text-align: center; font-size: 1.2em;">🧠 Context-Aware Analysis</h2>
            <div class="summary" style="padding: 0; gap: 10px;">
                <div class="summary-card"><div class="number" style="color: #ffc107;">{context_fp}</div><div class="label">Likely False Positives</div></div>
                <div class="summary-card"><div class="number" style="color: #17a2b8;">{context_adjusted}</div><div class="label">Severity Adjusted</div></div>
                <div class="summary-card"><div class="number" style="color: #28a745;">{context_fp_rate}%</div><div class="label">False Positive Rate</div></div>
            </div>
            <p style="text-align: center; margin-top: 10px; color: #555; font-size: 0.85em; line-height: 1.4;">
                Context-aware analysis reduces false positives by understanding code usage patterns,
                test environments, and acceptable cryptographic use cases.
            </p>
        </div>
        <div style="text-align: center; padding: 12px; background: #f8f9fa;">
            <div class="status-badge {status_class}">{status_text}</div>
            <p style="margin-top: 6px; color: #666; font-size: 0.85em;">Risk Score: {risk_score}</p>
        </div>
        <div class="content">
            <div class="section">
                <h2>🔍 Detailed Findings</h2>
                {findings_html}
            </div>
            <div class="section">
                <h2>📦 Cryptographic Dependencies</h2>
                {deps_html}
            </div>
            
            <!-- PQC Detailed Analysis -->
            <div class="section" style="background: #f0f4ff; padding: 15px; border-radius: 6px; margin-top: 15px;">
                <h2 style="color: #667eea; font-size: 1.3em;">🔮 Post-Quantum Cryptography Detailed Analysis</h2>
                
                <!-- Crypto-Agility Score -->
                <div style="background: white; padding: 12px; border-radius: 6px; margin: 12px 0; border-left: 3px solid #17a2b8;">
                    <h3 style="color: #17a2b8; margin-bottom: 10px; font-size: 1.1em;">🎯 Crypto-Agility Assessment</h3>
                    <div style="display: grid; grid-template-columns: 1fr 2fr; gap: 15px; align-items: center;">
                        <div style="text-align: center;">
                            <div style="font-size: 2em; font-weight: bold; color: #17a2b8;">{pqc_data.get('pqc_readiness', {}).get('crypto_agility_score', 'N/A')}/100</div>
                            <div style="color: #666; margin-top: 6px; font-size: 0.85em;">Crypto-Agility Score</div>
                        </div>
                        <div>
                            <p style="margin-bottom: 8px; font-size: 0.85em;"><strong>What this means:</strong> This score indicates how easily your codebase can migrate to new cryptographic algorithms.</p>
                            <p style="color: #666; font-size: 0.8em;"><strong>Issues Found:</strong> {html.escape(str(pqc_data.get('pqc_readiness', {}).get('crypto_agility_issues', 'None')))}</p>
                            <div style="margin-top: 10px;">
                                <strong style="font-size: 0.85em;">Score Guide:</strong>
                                <ul style="margin-top: 4px; padding-left: 18px; line-height: 1.5; font-size: 0.8em;">
                                    <li>90-100: Excellent - Easy migration</li>
                                    <li>70-89: Good - Moderate refactoring needed</li>
                                    <li>50-69: Fair - Significant refactoring required</li>
                                    <li>0-49: Poor - Major architectural changes needed</li>
                                </ul>
                            </div>
                        </div>
                    </div>
                </div>
                
                <!-- Harvest Now, Decrypt Later Warning -->
                <div style="background: #fff3cd; padding: 12px; border-radius: 6px; margin: 12px 0; border-left: 3px solid #ffc107;">
                    <h3 style="color: #856404; margin-bottom: 10px; font-size: 1.1em;">⚠️ "Harvest Now, Decrypt Later" Threat</h3>
                    <p style="line-height: 1.5; margin-bottom: 10px; font-size: 0.85em;">
                        <strong>CRITICAL WARNING:</strong> {pqc_data.get('harvest_now_decrypt_later', {}).get('description', 'Adversaries are collecting encrypted data NOW to decrypt with future quantum computers')}
                    </p>
                    <div style="background: white; padding: 10px; border-radius: 4px; margin-top: 8px;">
                        <strong style="font-size: 0.85em;">Data at Risk:</strong>
                        <ul style="margin-top: 6px; padding-left: 18px; line-height: 1.5; font-size: 0.8em;">
                            {''.join(f'<li>{html.escape(item)}</li>' for item in pqc_data.get('harvest_now_decrypt_later', {}).get('at_risk', []))}
                        </ul>
                    </div>
                    <p style="margin-top: 10px; padding: 10px; background: #dc3545; color: white; border-radius: 4px; font-size: 0.85em;">
                        <strong>⏰ Urgency:</strong> {pqc_data.get('harvest_now_decrypt_later', {}).get('urgency', 'Start PQC migration NOW for data with 10+ year lifetime')}
                    </p>
                </div>
                
                <!-- Quantum Threat Timeline -->
                <div style="background: white; padding: 12px; border-radius: 6px; margin: 12px 0; border-left: 3px solid #dc3545;">
                    <h3 style="color: #dc3545; margin-bottom: 10px; font-size: 1.1em;">⏰ Quantum Threat Timeline (2024-2035)</h3>
                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px;">
                        {''.join(f'<div style="background: #f8f9fa; padding: 10px; border-radius: 4px;"><div style="font-size: 1.2em; font-weight: bold; color: #667eea; margin-bottom: 6px;">{year}</div><div style="margin-bottom: 5px; font-size: 0.8em;"><strong>Status:</strong> {data.get("status", "")}</div><div style="margin-bottom: 5px; font-size: 0.8em;"><strong>Threat:</strong> <span style="color: #dc3545; font-weight: bold;">{data.get("threat_level", "")}</span></div><div style="margin-bottom: 5px; font-size: 0.8em;"><strong>Action:</strong> {data.get("action", "")}</div><div style="font-size: 0.75em; color: #666;"><strong>Quantum:</strong> {data.get("quantum_capability", "")}</div></div>' for year, data in pqc_data.get('quantum_threat_timeline', {}).items() if year in ['2024', '2027', '2030', '2035'])}
                    </div>
                </div>
                
                <!-- Migration Roadmap -->
                <div style="background: white; padding: 12px; border-radius: 6px; margin: 12px 0; border-left: 3px solid #28a745;">
                    <h3 style="color: #28a745; margin-bottom: 10px; font-size: 1.1em;">🗺️ PQC Migration Roadmap</h3>
                    <div style="margin-bottom: 12px; font-size: 0.85em;">
                        <strong>Current State:</strong> Readiness Level: <span style="color: #667eea; font-weight: bold;">{pqc_data.get('migration_roadmap', {}).get('current_state', {}).get('readiness_level', 'UNKNOWN')}</span> |
                        Quantum Risk: <span style="color: #fd7e14; font-weight: bold;">{pqc_data.get('migration_roadmap', {}).get('current_state', {}).get('quantum_risk_score', 0)}/100</span>
                    </div>
                    <div style="display: grid; grid-template-columns: 1fr; gap: 10px;">
                        {''.join(f'<div style="background: #f8f9fa; padding: 10px; border-radius: 4px; border-left: 2px solid {"#28a745" if data.get("status") == "COMPLETED" else "#ffc107" if data.get("status") == "IN_PROGRESS" else "#6c757d"};"><div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;"><strong style="font-size: 0.95em;">{phase_name.replace("_", " ").title()}</strong><span style="background: {"#d4edda" if data.get("status") == "COMPLETED" else "#fff3cd" if data.get("status") == "IN_PROGRESS" else "#e2e3e5"}; padding: 3px 10px; border-radius: 10px; font-size: 0.75em; font-weight: bold;">{data.get("status", "PLANNED")}</span></div><div style="color: #666; margin-bottom: 6px; font-size: 0.8em;"><strong>Timeline:</strong> {data.get("timeline", "")}</div><div style="font-size: 0.8em;"><strong>Deliverables:</strong> {data.get("deliverables", "")}</div></div>' for phase_name, data in pqc_data.get('migration_roadmap', {}).items() if phase_name.startswith('phase_'))}
                    </div>
                </div>
                
                <!-- Priority Actions -->
                <div style="background: white; padding: 12px; border-radius: 6px; margin: 12px 0; border-left: 3px solid #fd7e14;">
                    <h3 style="color: #fd7e14; margin-bottom: 10px; font-size: 1.1em;">🚀 Priority Actions</h3>
                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 10px;">
                        <div style="background: #fff5f5; padding: 10px; border-radius: 4px;">
                            <h4 style="color: #dc3545; margin-bottom: 8px; font-size: 0.95em;">⚡ Immediate</h4>
                            <ul style="padding-left: 18px; line-height: 1.5; font-size: 0.8em;">
                                {''.join(f'<li>{html.escape(action)}</li>' for action in pqc_data.get('priority_actions', {}).get('immediate', []))}
                            </ul>
                        </div>
                        <div style="background: #fff8e1; padding: 10px; border-radius: 4px;">
                            <h4 style="color: #ffc107; margin-bottom: 8px; font-size: 0.95em;">📅 Short-term</h4>
                            <ul style="padding-left: 18px; line-height: 1.5; font-size: 0.8em;">
                                {''.join(f'<li>{html.escape(action)}</li>' for action in pqc_data.get('priority_actions', {}).get('short_term', []))}
                            </ul>
                        </div>
                        <div style="background: #e8f5e9; padding: 10px; border-radius: 4px;">
                            <h4 style="color: #28a745; margin-bottom: 8px; font-size: 0.95em;">🎯 Long-term</h4>
                            <ul style="padding-left: 18px; line-height: 1.5; font-size: 0.8em;">
                                {''.join(f'<li>{html.escape(action)}</li>' for action in pqc_data.get('priority_actions', {}).get('long_term', []))}
                            </ul>
                        </div>
                    </div>
                </div>
                
                <!-- Compliance Requirements -->
                <div style="background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #6f42c1;">
                    <h3 style="color: #6f42c1; margin-bottom: 15px;">🏛️ Compliance Requirements</h3>
                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 15px;">
                        <div style="background: #f8f9fa; padding: 15px; border-radius: 4px;">
                            <h4 style="color: #6f42c1; margin-bottom: 10px;">NSA CNSA 2.0</h4>
                            <p><strong>Deadline:</strong> {pqc_data.get('compliance_requirements', {}).get('cnsa_2_0', {}).get('deadline', '2030')}</p>
                            <p><strong>Requirement:</strong> {pqc_data.get('compliance_requirements', {}).get('cnsa_2_0', {}).get('requirement', '')}</p>
                            <p style="font-size: 0.9em; color: #666;"><strong>Applies to:</strong> {pqc_data.get('compliance_requirements', {}).get('cnsa_2_0', {}).get('applies_to', '')}</p>
                        </div>
                        <div style="background: #f8f9fa; padding: 15px; border-radius: 4px;">
                            <h4 style="color: #6f42c1; margin-bottom: 10px;">NIST PQC</h4>
                            <p><strong>Status:</strong> {pqc_data.get('compliance_requirements', {}).get('nist_pqc', {}).get('status', '')}</p>
                            <p><strong>Algorithms:</strong> {pqc_data.get('compliance_requirements', {}).get('nist_pqc', {}).get('algorithms', '')}</p>
                        </div>
                        <div style="background: #f8f9fa; padding: 15px; border-radius: 4px;">
                            <h4 style="color: #6f42c1; margin-bottom: 10px;">Industry-Specific</h4>
                            <p><strong>Healthcare:</strong> {pqc_data.get('compliance_requirements', {}).get('industry_specific', {}).get('healthcare', '')}</p>
                            <p><strong>Finance:</strong> {pqc_data.get('compliance_requirements', {}).get('industry_specific', {}).get('finance', '')}</p>
                            <p><strong>Government:</strong> {pqc_data.get('compliance_requirements', {}).get('industry_specific', {}).get('government', '')}</p>
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="recommendations">
                <h3>💡 Recommendations</h3>
                <ul>
                    <li><strong>Critical Issues:</strong> Address immediately - these represent severe security vulnerabilities</li>
                    <li><strong>High Issues:</strong> Plan remediation within current sprint</li>
                    <li><strong>Medium Issues:</strong> Schedule for next release cycle</li>
                    <li><strong>Dependencies:</strong> Keep crypto libraries updated to latest stable versions</li>
                    <li><strong>Best Practices:</strong> Use industry-standard algorithms (AES-256-GCM, SHA-256, bcrypt/Argon2)</li>
                    <li><strong>Post-Quantum Cryptography:</strong> Adopt NIST-approved PQC algorithms (Kyber, Dilithium, SPHINCS+)</li>
                    <li><strong>Quantum Migration:</strong> Use RSA-4096 minimum until full PQC migration (2025-2030 timeline)</li>
                    <li><strong>Hybrid Approach:</strong> Implement hybrid classical+PQC schemes during transition period</li>
                </ul>
            </div>
        </div>
        <div class="footer">
            <p>Crypto Posture Scanner v1.0 | IBM Secure Pipelines Service Integration</p>
            <p style="margin-top: 10px; opacity: 0.8;">Track 8: End-to-End Crypto Posture Visibility</p>
        </div>
    </div>
    
    <script>
        // Initialize charts
        function initializeCharts() {{
            // Severity Distribution Chart (Doughnut)
            const severityCtx = document.getElementById('severityChart').getContext('2d');
            new Chart(severityCtx, {{
                type: 'doughnut',
                data: {{
                    labels: ['Critical', 'High', 'Medium', 'Low'],
                    datasets: [{{
                        data: [{critical}, {high}, {medium}, {low}],
                        backgroundColor: ['#dc3545', '#fd7e14', '#ffc107', '#28a745'],
                        borderWidth: 3,
                        borderColor: '#ffffff',
                        hoverOffset: 10
                    }}]
                }},
                options: {{
                    responsive: true,
                    maintainAspectRatio: true,
                    plugins: {{
                        legend: {{
                            position: 'bottom',
                            labels: {{
                                color: '#333',
                                font: {{ size: 11, weight: 'bold' }},
                                padding: 10
                            }}
                        }},
                        tooltip: {{
                            backgroundColor: '#ffffff',
                            titleColor: '#333',
                            bodyColor: '#333',
                            borderColor: '#ddd',
                            borderWidth: 1,
                            padding: 10
                        }}
                    }}
                }}
            }});
            
            // Risk Impact Chart (Bar)
            const riskCtx = document.getElementById('riskChart').getContext('2d');
            new Chart(riskCtx, {{
                type: 'bar',
                data: {{
                    labels: ['Critical', 'High', 'Medium', 'Low'],
                    datasets: [{{
                        label: 'Risk Impact Score',
                        data: [{critical} * 10, {high} * 5, {medium} * 2, {low} * 1],
                        backgroundColor: ['#dc3545', '#fd7e14', '#ffc107', '#28a745'],
                        borderWidth: 2,
                        borderColor: '#ffffff',
                        borderRadius: 6
                    }}]
                }},
                options: {{
                    responsive: true,
                    maintainAspectRatio: true,
                    scales: {{
                        y: {{
                            beginAtZero: true,
                            ticks: {{
                                color: '#333',
                                font: {{ size: 10, weight: 'bold' }}
                            }},
                            grid: {{ color: '#ddd' }}
                        }},
                        x: {{
                            ticks: {{
                                color: '#333',
                                font: {{ size: 10, weight: 'bold' }}
                            }},
                            grid: {{ color: '#ddd' }}
                        }}
                    }},
                    plugins: {{
                        legend: {{ labels: {{ color: '#333' }} }}
                    }}
                }}
            }});
        }}
        
        // Initialize charts on page load
        window.addEventListener('load', initializeCharts);
        
        // Search functionality
        const searchBox = document.getElementById('searchBox');
        searchBox.addEventListener('input', (e) => {{
            const searchTerm = e.target.value.toLowerCase();
            const findings = document.querySelectorAll('.finding');
            
            findings.forEach(finding => {{
                const text = finding.textContent.toLowerCase();
                finding.style.display = text.includes(searchTerm) ? '' : 'none';
            }});
        }});
        
        // Filter buttons
        const filterBtns = document.querySelectorAll('.btn');
        filterBtns.forEach(btn => {{
            btn.addEventListener('click', () => {{
                filterBtns.forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                const filter = btn.dataset.filter;
                filterBySeverity(filter);
            }});
        }});
        
        function filterBySeverity(severity) {{
            const findings = document.querySelectorAll('.finding');
            findings.forEach(finding => {{
                finding.style.display = (severity === 'all' || finding.classList.contains(severity)) ? '' : 'none';
            }});
        }}
        
        // Make summary cards clickable
        const summaryCards = document.querySelectorAll('.summary-card');
        summaryCards.forEach(card => {{
            card.addEventListener('click', () => {{
                const severity = card.dataset.severity;
                if (severity) {{
                    filterBySeverity(severity);
                    
                    // Update active button
                    filterBtns.forEach(btn => {{
                        btn.classList.toggle('active', btn.dataset.filter === severity);
                    }});
                    
                    // Scroll to findings section
                    const findingsSection = document.querySelector('.section');
                    if (findingsSection) {{
                        findingsSection.scrollIntoView({{ behavior: 'smooth', block: 'start' }});
                    }}
                }}
            }});
        }});
    </script>
</body>
</html>'''

    # Write HTML file
    with open(html_file, 'w') as f:
        f.write(html_content)

if __name__ == '__main__':
    if len(sys.argv) != 24:
        print(f"Error: Expected 23 arguments, got {len(sys.argv) - 1}")
        print("Usage: script patterns_file deps_file pqc_file context_file html_file critical high medium low total dep_count risk_score status_class status_text compliance pqc_readiness pqc_risk pqc_libs quantum_vuln hybrid_impl context_fp context_adjusted context_fp_rate")
        sys.exit(1)
    
    generate_html_report(
        sys.argv[1],  # patterns_file
        sys.argv[2],  # deps_file
        sys.argv[3],  # pqc_file
        sys.argv[4],  # context_file
        sys.argv[5],  # html_file
        int(sys.argv[6]),  # critical
        int(sys.argv[7]),  # high
        int(sys.argv[8]),  # medium
        int(sys.argv[9]),  # low
        int(sys.argv[10]),  # total
        int(sys.argv[11]),  # dep_count
        int(sys.argv[12]),  # risk_score
        sys.argv[13],  # status_class
        sys.argv[14],  # status_text
        sys.argv[15],  # compliance
        sys.argv[16],  # pqc_readiness
        int(sys.argv[17]),  # pqc_risk
        int(sys.argv[18]),  # pqc_libs
        int(sys.argv[19]),  # quantum_vuln
        int(sys.argv[20]),  # hybrid_impl
        int(sys.argv[21]),  # context_fp
        int(sys.argv[22]),  # context_adjusted
        sys.argv[23]   # context_fp_rate
    )
PYTHON_EOF

# Run Python script
python3 /tmp/generate_html_report.py "$PATTERNS_FILE" "$DEPS_FILE" "$PQC_FILE" "$CONTEXT_FILE" "$HTML_REPORT" "$CRITICAL" "$HIGH" "$MEDIUM" "$LOW" "$TOTAL" "$DEP_COUNT" "$RISK_SCORE" "$STATUS_CLASS" "$STATUS_TEXT" "$COMPLIANCE" "$PQC_READINESS" "$PQC_RISK" "$PQC_LIBS" "$QUANTUM_VULN" "$HYBRID_IMPL" "$CONTEXT_FP" "$CONTEXT_ADJUSTED" "$CONTEXT_FP_RATE"

# Cleanup
rm -f /tmp/generate_html_report.py

echo "✅ Reports generated:"
echo "   📄 JSON: $JSON_REPORT"
echo "   📄 HTML: $HTML_REPORT"

exit 0