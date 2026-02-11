# 🔧 Crypto Vulnerability Remediation Guide

## Quick Reference: How to Fix Common Issues

### 🚨 CRITICAL Issues

#### 1. MD5/SHA1 for Password Hashing

**❌ Vulnerable Code:**
```python
# Python
import hashlib
hashed = hashlib.md5(password.encode()).hexdigest()
hashed = hashlib.sha1(password.encode()).hexdigest()
```

```javascript
// JavaScript
const crypto = require('crypto');
const hashed = crypto.createHash('md5').update(password).digest('hex');
const hashed = crypto.createHash('sha1').update(password).digest('hex');
```

**✅ Secure Fix:**
```python
# Python - Use bcrypt
import bcrypt
hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt(rounds=12))
# Verify: bcrypt.checkpw(password.encode(), hashed)

# Alternative: Use Argon2 (winner of Password Hashing Competition)
from argon2 import PasswordHasher
ph = PasswordHasher()
hashed = ph.hash(password)
# Verify: ph.verify(hashed, password)
```

```javascript
// JavaScript - Use bcrypt
const bcrypt = require('bcrypt');
const saltRounds = 12;
const hashed = await bcrypt.hash(password, saltRounds);
// Verify: await bcrypt.compare(password, hashed)
```

**Why:** MD5 and SHA1 are too fast, making brute-force attacks feasible. Use slow, adaptive hashing algorithms designed for passwords.

---

#### 2. Hardcoded Secrets/API Keys

**❌ Vulnerable Code:**
```python
API_KEY = "sk_live_12345_secret_key"
DB_PASSWORD = "admin123"
SECRET_TOKEN = "my_secret_token"
```

**✅ Secure Fix:**
```python
# Python - Use environment variables
import os
from dotenv import load_dotenv

load_dotenv()  # Load from .env file
API_KEY = os.getenv('API_KEY')
DB_PASSWORD = os.getenv('DB_PASSWORD')
SECRET_TOKEN = os.getenv('SECRET_TOKEN')

# Validate that secrets are loaded
if not API_KEY:
    raise ValueError("API_KEY environment variable not set")
```

```javascript
// JavaScript - Use environment variables
require('dotenv').config();

const API_KEY = process.env.API_KEY;
const DB_PASSWORD = process.env.DB_PASSWORD;

if (!API_KEY) {
    throw new Error('API_KEY environment variable not set');
}
```

**Setup .env file (never commit this!):**
```bash
# .env
API_KEY=sk_live_12345_secret_key
DB_PASSWORD=admin123
SECRET_TOKEN=my_secret_token
```

**Add to .gitignore:**
```
.env
*.env
.env.*
```

**For Production:** Use secret management services:
- IBM Cloud Secrets Manager
- HashiCorp Vault
- AWS Secrets Manager
- Azure Key Vault

---

### ⚠️ HIGH Severity Issues

#### 3. Weak Random Number Generation

**❌ Vulnerable Code:**
```python
# Python
import random
token = str(random.random())
session_id = random.randint(1000, 9999)
```

```javascript
// JavaScript
const token = Math.random().toString(36);
const sessionId = Math.floor(Math.random() * 1000000);
```

**✅ Secure Fix:**
```python
# Python - Use secrets module
import secrets

# Generate secure random token
token = secrets.token_hex(32)  # 32 bytes = 256 bits
token_urlsafe = secrets.token_urlsafe(32)

# Generate secure random number
session_id = secrets.randbelow(1000000)

# Generate secure random bytes
random_bytes = secrets.token_bytes(16)
```

```javascript
// JavaScript - Use crypto.randomBytes
const crypto = require('crypto');

// Generate secure random token
const token = crypto.randomBytes(32).toString('hex');
const tokenBase64 = crypto.randomBytes(32).toString('base64url');

// Generate secure random number
const sessionId = crypto.randomInt(0, 1000000);
```

**Why:** `random.random()` and `Math.random()` are predictable and not cryptographically secure.

---

#### 4. AES ECB Mode

**❌ Vulnerable Code:**
```python
# Python
from Crypto.Cipher import AES
cipher = AES.new(key, AES.MODE_ECB)
ciphertext = cipher.encrypt(data)
```

**✅ Secure Fix:**
```python
# Python - Use AES-GCM (authenticated encryption)
from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes

# Encryption
key = get_random_bytes(32)  # 256-bit key
cipher = AES.new(key, AES.MODE_GCM)
ciphertext, tag = cipher.encrypt_and_digest(data)

# Store: cipher.nonce, tag, ciphertext

# Decryption
cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
plaintext = cipher.decrypt_and_verify(ciphertext, tag)
```

```javascript
// JavaScript - Use AES-GCM
const crypto = require('crypto');

// Encryption
const algorithm = 'aes-256-gcm';
const key = crypto.randomBytes(32);
const iv = crypto.randomBytes(16);

const cipher = crypto.createCipheriv(algorithm, key, iv);
let encrypted = cipher.update(data, 'utf8', 'hex');
encrypted += cipher.final('hex');
const authTag = cipher.getAuthTag();

// Decryption
const decipher = crypto.createDecipheriv(algorithm, key, iv);
decipher.setAuthTag(authTag);
let decrypted = decipher.update(encrypted, 'hex', 'utf8');
decrypted += decipher.final('utf8');
```

**Why:** ECB mode reveals patterns in plaintext. Use GCM for authenticated encryption.

---

#### 5. Weak Key Size (128-bit)

**❌ Vulnerable Code:**
```python
key_size = 128  # Too weak
key = os.urandom(key_size // 8)
```

**✅ Secure Fix:**
```python
key_size = 256  # Strong
key = os.urandom(key_size // 8)  # 32 bytes
```

