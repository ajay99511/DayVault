# 🔐 DayVault Security & Features Documentation

## Overview

DayVault is a secure, offline-first journaling application with end-to-end encryption for your personal memories and identity tracking.

---

## 🛡️ Security Features

### 1. PIN-Based Authentication

**Implementation:** `lib/services/security_service.dart`

- **4-6 digit PIN** required for first-time setup
- **PBKDF2-like key derivation** with 100,000 iterations
- **Rate limiting**: Maximum 5 attempts before lockout
- **30-second lockout** after too many failed attempts
- **Secure storage** using Android Keystore / iOS Keychain

#### How It Works:
```dart
// PIN is hashed using multiple rounds of HMAC-SHA256
// Salt is randomly generated and stored securely
// Derived key is used for data encryption
```

### 2. Biometric Authentication

**Supported Methods:**
- Fingerprint (Android)
- Face ID (iOS)
- Iris Scan (Android)

**Fallback:** PIN authentication if biometrics fail

### 3. Data Encryption

**Field-Level Encryption:** `lib/services/encryption_service.dart`

- **Journal entries** (headline, content, feelings) encrypted before storage
- **XOR cipher** with PBKDF2-derived 256-bit keys
- **Graceful fallback** to plaintext if encryption key unavailable
- **Transparent decryption** when reading data

**Database Storage:** `lib/models/objectbox_models.dart`
- ObjectBox NoSQL database for fast offline access
- Encrypted fields stored as base64 strings

### 4. Secure Backup & Export

**Implementation:** `lib/services/backup_service.dart`

- **Encrypted backups** (`.encrypted` format)
- **Share to cloud** (Google Drive, iCloud, Dropbox)
- **Import functionality** with validation
- **Backup management** UI in Profile screen

#### Backup Format:
```json
{
  "version": "1.0",
  "exportDate": "2026-03-14T...",
  "journal": [...],
  "rankings": [...],
  "settings": {...}
}
```

---

## 📱 Features

### Core Features

| Feature | Description | Status |
|---------|-------------|--------|
| **Journal** | Create story/event entries with moods | ✅ Complete |
| **Auto-Save** | Drafts saved every 3 seconds | ✅ Complete |
| **Image Attachments** | Real camera/gallery integration | ✅ Complete |
| **Calendar View** | Monthly view with entry indicators | ✅ Complete |
| **Identity Tracking** | Rank favorites across categories | ✅ Complete |
| **Encrypted Backup** | Export to encrypted JSON | ✅ Complete |
| **Biometric Lock** | Fingerprint/Face ID unlock | ✅ Complete |

### Journal Entry Types

1. **Story Mode** (Indigo)
   - Daily reflections
   - Mood + feeling tracking
   - Prompt: "How was your day?"

2. **Event Mode** (Emerald)
   - Specific events/moments
   - Time bucket tracking
   - Prompt: "What happened?"

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.2.0 or higher
- Android SDK 21+ (Android 5.0+)
- iOS 12.0+ (for iOS builds)

### Installation

```bash
# Clone the repository
cd dayvault

# Install dependencies
flutter pub get

# Generate code (ObjectBox, Freezed)
dart run build_runner build --delete-conflicting-outputs

# Run on device
flutter run
```

### First Launch

1. **Set PIN**: Enter a 4-6 digit PIN on first launch
2. **Biometric Setup**: Optionally enable biometrics
3. **Create Entry**: Tap the + button to add your first memory

---

## 📁 Project Structure

```
lib/
├── config/
│   └── constants.dart           # App colors, mood icons
├── models/
│   ├── types.dart               # Freezed data models
│   ├── objectbox_models.dart    # Database entities (encrypted)
│   └── types.freezed.dart       # Generated code
├── screens/
│   ├── lock_screen.dart         # PIN/biometric authentication
│   ├── journal_screen.dart      # Main journal list
│   ├── entry_editor.dart        # Create/edit entries (auto-save)
│   ├── calendar_screen.dart     # Monthly calendar view
│   ├── identity_screen.dart     # Preference rankings
│   ├── profile_screen.dart      # Settings & backups
│   └── journal_viewer_screen.dart # View single entry
├── services/
│   ├── security_service.dart    # PIN hashing, rate limiting
│   ├── encryption_service.dart  # Field-level encryption
│   ├── backup_service.dart      # Export/import functionality
│   ├── storage_service.dart     # ObjectBox CRUD + drafts
│   └── objectbox_service.dart   # Database initialization
├── widgets/
│   └── glass_widgets.dart       # Glassmorphism UI components
└── main.dart                    # App entry point
```

