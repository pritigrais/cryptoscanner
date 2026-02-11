#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-.}"
REPORT_DIR="${2:-./reports}"

echo "[SECRET-PREVENTION] Installing git pre-commit hook..."

cat > "$TARGET_DIR/.git/hooks/pre-commit" <<'EOFHOOK'
#!/bin/bash
# Crypto Scanner Secret Prevention Hook

if git diff --cached | grep -E "(api[_-]?key|secret|password|token).*=.*['\"]"; then
    echo "❌ ERROR: Hardcoded secret detected!"
    echo "Use environment variables instead:"
    echo "  export API_KEY=\"your_key\""
    echo "  api_key = os.getenv('API_KEY')"
    exit 1
fi

exit 0
EOFHOOK

chmod +x "$TARGET_DIR/.git/hooks/pre-commit" 2>/dev/null || true

echo "✓ Git hook installed: $TARGET_DIR/.git/hooks/pre-commit"