**Why:** 256-bit keys provide better security margin and future-proofing.

---

#### 6. Hardcoded IV (Initialization Vector)

**❌ Vulnerable Code:**
```python
iv = b"1234567890123456"  # Never reuse IV!
```

**✅ Secure Fix:**
```python
from Crypto.Random import get_random_bytes

# Generate new random IV for each encryption
iv = get_random_bytes(16)  # AES block size

# Store IV with ciphertext (IV doesn't need to be secret)
```

**Why:** Reusing IVs breaks security of many encryption modes.

---

#### 7. Non-Quantum-Safe Algorithms (RSA, ECDSA)

**❌ Current Code:**
```python
# RSA will be broken by quantum computers
from Crypto.PublicKey import RSA
key = RSA.generate(2048)
```

**✅ Migration Path:**
```python
# Option 1: Increase key size for now
key = RSA.generate(4096)  # Temporary measure

# Option 2: Prepare for post-quantum cryptography
# Use hybrid approach: classical + post-quantum
# NIST has standardized:
# - CRYSTALS-Kyber (encryption)
# - CRYSTALS-Dilithium (signatures)
# - SPHINCS+ (signatures)

# Python example with liboqs (Open Quantum Safe)
import oqs

# Key encapsulation
with oqs.KeyEncapsulation("Kyber512") as kem:
    public_key = kem.generate_keypair()
    ciphertext, shared_secret = kem.encap_secret(public_key)
```

**Timeline:**
- **Now**: Use RSA-4096 or ECDSA P-384
- **2025-2030**: Implement hybrid classical + post-quantum
- **2030+**: Full post-quantum migration

---

### 📊 MEDIUM Severity Issues

#### 8. DES/3DES/RC4 Encryption

**❌ Vulnerable Code:**
```python
from Crypto.Cipher import DES, DES3
cipher = DES.new(key, DES.MODE_CBC, iv)
cipher = DES3.new(key, DES3.MODE_CBC, iv)
```

**✅ Secure Fix:**
```python
from Crypto.Cipher import AES

# Use AES-256-GCM instead
cipher = AES.new(key, AES.MODE_GCM)
```

**Why:** DES has 56-bit keys (broken), 3DES is deprecated, RC4 has known vulnerabilities.

---

### 🔵 LOW Severity Issues

#### 9. Base64 Encoding (Not Encryption!)

**⚠️ Common Mistake:**
```python
import base64
# This is NOT encryption!
encoded = base64.b64encode(sensitive_data)
```

**✅ Correct Usage:**
```python
# Base64 is for encoding, not security
# Use it AFTER encryption for transport/storage

# 1. Encrypt first
from Crypto.Cipher import AES
cipher = AES.new(key, AES.MODE_GCM)
ciphertext, tag = cipher.encrypt_and_digest(data)

# 2. Then encode for transport
import base64
encoded = base64.b64encode(ciphertext)
```

**Why:** Base64 is reversible encoding, not encryption. Always encrypt first.

---

## 🔄 Migration Strategy

### Phase 1: Immediate (Critical Issues)
1. Remove all hardcoded secrets → environment variables
2. Replace MD5/SHA1 password hashing → bcrypt/Argon2
3. Fix weak random → secrets module

### Phase 2: Short-term (High Issues)
1. Replace ECB mode → GCM mode
2. Increase key sizes to 256-bit
3. Generate random IVs

### Phase 3: Medium-term (Medium Issues)
1. Replace DES/3DES/RC4 → AES-256
2. Update TLS to 1.3
3. Review all crypto library versions

### Phase 4: Long-term (Future-proofing)
1. Plan post-quantum migration
2. Implement crypto agility
3. Regular security audits

---

## 📚 Recommended Libraries

### Python
- **Password Hashing**: `bcrypt`, `argon2-cffi`
- **Encryption**: `cryptography` (not `pycrypto`!)
- **Random**: `secrets` (built-in)

```bash
pip install bcrypt argon2-cffi cryptography python-dotenv
```

### JavaScript/Node.js
- **Password Hashing**: `bcrypt`, `argon2`
- **Encryption**: `crypto` (built-in)
- **Environment**: `dotenv`

```bash
npm install bcrypt argon2 dotenv
```

### Java
- **Password Hashing**: `BCrypt`, `Argon2`
- **Encryption**: `Bouncy Castle`
- **Framework**: Spring Security

---

## 🧪 Testing Your Fixes

After fixing vulnerabilities:

1. **Re-run the scanner:**
   ```bash
   ./crypto-scan.sh /path/to/your/code
   ```

2. **Verify functionality:**
   - Test authentication flows
   - Verify encryption/decryption
   - Check API integrations

3. **Security review:**
   - Code review by security team
   - Penetration testing
   - Compliance audit

---

## 📞 Need Help?

- **Security Team**: For critical issues and architecture decisions
- **DevOps Team**: For secret management and deployment
- **Documentation**: See README.md for scanner usage

---

## ✅ Checklist

After remediation, verify:

- [ ] No hardcoded secrets in code
- [ ] Secrets stored in environment variables or secret manager
- [ ] Password hashing uses bcrypt/Argon2
- [ ] Random generation uses cryptographically secure methods
- [ ] Encryption uses AES-256-GCM or equivalent
- [ ] No ECB mode usage
- [ ] Key sizes are 256-bit minimum
- [ ] IVs are randomly generated per encryption
- [ ] Dependencies are up-to-date
- [ ] Scanner shows 0 critical issues
- [ ] Code reviewed and tested

---

**Remember**: Security is a journey, not a destination. Regular scans and updates are essential!