# 📝 Step 2: README Generation Prompt

**Token Cost:** ~1500 tokens  
**Usage:** After completing Step 1 analysis

---

## Complete README (Recommended)

```markdown
Create a comprehensive README.md for this project.

## Project Context:
[PASTE STEP 1 ANALYSIS HERE]

## Required Structure:

# ⏱️ [Project Name]

<div align="center">

[![Tech Badge](https://img.shields.io/badge/[Tech]-[Version]-[Color]?logo=[logo]&logoColor=white)](url)
[![License](https://img.shields.io/badge/License-[Type]-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-[Platforms]-green)]()

**[One-sentence tagline that captures value proposition]**

[Features](#-features) • [Quick Start](#-quick-start) • [Architecture](#-architecture) • [Documentation](#-documentation) • [Contributing](#-contributing)

</div>

---

## 🌟 What is [Project Name]?

[2-3 paragraph description explaining:
- What problem it solves
- How it works (briefly)
- Target audience
- Unique value proposition]

### Why [Project Name]?

| Traditional Approach | [Project Name] Solution |
|---------------------|------------------------|
| [Problem 1] | **[Solution 1]** |
| [Problem 2] | **[Solution 2]** |
| [Problem 3] | **[Solution 3]** |

---

## ✨ Features

### 📅 [Category 1 - e.g., Smart Scheduling]
- **Feature 1** — Description
- **Feature 2** — Description
- **Feature 3** — Description

### 🎯 [Category 2 - e.g., Energy-Aware Intelligence]
- **Feature 1** — Description
- **Feature 2** — Description
- **Feature 3** — Description

### 📋 [Category 3 - e.g., Template System]
- **Feature 1** — Description
- **Feature 2** — Description
- **Feature 3** — Description

### ✅ [Category 4 - e.g., Todo Management]
- **Feature 1** — Description
- **Feature 2** — Description
- **Feature 3** — Description

### 📊 [Category 5 - e.g., Analytics Dashboard]
- **Feature 1** — Description
- **Feature 2** — Description
- **Feature 3** — Description

### 🎨 [Category 6 - e.g., Desktop Experience]
- **Feature 1** — Description
- **Feature 2** — Description
- **Feature 3** — Description

---

## 📸 Screenshots

<div align="center">

| [View 1] | [View 2] |
|:---:|:---:|
| ![View 1](docs/screenshots/view1.png) | ![View 2](docs/screenshots/view2.png) |
| [Description] | [Description] |

</div>

---

## 🚀 Quick Start

### Prerequisites

Ensure you have the following installed:

```bash
# [Prerequisite 1]
[command to check/install]

# [Prerequisite 2]
[command to check/install]
```

### Installation

1. **Clone the repository**
   ```bash
   git clone [repository-url]
   cd [project-folder]
   ```

2. **Install dependencies**
   ```bash
   [install command]
   ```

3. **[Step 3 - e.g., Generate code]**
   ```bash
   [command]
   ```

4. **Run the application**
   ```bash
   [run command]
   ```

### Build for Production

```bash
# [Platform 1]
[build command]

# [Platform 2]
[build command]
```

---

## 🏗️ Architecture

[Describe architecture pattern in 2-3 sentences]

```
[ASCII Architecture Diagram showing layers/components]
```

### Key Design Decisions

| Pattern/Decision | Purpose | Benefit |
|-----------------|---------|---------|
| [Pattern 1] | [Purpose] | [Benefit] |
| [Pattern 2] | [Purpose] | [Benefit] |
| [Pattern 3] | [Purpose] | [Benefit] |

---

## 📦 Tech Stack

### Core Technologies

| Technology | Version | Purpose |
|------------|---------|---------|
| [Tech 1] | [Version] | [Purpose] |
| [Tech 2] | [Version] | [Purpose] |
| [Tech 3] | [Version] | [Purpose] |

### Key Packages

```yaml
dependencies:
  [package1]: [version]  # Purpose
  [package2]: [version]  # Purpose
  [package3]: [version]  # Purpose
