# 🎫 JIRA Integration Guide

## Overview

Automatically create JIRA tickets for crypto vulnerabilities detected by the scanner. Each ticket includes detailed information, code snippets, and remediation guidance.

## Features

✅ **Smart Grouping** - Groups multiple occurrences into single tickets  
✅ **Priority Mapping** - Critical → Highest, High → High, etc.  
✅ **Rich Descriptions** - Code snippets, file locations, CWE references  
✅ **Remediation Guidance** - Specific fix instructions in each ticket  
✅ **Auto-Labeling** - Tags for easy filtering and tracking  
✅ **Batch Processing** - Handles all findings efficiently  

## Quick Start

### 1. Generate JIRA API Token

1. Go to: https://id.atlassian.com/manage-profile/security/api-tokens
2. Click **Create API Token**
3. Name it: "Crypto Scanner"
4. Copy the token (save it securely!)

### 2. Configure Environment

```bash
# Required
export JIRA_USER="your.email@company.com"
export JIRA_TOKEN="your-api-token-here"

# Optional (defaults shown)
export JIRA_URL="https://your-company.atlassian.net"
export JIRA_PROJECT="SEC"
```

### 3. Run Scanner and Create Tickets

```bash
# Step 1: Run scan
./crypto-scan.sh /path/to/code

# Step 2: Create JIRA tickets
./scripts/create-jira-tickets.sh
```

## Usage Examples

### Basic Usage

```bash
# After running a scan
./scripts/create-jira-tickets.sh
```

### Specify Custom Files

```bash
./scripts/create-jira-tickets.sh reports/crypto-report.json reports/patterns_20260206_163408.json
```

### Integrated Workflow

```bash
# Complete workflow: Scan → Report → Tickets
./crypto-scan.sh /path/to/code && ./scripts/create-jira-tickets.sh
```

### Add to Pipeline

```yaml
# In your .pipeline-config-v2.yaml
- name: crypto-scan-and-ticket
  script: |
    ./crypto-scan.sh . || true
    ./scripts/create-jira-tickets.sh
```

## What Gets Created

### Ticket Structure

**Summary:**
```
[Crypto-CRITICAL] Hardcoded password detected (2 occurrence(s))
```

**Description Includes:**
- 🔐 Scan metadata (ID, timestamp)
- 📊 Severity level and CWE reference
- 📍 All affected file locations and line numbers
- 💻 Code snippets showing the vulnerability
- 🔧 Specific remediation instructions with examples
- 📚 Links to OWASP and CWE documentation

**Fields:**
- **Issue Type**: Bug
- **Priority**: Highest/High/Medium/Low (mapped from severity)
- **Labels**: `crypto-vulnerability`, `security`, `crypto-critical`, `scan-{id}`, `auto-generated`

### Example Ticket

```
Title: [Crypto-CRITICAL] MD5 used for password hashing (5 occurrence(s))

Description:
