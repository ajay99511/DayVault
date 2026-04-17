# 📚 Step 3: Supporting Documentation Prompts

**Token Cost:** ~2500 tokens (all 3 files)  
**Usage:** After completing Step 2 README

---

## 3a: GETTING_STARTED.md Prompt

```markdown
Create docs/GETTING_STARTED.md for developer onboarding.

## Project Context:
[PASTE STEP 1 ANALYSIS HERE]

## Required Structure:

# 🚀 Getting Started with [Project Name]

This guide will help you set up your development environment and start contributing.

---

## 📋 Prerequisites

### Required Software

| Software | Version | Purpose | Download |
|----------|---------|---------|----------|
| [Software 1] | [Version] | [Purpose] | [URL] |
| [Software 2] | [Version] | [Purpose] | [URL] |
| [Software 3] | [Version] | [Purpose] | [URL] |

### Platform-Specific Requirements

#### [Platform 1 - e.g., Windows]
```bash
# Installation commands
[command 1]
[command 2]
```

#### [Platform 2 - e.g., macOS]
```bash
# Installation commands
[command 1]
[command 2]
```

#### [Platform 3 - e.g., Linux]
```bash
# Installation commands
[command 1]
[command 2]
```

---

## 📥 Installation

### Step 1: Clone the Repository

```bash
git clone [repository-url]
cd [project-folder]
```

### Step 2: Verify Installation

```bash
# Check version
[version check command]

# Run diagnostics
[diagnostic command]
```

### Step 3: Install Dependencies

```bash
[install command]
```

### Step 4: [Project-Specific Step - e.g., Generate Code]

```bash
[codegen command]
```

### Step 5: Run the Application

```bash
# [Platform/Mode 1]
[run command]

# [Platform/Mode 2]
[run command]
```

---

## 🛠️ Development Workflow

### Hot Reload / Live Reload

```bash
# While app is running:
[command/key]  # Action
[command/key]  # Action
[command/key]  # Action
```

### Debugging

```bash
# Run in debug mode
[command]

# Open DevTools
[command]
```

DevTools provides:
- Feature 1
- Feature 2
- Feature 3

---

## 🧪 Testing

### Run All Tests

```bash
[test command]
```

### Run Specific Test

```bash
[test command with filter]
```

### Generate Coverage

```bash
[test command with coverage]
```

### Writing Tests

Example test:

```[language]
// Example test code
// Show structure and assertions
```

---

## 📁 Project Structure

```
[project]/
├── [folder1]/          # Purpose
│   ├── [subfolder]/    # Purpose
│   └── [file]          # Purpose
├── [folder2]/          # Purpose
├── [folder3]/          # Purpose
└── [key files]         # Purpose
```

---

## 🔧 Common Development Tasks

### Adding a New Feature

1. **Create a feature branch**
   ```bash
   git checkout -b feature/feature-name
   ```

2. **Make changes** following architecture patterns

3. **Run code generation** (if applicable)
   ```bash
   [codegen command]
   ```

4. **Write tests** for new functionality

5. **Run linter**
   ```bash
   [lint command]
   ```

6. **Commit changes**
   ```bash
   git add .
   git commit -m "feat: description"
   ```

### [Task 2 - Project Specific]

[Steps with commands]

### [Task 3 - Project Specific]

[Steps with commands]

---

## 🐛 Troubleshooting

### Common Issues

#### "[Error/Issue 1]"

```bash
# Solution
[fix command]
```

#### "[Error/Issue 2]"

**Cause:** [Explanation]

**Solution:**
```bash
[fix command]
```

#### "[Error/Issue 3]"

- Step 1
- Step 2
- Step 3

---

## 📚 Resources

### Official Documentation

- [Tech 1 Docs](url)
- [Tech 2 Docs](url)
- [Tech 3 Docs](url)

### Project Documentation

- [Architecture](ARCHITECTURE.md)
- [Features](FEATURES.md)
- [Contributing](CONTRIBUTING.md)

### Community

- [Discord/Slack](url)
- [Stack Overflow Tag](url)
- [Reddit](url)

---

## ✅ Next Steps

Now that you're set up:

1. **Explore the codebase** - Start with [entry point file]
2. **Run the app** - `[run command]`
3. **Make a small change** - Try modifying [simple thing]
4. **Read the docs** - Check out [key doc]
5. **Pick an issue** - Look for "good first issue" labels

Happy coding! 🎉
```