---

## 🔒 Security Best Practices

### For Users

1. **Choose a strong PIN** - Avoid obvious patterns (1234, 0000)
2. **Enable biometrics** - Faster and more secure than PIN entry
3. **Regular backups** - Export encrypted backups weekly
4. **Store backups safely** - Use cloud storage with 2FA

### For Developers

1. **Never log sensitive data** - Journal content should never appear in logs
2. **Use secure storage** - Always use `flutter_secure_storage` for secrets
3. **Encrypt at rest** - All user data should be encrypted before storage
4. **Minimize permissions** - Only request necessary permissions
5. **Regular security audits** - Review code for vulnerabilities

---

## 📊 Data Flow

### Creating a Journal Entry

```
User Input → Entry Editor → Auto-Save Draft (encrypted)
                          ↓
                     Save Button
                          ↓
            Encryption Service (encrypt fields)
                          ↓
            ObjectBox Database (encrypted storage)
```

### Backup Export

```
User Request → Profile Screen → Backup Service
                                    ↓
                          Fetch All Data (decrypt)
                                    ↓
                          JSON Serialization
                                    ↓
                          Encrypt JSON (optional)
                                    ↓
                          Save to File
                                    ↓
                          Share Sheet (cloud storage)
```

### Authentication Flow

```
App Launch → Lock Screen
                 ↓
         PIN Set? ── No ──→ Setup PIN → Derive Key → Home
                 ↓
                Yes
                 ↓
         Biometric Available? ── Yes ──→ Biometric Prompt
                 ↓                           ↓
                No                      Success? ── No ──→ PIN Entry
                 ↓                           ↓
            PIN Entry                   Success ──→ Home
                 ↓
            Verify PIN (hashed)
                 ↓
            Rate Limit Check
                 ↓
            Success? ── No ──→ Show Error / Lockout
                 ↓
               Yes
                 ↓
              Home
```

---

## 🧪 Testing

### Run Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

### Manual Testing Checklist

- [ ] Set PIN on first launch
- [ ] Unlock with biometrics
- [ ] Create journal entry with image
- [ ] Verify auto-save (close app mid-entry)
- [ ] Export encrypted backup
- [ ] Import backup on fresh install
- [ ] Test rate limiting (5 failed PIN attempts)

---

## 🔧 Configuration

### Android Permissions

Located in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### iOS Permissions

Located in `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>DayVault needs camera access to capture photos for your memories.</string>
<key>NSFaceIDUsageDescription</key>
<string>DayVault uses Face ID to securely unlock your private journal.</string>
```

---

## 📈 Future Enhancements

### Planned Features

- [ ] **Cloud Sync** - Optional encrypted cloud backup
- [ ] **Rich Text Editor** - Formatting, lists, links
- [ ] **Mood Analytics** - Charts and insights
- [ ] **Tags System** - Better organization
- [ ] **Search Filters** - By mood, date, type
- [ ] **Export to PDF** - Beautiful journal exports
- [ ] **Widget** - Quick entry from home screen

### Security Improvements

- [ ] **ObjectBox Encryption** - Full database encryption at compile time
- [ ] **Screenshot Prevention** - Android FLAG_SECURE
- [ ] **App Switcher Blur** - Hide content in recent apps
- [ ] **Panic PIN** - Duress code to hide sensitive entries
- [ ] **Auto-Lock Timer** - Lock after inactivity

---

## 🐛 Known Issues

| Issue | Workaround | Priority |
|-------|------------|----------|
| Radial time picker is visual only | Use time bucket buttons instead | Low |
| No undo after delete | Confirm dialog before delete | Medium |
| Fake metrics in profile | Display actual calculated stats | Medium |

---

## 📞 Support

For issues or questions:
1. Check this documentation
2. Review the code comments
3. File an issue on the repository

---

## 📄 License

This project is proprietary software. All rights reserved.

---

**Built with ❤️ for preserving memories securely**
