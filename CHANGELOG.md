# Changelog

All notable changes to DayVault (Memory Palace) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-03-14

### 🔐 Security Improvements

#### Added
- **PIN Authentication System** with PBKDF2-like key derivation
  - 4-6 digit PIN support
  - 100,000 iteration key derivation for brute-force resistance
  - Secure storage in platform keystore/keychain
  - `lib/services/security_service.dart`

- **Rate Limiting & Lockout**
  - Maximum 5 PIN attempts before lockout
  - 30-second cooldown period
  - Visual countdown display during lockout
  - Attempt counter reset on successful authentication

- **Field-Level Encryption**
  - XOR cipher with 256-bit derived keys
  - Journal entry content encrypted before storage
  - Graceful fallback for pre-encryption data
  - `lib/services/encryption_service.dart`

- **Biometric Authentication**
  - Fingerprint support (Android)
  - Face ID support (iOS)
  - Fallback to PIN on failure
  - Proper error handling

#### Changed
- **Lock Screen** completely rewritten with security focus
  - Visual feedback for remaining attempts
  - Shake animation on incorrect PIN
  - Loading state during initialization
  - Security status indicator

### 🛡️ Data Integrity

#### Added
- **Auto-Save Functionality**
  - 3-second delayed auto-save for drafts
  - Draft recovery on app restart
  - Visual save status indicator (spinner/edit icon)
  - Automatic draft cleanup after successful save
  - `lib/screens/entry_editor.dart`

- **Backup & Export System**
  - Encrypted JSON export (`.encrypted` format)
  - Unencrypted export option (`.json` format)
  - Share to cloud storage (Drive, iCloud, Dropbox)
  - Backup management UI (view, delete backups)
  - Import functionality with validation
  - `lib/services/backup_service.dart`

- **Draft Management**
  - Secure draft storage using flutter_secure_storage
  - Automatic draft loading for incomplete entries
  - Draft discard option in recovery snackbar

#### Changed
- **Storage Service** extended with draft methods
  - `saveDraft()`, `getDraft()`, `deleteDraft()`
  - Separate storage for drafts vs persisted data

### 📱 Core Features

#### Added
- **Real Image Picker**
  - Camera integration for photos
  - Gallery selection with image picker
  - Local storage in app documents directory
  - Image compression (85% quality, 1920x1080 max)
  - Multiple image support per entry
  - Image preview with delete option

- **Entry Editor Improvements**
  - Auto-save status indicator
  - Unsaved changes warning
  - Better error handling
  - Loading state during save

#### Changed
- **Entry Editor** migrated to ConsumerStatefulWidget
  - Proper Riverpod integration
  - Better state management
  - Improved lifecycle handling

### ⚙️ Configuration

#### Added
- **Android Permissions** (`AndroidManifest.xml`)
  - Camera access
  - Photo library access (legacy + modern)
  - Biometric authentication
  - File access for backups
  - Keystore feature access

- **iOS Permissions** (`Info.plist`)
  - NSCameraUsageDescription
  - NSPhotoLibraryUsageDescription
  - NSPhotoLibraryAddUsageDescription
  - NSFaceIDUsageDescription
  - NSDocumentsFolderUsageDescription

#### Changed
- **App Name** updated to "DayVault" (from "memory_palace")
- **Activity Configuration** updated for lock screen support
  - `showWhenLocked="true"`
  - `turnScreenOn="true"`

### 📦 Dependencies

#### Added
```yaml
crypto: ^3.0.3           # Cryptographic hashing
image_picker: ^1.0.7     # Camera/gallery access
share_plus: ^7.2.2       # File sharing
uuid: ^4.3.3            # Unique ID generation
permission_handler: ^11.3.0  # Runtime permissions
```

### 📝 Documentation

#### Added
- `SECURITY_FEATURES.md` - Comprehensive security documentation
- `CHANGELOG.md` - This changelog
- Extensive code comments in security services
- Architecture diagrams in documentation

### 🐛 Bug Fixes

- Fixed undefined `pi` in radial time picker
- Fixed missing `compute` import for PBKDF2
- Fixed deprecated `encryptedSharedPreferences` parameter
- Fixed unused imports and variables
- Fixed const constructor warnings

### 🔧 Technical Changes

#### Changed
- **ObjectBox Service** simplified (removed runtime encryption config)
  - Note: ObjectBox encryption should be enabled at compile time
  - Field-level encryption handles sensitive data

- **Security Service** uses compute isolates
  - Key derivation runs in background
  - Prevents UI blocking during hashing

- **Entry Editor** uses `dart:math` prefix
  - Avoids conflicts with Flutter classes

### 📊 Code Quality

- ✅ All compilation errors fixed
- ✅ Build successful (APK generated)
- ⚠️ 7 info-level style suggestions remaining (non-blocking)

---

## [1.0.0] - 2026-02-11

### Initial Release

#### Features
- Dual-mode journaling (Story/Event)
- Calendar view with entry indicators
- Identity/ranking system
- Glassmorphism UI design
- Material dark theme
- ObjectBox database integration
- Basic lock screen (insecure)

#### Known Issues (Addressed in 1.1.0)
- ❌ PIN stored in plaintext
- ❌ No data encryption
- ❌ No backup system
- ❌ Fake image storage (picsum.photos)
- ❌ No auto-save
- ❌ Hardcoded metrics

---

## [Unreleased]

### Planned for 1.2.0
- ObjectBox compile-time encryption
- Screenshot prevention (Android FLAG_SECURE)
- App switcher content hiding
- Rich text editor
- Tags system UI
- Mood analytics charts
- Search filters (mood, date, type)

### Under Consideration
- Cloud sync with end-to-end encryption
- Panic PIN (duress code)
- Auto-lock timer
- Export to PDF
- Home screen widget
- Voice input for entries

---

## Version History

| Version | Release Date | Status |
|---------|--------------|--------|
| 1.1.0   | 2026-03-14   | ✅ Current |
| 1.0.0   | 2026-02-11   | ✅ Stable |

---

## Migration Guide

### From 1.0.0 to 1.1.0

#### Breaking Changes
- **None** - All changes are backward compatible
- Existing entries will be encrypted on first save
- PIN will need to be set on first launch (if not already set)

#### Data Migration
- Old unencrypted entries remain readable
- New entries automatically encrypted
- Mixed encrypted/unencrypted data handled gracefully

#### Required Actions
1. Run `flutter pub get` to install new dependencies
2. Run `dart run build_runner build` to regenerate code
3. Set up PIN on first launch (if not configured)
4. Grant permissions for camera/storage when prompted

---

**For detailed security implementation details, see `SECURITY_FEATURES.md`**
