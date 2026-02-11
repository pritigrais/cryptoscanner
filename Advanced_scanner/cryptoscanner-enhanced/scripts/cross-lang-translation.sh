#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${2:-./reports}"

cat > "$REPORT_DIR/cross-language-fixes.md" <<'EOFMD'
# Cross-Language Crypto Fixes

## MD5 Password Hashing → Secure Alternatives

### Python (BEFORE)
```python
import hashlib
password_hash = hashlib.md5(password.encode()).hexdigest()
```

### Python (AFTER)
```python
import bcrypt
password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt(12))
```

### JavaScript (BEFORE)
```javascript
const crypto = require('crypto');
const hash = crypto.createHash('md5').update(password).digest('hex');
```

### JavaScript (AFTER)
```javascript
const bcrypt = require('bcrypt');
const hash = await bcrypt.hash(password, 12);
```

### Java (BEFORE)
```java
MessageDigest md = MessageDigest.getInstance("MD5");
byte[] hash = md.digest(password.getBytes());
```

### Java (AFTER)
```java
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(12);
String hash = encoder.encode(password);
```

## Weak Random → Secure Random

### Python
```python
# BEFORE: import random; x = random.random()
# AFTER:
import secrets
x = secrets.randbelow(100)  # Random int 0-99
token = secrets.token_hex(32)  # Random hex token
```

### JavaScript
```javascript
// BEFORE: Math.random()
// AFTER:
const crypto = require('crypto');
const random = crypto.randomBytes(32);
```

### Java
```java
// BEFORE: new Random().nextInt()
// AFTER:
import java.security.SecureRandom;
SecureRandom random = new SecureRandom();
int value = random.nextInt();
```
EOFMD

echo "Cross-language fixes: $REPORT_DIR/cross-language-fixes.md"