---

## 3b: CONTRIBUTING.md Prompt

```markdown
Create CONTRIBUTING.md with contribution guidelines.

## Project Context:
[PASTE STEP 1 ANALYSIS HERE]

## Required Structure:

# 🤝 Contributing to [Project Name]

Thank you for considering contributing! This document provides guidelines.

---

## 🌟 How to Contribute

### Types of Contributions We Welcome

| Type | Description | Examples |
|------|-------------|----------|
| **🐛 Bug Reports** | Report bugs | Crash reports, UI glitches |
| **💡 Feature Requests** | Suggest features | New integrations, improvements |
| **📝 Documentation** | Improve docs | Typos, clarifications, examples |
| **🔧 Code Contributions** | Fix/add code | Bug fixes, new features |
| **🎨 Design** | UI/UX improvements | Layouts, animations, themes |
| **🧪 Testing** | Add tests | Unit, integration tests |
| **🌍 Localization** | Translate | New language support |

---

## 🚀 Quick Start for Contributors

### 1. Fork the Repository

```bash
# Click "Fork" on GitHub, then clone
git clone https://github.com/YOUR_USERNAME/[repo].git
cd [repo]
```

### 2. Create a Branch

```bash
# Always branch from main
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/your-feature-name
```

### 3. Make Your Changes

Follow development guidelines.

### 4. Test Your Changes

```bash
# Run all tests
[test command]

# Run linter
[lint command]

# Run manually
[run command]
```

### 5. Commit Your Changes

```bash
# Stage changes
git add .

# Commit with conventional commit
git commit -m "type: description"
```

### 6. Push and Create PR

```bash
# Push to fork
git push origin feature/your-feature-name

# Go to GitHub and create Pull Request
```

---

## 📝 Coding Guidelines

### [Language] Style Guide

Follow the [Official Style Guide](url):

```[language]
// ✅ DO: Best practice example
[good code example]

// ❌ DON'T: Anti-pattern
[bad code example]
```

### File Organization

```[language]
// 1. Import order
import ...

// 2. Part directives
part ...

// 3. Your code
class ...
```

### Documentation Comments

```[language]
/// Doc comment format
///
/// ## Parameters
/// - [param]: Description
///
/// ## Returns
/// Description
[function example]
```

---

## 🏷️ Commit Message Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/):

### Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat: add new feature` |
| `fix` | Bug fix | `fix: resolve crash` |
| `docs` | Documentation | `docs: update README` |
| `style` | Formatting | `style: fix indentation` |
| `refactor` | Refactoring | `refactor: extract method` |
| `test` | Tests | `test: add unit tests` |
| `chore` | Maintenance | `chore: update deps` |

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Examples

```bash
# Simple
git commit -m "feat: add Pomodoro timer"

# With scope
git commit -m "feat(analytics): add peak hour chart"

# With body
git commit -m "fix(schedule): resolve undo crash

- Fixed null pointer in undo stack
- Added null checks
- Updated tests

Closes #142"
```

---

## 🧪 Testing Guidelines

### Writing Tests

```[language]
// Example test structure
import ...

void main() {
  group('Test Group', () {
    test('does something', () {
      // Arrange
      ...
      
      // Act
      ...
      
      // Assert
      ...
    });
  });
}
```

### Coverage Goals

| Component | Minimum |
|-----------|---------|
| Models | 90% |
| Logic | 80% |
| UI | 60% |

---

## 🐛 Reporting Bugs

### Bug Report Template

```markdown
### Describe the Bug
Clear description of the issue.

### To Reproduce
Steps to reproduce:
1. Go to '...'
2. Click on '...'
3. See error

### Expected Behavior
What you expected to happen.

### Screenshots
If applicable.

### Environment
- OS: [e.g., Windows 11]
- Version: [e.g., 1.0.0]

### Additional Context
Any other context.
```

---

## 💡 Feature Requests

### Feature Request Template

