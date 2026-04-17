# 🚀 Getting Started with DayVault

Welcome to DayVault! This guide will help you set up the project locally and start contributing to the ultimate Quantified Self platform.

---

## 📋 Prerequisites

Before you begin, ensure you have the following installed on your machine:

| Software | Version | Purpose | Download Link |
|----------|---------|---------|---------------|
| **Flutter SDK** | `^3.2.0` | Core framework | [Install Flutter](https://docs.flutter.dev/get-started/install) |
| **Dart SDK** | `^3.2.0` | Programming language | (Included with Flutter) |
| **Android Studio** | Latest | Android development | [Download](https://developer.android.com/studio) |
| **Xcode** | Latest | iOS/macOS development | (Mac App Store) |
| **Visual Studio** | 2022 | Windows development | [Download](https://visualstudio.microsoft.com/) |

---

## 🛠️ Installation Steps

Follow these steps to get your development environment ready:

1. **Clone the Repository**
   ```bash
   git clone https://github.com/yourusername/dayvault.git
   cd dayvault
   ```

2. **Install Flutter Dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate Source Code**
   DayVault uses code generation for ObjectBox and Freezed models. This step is mandatory.
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Verify ObjectBox Setup**
   Ensure the ObjectBox native libraries are correctly linked.
   ```bash
   flutter doctor -v
   ```

5. **Run the Application**
   ```bash
   # For Android
   flutter run
   
   # For iOS
   flutter run -d ios
   
   # For Windows
   flutter run -d windows
   ```

---

## 🔄 Development Workflow

### Hot Reload
Flutter's hot reload feature allows you to see changes instantly. 
- Press `r` in the terminal or use the "Hot Reload" button in your IDE.

### Debugging
We recommend using **VS Code** with the Flutter extension or **Android Studio**.
- Use the **Flutter DevTools** to inspect the widget tree and monitor performance.
- Use `debugPrint()` instead of `print()` for cleaner logs.

### State Management
DayVault uses **Riverpod 3.x**. When adding new providers:
1. Create a new file in `lib/services/` or `lib/providers/`.
2. Use `@riverpod` annotations.
3. Run `build_runner` to generate the provider code.

---

## 🧪 Testing Guide

We strive for high test coverage. Always run tests before submitting a PR.

### Running Tests
```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage
```

### Example Test Case
```dart
void main() {
  test('Encryption Service should encrypt and decrypt correctly', () {
    final service = EncryptionService();
    const plainText = 'Hello World';
    final encrypted = service.encrypt(plainText);
    final decrypted = service.decrypt(encrypted);
    expect(decrypted, equals(plainText));
  });
}
```

---

## 📁 Project Structure

```bash
lib/
├── config/          # Global constants and security questions
├── models/          # Freezed domain models & ObjectBox entities
├── screens/         # UI Screen widgets (Journal, Identity, etc.)
├── services/        # Business logic & Repository implementations
├── widgets/         # Reusable glassmorphic UI components
└── main.dart        # App entry point & initialization logic
```

---

## 🛠️ Common Development Tasks

### Adding a New Icon
We prefer **Lucide Icons**. 
- Add the icon to `lucide_icons` package or use the Material fallback in `lib/config/constants.dart`.

### Modifying the Database
1. Update the `@Entity` class in `lib/models/objectbox_models.dart`.
2. Run `dart run build_runner build`.
3. ObjectBox will automatically handle the migration.

### Updating the UI Theme
Theme constants are located in `lib/config/constants.dart`. 
- Adjust `AppColors` for global styling changes.

---

## ❓ Troubleshooting

| Issue | Solution |
|-------|----------|
| `ObjectBoxException` | Run `flutter clean` and then `flutter pub get`. |
| `build_runner` fails | Use `--delete-conflicting-outputs` flag. |
| Biometrics not working | Ensure your emulator/device has biometrics enrolled. |
| PIN Lockout | Clear app data or use the "Forgot PIN" flow (if configured). |

---

## 📚 Resources
- [Flutter Documentation](https://docs.flutter.dev/)
- [Riverpod Documentation](https://riverpod.dev/)
- [ObjectBox for Dart](https://docs.objectbox.io/getting-started)

---

<div align="center">
  <p>Need more help? Join our community or open an issue!</p>
</div>