```

---

## 📚 Documentation

Comprehensive documentation is available in the `docs/` directory:

| Document | Description |
|----------|-------------|
| [Getting Started](docs/GETTING_STARTED.md) | Developer onboarding |
| [Architecture](docs/ARCHITECTURE.md) | System design |
| [Features](docs/FEATURES.md) | Feature catalog |
| [Contributing](CONTRIBUTING.md) | Contribution guidelines |

---

## 🛠️ Development

### Project Structure

```
[project]/
├── [folder1]/    # Purpose
├── [folder2]/    # Purpose
├── [folder3]/    # Purpose
└── [key files]   # Purpose
```

### Running Tests

```bash
# Run all tests
[test command]

# Run specific test
[test command with filter]

# Generate coverage
[test command with coverage]
```

---

## 🔮 Roadmap

### Coming Soon

- [ ] [Feature 1] - [Target quarter/year]
- [ ] [Feature 2] - [Target quarter/year]
- [ ] [Feature 3] - [Target quarter/year]

### Under Consideration

- [ ] [Idea 1]
- [ ] [Idea 2]
- [ ] [Idea 3]

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/name`)
3. **Commit** your changes (`git commit -m 'feat: description'`)
4. **Push** to the branch (`git push origin feature/name`)
5. **Open** a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

## 📄 License

This project is licensed under the [License Name] - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Thank person/org 1]
- [Thank person/org 2]
- [Thank person/org 3]

---

<div align="center">

**Made with ❤️ using [Technology]**

[Report Bug](issues) • [Request Feature](issues) • [Discussions](discussions)

</div>
```

---

## Modular Approach (Token Efficient)

Generate in parts to save tokens:

### Part 1: Header + Features (~800 tokens)

```markdown
Create README sections 1-3:

1. **Header** with badges and navigation
2. **What/Why** with comparison table
3. **Features** with 6 categories

Project: [PASTE STEP 1 ANALYSIS]

Use emoji headers, tables, and clear formatting.
```

### Part 2: Technical (~800 tokens)

```markdown
Create README sections 4-7:

4. **Quick Start** with commands
5. **Architecture** with diagram
6. **Tech Stack** with tables
7. **Development** with structure

Project: [PASTE STEP 1 ANALYSIS]

Include copy-paste commands and code blocks.
```

### Part 3: Closing (~500 tokens)

```markdown
Create README sections 8-11:

8. **Roadmap** (Coming Soon + Under Consideration)
9. **Contributing** (brief + link)
10. **License** (brief + link)
11. **Footer** with acknowledgments

Project: [PASTE STEP 1 ANALYSIS]

Keep concise and actionable.
```

---

## Customization Tips

### For Libraries

- Add installation section (npm install, pip install, etc.)
- Include usage examples with code
- Add API documentation link
- Show basic example in README

### For Applications

- Focus on screenshots
- Include system requirements
- Add deployment instructions
- Show configuration examples

### For APIs

- Add endpoint documentation
- Include authentication guide
- Show request/response examples
- Link to OpenAPI/Swagger spec

### For CLI Tools

- Show command examples
- Include configuration options
- Add troubleshooting section
- Link to full command reference

---

## Quality Checklist

Before finalizing, verify:

- [ ] 4+ badges at top
- [ ] Clear one-sentence tagline
- [ ] Navigation links (5+ sections)
- [ ] Comparison table (Traditional vs Project)
- [ ] 6 feature categories
- [ ] Screenshot placeholders
- [ ] Prerequisites with commands
- [ ] 4+ installation steps
- [ ] Architecture diagram (ASCII)
- [ ] Tech stack table
- [ ] Project structure tree
- [ ] Roadmap with timeline
- [ ] Contributing guidelines
- [ ] License
- [ ] Footer with links

---

**Next Step:** Use Step 3 prompts to create supporting documentation
