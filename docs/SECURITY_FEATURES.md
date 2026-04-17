# 🔐 Security Protocol & Encryption Architecture

DayVault is built with a "Privacy First" philosophy. This document outlines the multi-layered security stack that protects your journal entries and identity data.

---

## 🏗️ Security Architecture

DayVault implements security at four distinct layers:

1. **Access Layer**: Biometric and PIN-based authentication.
2. **Key Layer**: Hardened key derivation using PBKDF2.
3. **Storage Layer**: Field-level encryption (AES-256) and secure keystore persistence.
4. **Transport Layer**: Encrypted backup/restore pipeline.

---

## 🔑 1. Authentication & Key Derivation

### PIN Authentication
- **Requirement**: 4-6 digit numeric PIN.
- **Hardening**: We use a PBKDF2-like derivation process using **HMAC-SHA256**.
- **Iterations**: **100,000 iterations** to resist brute-force attacks.
- **Salt**: A 16-byte cryptographically random salt is generated on first setup and stored in the platform's secure keystore (Android Keystore / iOS Keychain).
- **Isolate-Based**: Key derivation runs in a separate Dart isolate (`compute()`) to keep the UI fluid at 60fps.

### Rate Limiting & Lockout
- **Max Attempts**: 5 failed PIN attempts.
- **Lockout Duration**: 30-second cooldown with an active countdown timer.
- **Persistence**: Attempt counters are stored in secure storage and persist across app restarts.

---

## 🛡️ 2. Encryption Architecture

### Field-Level Encryption
DayVault does not just encrypt the database file; it encrypts individual sensitive fields before they ever touch the disk.

- **Algorithm**: **AES-256-CBC** (Advanced Encryption Standard).
- **IV (Initialization Vector)**: A unique 16-byte random IV is generated for *every* encryption operation.
- **Format**: Ciphertext is stored in a version-prefixed format:
  `[Version Byte] [16-byte IV] [Ciphertext]`

### Decryption Pipeline (Chain of Responsibility)
When reading data, DayVault uses an intelligent decryption pipeline:
1. **Base64 Decode**: Convert stored string to bytes.
2. **Version Check**: Identify if it's AES (v2), Legacy XOR (v1), or Plaintext (fallback).
3. **Decryption**: Execute the appropriate algorithm.
4. **Integrity Check**: Validate the decrypted payload.

---

## 🧬 3. Biometric Integration

DayVault leverages platform-native biometrics via the **Local Auth** framework.

- **Supported Methods**: Face ID (iOS), Fingerprint (Android), Windows Hello.
- **Security Policy**: Biometrics can unlock the app but cannot be used to *change* the PIN or recovery questions without the original PIN.
- **Fallback**: Always falls back to PIN if biometric authentication fails or is unavailable.

---

## ❓ 4. Account Recovery

Since DayVault is offline-first and doesn't store your PIN on a server, we provide a local recovery mechanism.

- **Security Questions**: A pool of 25 questions; users must select and answer 3 during setup.
- **Normalization**: Answers are trimmed, converted to lowercase, and then PBKDF2-hashed with the same salt as the PIN.
- **Threshold**: 2-out-of-3 correct answers are required to authorize a PIN reset.

---

## 💾 5. Secure Backup & Export

- **Encrypted Export**: Generates a `.encrypted` JSON file. The data remains encrypted with your master key.
- **Integrity**: A **SHA-256 hash** is included in the backup to detect tampering.
- **Local Only**: Backups are handled via the native share sheet, allowing you to choose your trusted cloud provider (Drive, iCloud, etc.) without DayVault ever having network access.

---

## 📝 Developer Security Best Practices

When contributing to DayVault, adhere to these security mandates:
1. **Never log sensitive data**: Use `debugPrint` and ensure no PII or ciphertext is logged in release builds.
2. **Use Secure Storage**: All keys, salts, and hashes *must* go into `flutter_secure_storage`.
3. **Mounted Checks**: Always check `if (mounted)` before updating UI state after an async security operation.
4. **Isolate Usage**: Any cryptographic operation taking >16ms must be run in an isolate.

---

<div align="center">
  <p><b>Your memories are your own. DayVault ensures they stay that way.</b></p>
</div>
