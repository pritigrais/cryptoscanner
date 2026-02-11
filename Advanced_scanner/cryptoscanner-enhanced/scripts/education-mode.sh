#!/usr/bin/env bash
set -euo pipefail

echo "🎓 Interactive Crypto Security Learning Mode"
echo "============================================="
echo ""
echo "Fix this vulnerable code (MD5 password hashing):"
echo ""
echo 'import hashlib'
echo 'password_hash = hashlib.md5(password.encode()).hexdigest()'
echo ""
echo "Your fix (or 'skip'): "

read -r user_answer

if echo "$user_answer" | grep -q "bcrypt\|argon2\|scrypt"; then
    echo "✓ Correct! You've learned secure password hashing!"
    echo "🏆 Badge unlocked: Crypto Defender"
else
    echo "Try using bcrypt or Argon2 instead of MD5"
fi
