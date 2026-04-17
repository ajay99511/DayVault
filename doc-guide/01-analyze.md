# 📊 Step 1: Project Analysis Prompt

**Token Cost:** ~500 tokens  
**Usage:** First step for any project documentation

---

## Quick Analysis (Recommended)

```markdown
Analyze this project and provide a structured summary.

Read these files:
- Package config (pubspec.yaml, package.json, pom.xml, etc.)
- Main entry point (main.dart, index.js, app.py, etc.)
- README.md (if exists)
- Any files in docs/ folder

Output this table:

| Aspect | Details |
|--------|---------|
| Project Name | |
| Project Type | (Web/Mobile/Desktop/Library/CLI/API) |
| Description | (One sentence) |
| Tech Stack | (Top 5 technologies) |
| Target Platform | |
| Entry Points | (Main files) |
| Key Dependencies | (5-10 packages) |
| Current State | (Template/Dev/Production) |
| Key Features | (Bullet list 5-10) |
| Documentation Status | (What exists) |

Keep it concise and factual.
```

---

## Deep Analysis (Use for Complex Projects)

```markdown
Conduct a comprehensive project analysis.

## Files to Read:
1. Configuration: [list config files]
2. Entry Points: [list main files]
3. Core Logic: [list 3-5 key source files]
4. Tests: [list test structure]
5. Existing Docs: [list any docs]

## Output Structure:

### 1. Project Overview
- **Name**: 
- **Purpose**: 
- **Problem Solved**: 

### 2. Technology Stack
| Layer | Technology | Purpose |
|-------|------------|---------|
| Frontend | | |
| Backend | | |
| Database | | |
| DevOps | | |

### 3. Architecture Pattern
- **Pattern**: (MVC/MVVM/Clean/Layered/etc.)
- **Key Components**: 
- **Data Flow**: 

### 4. Directory Structure
```
project/
├── key_folder_1/    # Purpose
├── key_folder_2/    # Purpose
└── key_file.ext     # Purpose
```

### 5. Features Inventory
- [ ] Feature 1
- [ ] Feature 2
- [ ] Feature 3

### 6. Development Status
- **Version**: 
- **Last Updated**: 
- **Test Coverage**: 
- **Build Status**: 

### 7. Documentation Gaps
- Missing: 
- Outdated: 
- Needs improvement: 

### 8. Recommendations
- Priority 1: 
- Priority 2: 
- Priority 3: 

Keep analysis actionable and specific.
```

---

## Ultra-Quick Analysis (Minimum Tokens)

```markdown
5-bullet project summary:
1. What it does
2. Main tech stack
3. Target users/platform
4. Current state
5. One unique feature

Read: package config + main file only.
```

---

## Platform-Specific Analysis

### For Flutter Projects

```markdown
Analyze this Flutter project:

Read: pubspec.yaml, lib/main.dart, lib/ folder structure

Output:
| Aspect | Details |
|--------|---------|
| App Name | |
| Type | (Mobile/Desktop/Web) |
| Flutter Version | |
| State Management | (Provider/Bloc/Riverpod/etc.) |
| Local Storage | (SQLite/Hive/SharedPreferences) |
| Key Packages | (Top 10 from pubspec) |
| Platforms Supported | |
| Architecture | (MVVM/Clean/etc.) |
| Main Screens | (From lib/ui/) |
| Core Features | (5-10 bullets) |
```

### For Node.js Projects

```markdown
Analyze this Node.js project:

Read: package.json, index.js/main.js, src/ folder

Output:
| Aspect | Details |
|--------|---------|
| Project Name | |
| Type | (API/CLI/Library/Web App) |
| Node Version | |
| Framework | (Express/Fastify/NestJS/etc.) |
| Database | |
| Key Dependencies | (Top 10) |
| Scripts | (From package.json) |
| Main Routes/Commands | |
| Testing | (Jest/Mocha/etc.) |
| Core Features | (5-10 bullets) |
```

### For Python Projects

```markdown
Analyze this Python project:

Read: setup.py/pyproject.toml, main.py, package structure

Output:
| Aspect | Details |
|--------|---------|
| Project Name | |
| Type | (Library/CLI/Web App/Script) |
| Python Version | |
| Framework | (Django/Flask/FastAPI/etc.) |
| Key Dependencies | (Top 10) |
| Entry Points | |
| Main Modules | |
| Testing | (pytest/unittest) |
| Core Features | (5-10 bullets) |
```

---

## Usage Instructions

1. **Copy** the appropriate prompt above
2. **Paste** into your AI agent
3. **Wait** for analysis output
4. **Save** the output (to file or variable)
5. **Reuse** in subsequent steps

**Pro Tip:** Save the analysis output to `temp_analysis.md` and reference it in later prompts instead of re-reading files.

---

## Example Output

```markdown
| Aspect | Details |
|--------|---------|
| Project Name | Chronos Planner |
| Project Type | Desktop Productivity App |
| Description | Time management app with energy-aware scheduling |
| Tech Stack | Flutter 3.x, Dart 3.0, Drift, Provider |
| Target Platform | Windows, Linux, macOS |
| Entry Points | lib/main.dart, pubspec.yaml |
| Key Dependencies | provider, drift, google_fonts, uuid, window_manager |
| Current State | Production v1.0.0 |
| Key Features | • Rolling week scheduler<br>• Energy-level tracking<br>• Template system<br>• Analytics dashboard<br>• Focus Mode |
| Documentation Status | 8 docs in docs/ folder, README needs update |
```

---

**Next Step:** Use this analysis in Step 2: README Generation
