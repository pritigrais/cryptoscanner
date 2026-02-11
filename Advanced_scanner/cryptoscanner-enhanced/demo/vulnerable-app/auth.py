#!/usr/bin/env python3
"""
VULNERABLE DEMO APPLICATION - DO NOT USE IN PRODUCTION!
This app contains intentional crypto vulnerabilities for testing the scanner.
"""

import hashlib
import random
import base64
from Crypto.Cipher import AES

# CRITICAL: Hardcoded API key
API_KEY = "sk-1234567890abcdef"  # CWE-798
DATABASE_PASSWORD = "admin123"    # CWE-798

class InsecureAuth:
    def __init__(self):
        # CRITICAL: Hardcoded encryption key
        self.encryption_key = b"my_secret_key_16"  # CWE-321
    
    def hash_password(self, password):
        # CRITICAL: MD5 for password hashing (CWE-327)
        return hashlib.md5(password.encode()).hexdigest()
    
    def generate_token(self):
        # HIGH: Weak random number generator (CWE-338)
        return str(random.random() * 1000000)
    
    def encrypt_data(self, data):
        # HIGH: AES-ECB mode (CWE-327)
        cipher = AES.new(self.encryption_key, AES.MODE_ECB)
        # Padding
        pad_length = 16 - (len(data) % 16)
        padded_data = data + (chr(pad_length) * pad_length)
        encrypted = cipher.encrypt(padded_data.encode())
        return base64.b64encode(encrypted).decode()
    
    def sign_data(self, data):
        # MEDIUM: SHA1 for signatures (CWE-327)
        return hashlib.sha1(data.encode()).hexdigest()

class QuantumVulnerable:
    """Quantum-vulnerable cryptography examples"""
    
    def generate_rsa_key(self):
        # HIGH: RSA-2048 (quantum-vulnerable by 2030)
        from Crypto.PublicKey import RSA
        key = RSA.generate(2048)  # CWE-326
        return key
    
    def ecdsa_sign(self, message):
        # HIGH: ECDSA (quantum-vulnerable)
        from Crypto.PublicKey import ECC
        key = ECC.generate(curve='P-256')
        # Signature logic here
        pass

# Example usage
if __name__ == "__main__":
    auth = InsecureAuth()
    
    # Vulnerable password hashing
    user_password = "secret123"
    password_hash = auth.hash_password(user_password)
    print(f"Password hash (MD5): {password_hash}")
    
    # Weak token generation
    session_token = auth.generate_token()
    print(f"Session token: {session_token}")
    
    # Insecure encryption
    sensitive_data = "Credit card: 4111-1111-1111-1111"
    encrypted = auth.encrypt_data(sensitive_data)
    print(f"Encrypted data: {encrypted}")
