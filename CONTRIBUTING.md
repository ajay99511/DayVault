# 🤝 Contributing to DayVault

First off, thank you for considering contributing to DayVault! It's people like you that make DayVault such a great tool.

---

## 🌟 Types of Contributions

We welcome many types of contributions:

| Type | Description | Example |
|------|-------------|---------|
| **Bug Reports** | Reporting unexpected behavior | "App crashes when importing GGUF" |
| **Feature Requests** | Suggesting new ideas | "Add a dark mode toggle" |
| **Code** | Submitting PRs for fixes or features | Fixing a typo or adding a widget |
| **Documentation** | Improving or adding docs | Updating README or adding a guide |
| **Design** | Suggesting UI/UX improvements | Mockups for a new dashboard |
| **Security** | Reporting vulnerabilities | Disclosing an encryption bypass |
| **Translation** | Localizing the app | Adding Spanish language support |

---

## 🚀 Quick Start for Contributors

1. **Fork** the repository on GitHub.
2. **Clone** your fork to your local machine.
3. **Branch**: Create a new branch for your work:
   ```bash
   git checkout -b feature/amazing-feature
   ```
4. **Changes**: Make your changes and verify with `flutter run`.
5. **Test**: Run `flutter test` to ensure no regressions.
6. **Commit**: Use [Conventional Commits](#-commit-message-convention).
7. **PR**: Open a Pull Request against our `main` branch.

---

## 🎨 Coding Guidelines

To maintain a high-quality codebase, we follow these rules:

- **Clean Architecture**: Keep UI logic in `screens/` and business logic in `services/`.
- **Immutability**: Use `Freezed` for all domain models.
- **State Management**: Use `Riverpod` providers for all shared state.
- **Naming**: Use `camelCase` for variables and `PascalCase` for classes.
- **Comments**: Write meaningful docstrings for complex logic.
- **Linting**: Run `flutter lint` and fix all warnings.

---

## 📝 Commit Message Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/).

| Prefix | Meaning |
|--------|---------|
| `feat:` | A new feature |
| `fix:` | A bug fix |
| `docs:` | Documentation changes |
| `style:` | Formatting, missing semi colons, etc. |
| `refactor:` | Refactoring production code |
| `test:` | Adding missing tests, refactoring tests |
| `chore:` | Updating build tasks, package manager configs, etc. |

**Example:** `feat: add biometric lockout countdown`

---

## 🧪 Testing Guidelines

- Aim for **80%+ test coverage** for new features.
- Include unit tests for all new services.
- Include widget tests for new UI components.
- Run `flutter test --coverage` to verify.

---

## 📋 PR Checklist

Before submitting your PR, please ensure:
- [ ] Code compiles and runs.
- [ ] All tests pass (`flutter test`).
- [ ] Linter is happy (`flutter analyze`).
- [ ] Documentation is updated (if applicable).
- [ ] Conventional commit messages are used.
- [ ] Branch is up-to-date with `main`.

---

## 🏛️ License

By contributing, you agree that your contributions will be licensed under its **MIT License**.

---

<div align="center">
  <p>Thank you for being part of the DayVault journey! 💎</p>
</div>
