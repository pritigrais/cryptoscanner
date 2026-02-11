// VULNERABLE DEMO APPLICATION - DO NOT USE IN PRODUCTION!

const crypto = require('crypto');

// CRITICAL: Hardcoded secrets
const API_SECRET = "my-super-secret-key-12345";  // CWE-798
const JWT_SECRET = "jwt_secret_key";             // CWE-798

class InsecureAPI {
    constructor() {
        // CRITICAL: Hardcoded IV
        this.iv = Buffer.from('1234567890123456');  // CWE-329
    }
    
    hashPassword(password) {
        // CRITICAL: MD5 for password hashing
        return crypto.createHash('md5')
            .update(password)
            .digest('hex');
    }
    
    generateSessionId() {
        // HIGH: Weak random (Math.random)
        return Math.random().toString(36).substring(7);  // CWE-338
    }
    
    encryptData(data) {
        // HIGH: AES-ECB mode
        const cipher = crypto.createCipheriv('aes-128-ecb', 
            Buffer.from('1234567890123456'), 
            null);
        let encrypted = cipher.update(data, 'utf8', 'hex');
        encrypted += cipher.final('hex');
        return encrypted;
    }
    
    signToken(payload) {
        // MEDIUM: Weak signature algorithm
        const hash = crypto.createHash('sha1')
            .update(JSON.stringify(payload) + JWT_SECRET)
            .digest('hex');
        return hash;
    }
}

// Quantum-vulnerable code
class QuantumVulnerable {
    generateRSAKey() {
        // HIGH: RSA-2048 (quantum-vulnerable)
        return crypto.generateKeyPairSync('rsa', {
            modulusLength: 2048,  // Should be 4096 or use PQC
        });
    }
    
    generateECDSAKey() {
        // HIGH: ECDSA (quantum-vulnerable)
        return crypto.generateKeyPairSync('ec', {
            namedCurve: 'secp256k1'
        });
    }
}

// LOW: Base64 encoding (not encryption)
function encodeData(data) {
    return Buffer.from(data).toString('base64');
}

module.exports = { InsecureAPI, QuantumVulnerable };