```markdown
### Problem Statement
Is this related to a problem?

### Proposed Solution
What you want to happen.

### Alternatives Considered
Other solutions you've considered.

### Additional Context
Mockups or screenshots.
```

---

## 🔍 Pull Request Process

### PR Checklist

Before submitting:

- [ ] Code follows style guidelines
- [ ] Tests are passing
- [ ] Linter passes
- [ ] Documentation updated
- [ ] Commit messages follow convention
- [ ] Branch is up to date

### PR Template

```markdown
## Description
Brief description of changes.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change

## Testing
- [ ] Tests added/updated
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] No new warnings
- [ ] Tests pass locally
```

---

## 📞 Getting Help

- **Documentation**: Check docs/ folder
- **Discussions**: [GitHub Discussions URL]
- **Discord**: [Invite URL]

---

## 🏆 Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes
- GitHub Contributors graph

---

## 📄 License

By contributing, you agree your contributions will be licensed under the [License](LICENSE).

---

Thank you for contributing! 🎉
```

---

## 3c: FEATURES.md Prompt

```markdown
Create docs/FEATURES.md with comprehensive feature catalog.

## Project Context:
[PASTE STEP 1 ANALYSIS HERE]

## Required Structure:

# ✨ [Project Name] - Features

Complete guide to all features.

---

## 📋 Table of Contents

- [Core Features](#-core-features)
- [Category 1](#-category-1)
- [Category 2](#-category-2)
- [Coming Soon](#-coming-soon)
- [Roadmap](#-roadmap)

---

## 🎯 Core Features

### [Feature Name]

**Status:** ✅ Available

[2-3 paragraph description]

**Benefits:**
- ✅ Benefit 1
- ✅ Benefit 2
- ✅ Benefit 3

**How it Works:**
1. Step 1
2. Step 2
3. Step 3

**Example:**
```[language]
// Code example showing feature
```

---

## 📅 [Category 1 - e.g., Scheduling]

### [Feature 1]

**Status:** ✅ Available

Description and use cases.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| Property 1 | Type | Description |
| Property 2 | Type | Description |

### [Feature 2]

**Status:** ✅ Available

Description.

---

## 🎯 [Category 2 - e.g., Analytics]

### [Feature 1]

**Status:** ✅ Available

**Metrics:**

| Metric | Calculation | Source |
|--------|-------------|--------|
| Metric 1 | Formula | Data source |
| Metric 2 | Formula | Data source |

---

## 🚀 Coming Soon

### [Feature 1]
**Target:** Q[Quarter] [Year]

- Description
- Benefits
- Use cases

### [Feature 2]
**Target:** Q[Quarter] [Year]

- Description
- Benefits

---

## 🛣️ Roadmap

### Version [Next] (Q[Quarter] [Year])
- [ ] [Feature 1]
- [ ] [Feature 2]
- [ ] [Feature 3]

### Version [Future] (Q[Quarter] [Year])
- [ ] [Feature 4]
- [ ] [Feature 5]

---

## 💡 Under Consideration

These features are being explored:

- [ ] [Idea 1] - Brief description
- [ ] [Idea 2] - Brief description
- [ ] [Idea 3] - Brief description
- [ ] [Idea 4] - Brief description

---

## 📊 Feature Status Legend

| Status | Badge | Description |
|--------|-------|-------------|
| Available | ✅ | Fully implemented |
| In Progress | 🚧 | Being developed |
| Planned | 📅 | Committed to roadmap |
| Proposed | 💡 | Under consideration |

---

## 🙋 Feature Requests

Have an idea? Submit a feature request:
1. Go to [GitHub Issues](url)
2. Click "New Issue"
3. Select "Feature Request"

---

## 📝 Version History

### Version 1.0.0 ([Date])
**Initial Release**
- Feature 1
- Feature 2
- Feature 3
```

---

## Usage Instructions

1. **Copy** the appropriate prompt
2. **Paste** Step 1 analysis into `[PASTE STEP 1 ANALYSIS HERE]`
3. **Send** to AI agent
4. **Save** output to respective file
5. **Review** against quality checklist

**Token Tip:** Generate one file at a time for better quality control.
