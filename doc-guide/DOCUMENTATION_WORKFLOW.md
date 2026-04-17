# 🚀 Documentation Generator Workflow

A repeatable, token-efficient workflow to create **top 1% GitHub documentation** for any project.

---

## 📋 Quick Start

**For any new project, run these 4 steps:**

```bash
# 1. Analyze project structure
./docs-workflow.sh analyze

# 2. Generate README
./docs-workflow.sh readme

# 3. Generate supporting docs
./docs-workflow.sh docs

# 4. Finalize
./docs-workflow.sh finalize
```

---

## 🎯 The 4-Step Workflow

### Step 1: Project Analysis (5 minutes)

**Goal:** Understand project structure, tech stack, and purpose.

**Agent Prompt:**
```
Analyze this project and provide a structured summary:

1. **Project Type**: (Web/Mobile/Desktop/Library/CLI)
2. **Tech Stack**: List all major technologies
3. **Entry Points**: main files, configuration files
4. **Directory Structure**: Key folders and their purposes
5. **Current State**: Template/In Development/Production Ready

Read these files:
- Package config (package.json, pubspec.yaml, pom.xml, etc.)
- Main entry point (main.*, index.*, app.*)
- README.md (if exists)
- Any existing docs/

Output as a concise table.
```

**Expected Output:**
```markdown
| Aspect | Details |
|--------|---------|
| Project Type | Flutter Desktop App |
| Tech Stack | Flutter 3.x, Dart 3.0, Drift, Provider |
| Entry Points | lib/main.dart, pubspec.yaml |
| Key Folders | lib/, test/, docs/ |
| State | Production Ready v1.0 |
```

---

### Step 2: README Generation (10 minutes)

**Goal:** Create world-class README.md

**Agent Prompt:**
```
Create a README.md following this structure:

## Required Sections:
1. **Header**: Project name + 4 badges (Tech, Version, License, Platform)
2. **Tagline**: One sentence value proposition
3. **Navigation**: 5 key section links
4. **What/Why**: Description + comparison table
5. **Features**: 6 categories with emoji headers
6. **Screenshots**: Placeholder grid (2x2)
7. **Quick Start**: Prerequisites + Installation + Run commands
8. **Architecture**: ASCII diagram + decisions table
9. **Tech Stack**: Dependencies table + code blocks
10. **Documentation**: Links to docs/ folder
11. **Roadmap**: Coming Soon + Under Consideration
12. **Contributing**: Brief guidelines + link
13. **License**: MIT + link
14. **Footer**: Acknowledgments + links

Style Requirements:
- Use emoji section headers (🌟 ✨ 📅 🎯 🚀 📚 🤝)
- Center-align header section with <div align="center">
- Include 3-5 tables for comparisons
- Add 2-3 code blocks with commands
- Keep total length 400-600 lines
- Add navigation links at top

Project Context:
[PASTE STEP 1 ANALYSIS HERE]
```

**Token Optimization:**
- Generate in 2 parts if needed (Part 1: Header-Features, Part 2: Rest)
- Reuse Step 1 analysis instead of re-reading files

---

### Step 3: Supporting Docs (15 minutes)

**Goal:** Create essential documentation suite

#### 3a: GETTING_STARTED.md

**Agent Prompt:**
```
Create docs/GETTING_STARTED.md with:

## Required Sections:
1. Prerequisites table (Software | Version | Purpose | Download Link)
2. Installation steps (5-7 numbered steps with commands)
3. Development workflow (Hot reload, debugging)
4. Testing guide (Commands + example test)
5. Project structure tree
6. Common development tasks (3-5 examples)
7. Troubleshooting table (Issue | Solution)
8. Resources links

Style:
- Include copy-paste commands
- Add code examples for tests
- Platform-specific instructions (Windows/macOS/Linux)
- Keep it actionable and concise

Project Context:
[PASTE STEP 1 ANALYSIS HERE]
```

#### 3b: CONTRIBUTING.md

**Agent Prompt:**
```
Create CONTRIBUTING.md with:

## Required Sections:
1. Contribution types table (7 types with examples)
2. Quick start (Fork → Branch → Changes → Test → Commit → PR)
3. Coding guidelines (Language-specific style guide)
4. Commit message convention (Conventional Commits table)
5. Testing guidelines + coverage goals table
6. Bug report template
7. Feature request template
8. PR checklist
9. Review process

Style:
- Use tables for comparisons
- Include templates in code blocks
- Add emoji for visual breaks
- Link to external resources

Project Context:
[PASTE STEP 1 ANALYSIS HERE]
```

#### 3c: FEATURES.md

**Agent Prompt:**
```
Create docs/FEATURES.md with:

## Required Sections:
1. Table of contents
2. Core features (with status badges ✅ 🚧 📅)
3. Feature details (tables with properties)
4. Analytics/metrics (if applicable)
5. Coming Soon (3-5 features with targets)
6. Roadmap (Version-based timeline)
7. Under Consideration (5-7 ideas)
8. Feature request link

Style:
- Use status badge legend
- Include comparison tables
- Add code examples for technical features
- Version-based roadmap

Project Context:
[PASTE STEP 1 ANALYSIS HERE]
```

#### 3d: LICENSE

**Agent Prompt:**
```
Create LICENSE file with MIT License.

Use standard MIT License text.
Copyright holder: [Project Name]
Year: Current year
```

---

### Step 4: Finalize (5 minutes)

**Goal:** Polish and cross-link documentation

**Agent Prompt:**
```
Review and improve the documentation:

1. **Cross-link all docs**: Add navigation between README, CONTRIBUTING, docs/*
2. **Add documentation index**: Create table in ARCHITECTURE.md or README
3. **Consistency check**: Ensure consistent terminology
4. **Badge validation**: Check all badge URLs work
5. **Code block review**: Verify commands are accurate
6. **Add screenshot placeholders**: Create docs/screenshots/README.md

Output a checklist of fixes needed.
```

---

## 🛠️ Reusable Agent Prompts Library

### Project Analysis Prompts

#### Quick Analysis (Low Token)
```
Analyze this project in 5 bullet points:
1. What it does
2. Main technologies
3. Target platform
4. Current state
5. Key files
```

#### Deep Analysis (Medium Token)
```
Read these files: [list 3-5 key files]

Summarize:
- Architecture pattern
- Dependencies (top 5)
- Entry points
- Test coverage
- Documentation gaps

Output as markdown tables.
```

#### Full Analysis (High Token - Use Sparingly)
```
Complete project audit:

1. Read all config files
2. Map directory structure
3. Identify patterns and conventions
4. List all features
5. Document tech stack
6. Assess code quality
7. Review existing docs

Create comprehensive report with sections.
```

---

### Documentation Generation Prompts

#### README Sections (Modular Approach)

**Header Section:**
```
Create README header with:
- Project name as H1 with emoji
- 4 badges: [Tech], [Version], [License], [Platform]
- One-sentence tagline (bold)
- 5 navigation links

Project: [Name]
Tech: [List]
License: [Type]
```

**Features Section:**
```
List 6 feature categories for [Project Type]:

Format:
### 🎯 Category Name
- **Feature 1** — Description
- **Feature 2** — Description
- **Feature 3** — Description

Project features: [List 15-20 features]
```

**Quick Start:**
```
Write installation steps for [Tech Stack]:

Include:
- Prerequisites with versions
- 5 installation commands
- 1 run command
- 1 build command

Format as code blocks with bash syntax.
```

---

### Improvement Prompts

#### Enhance Existing README
```
Improve this README section:

[PASTE SECTION]

Make it:
- More concise
- Add visual elements (tables, badges)
- Better formatting
- Clearer call-to-actions

Keep same information, better presentation.
```

#### Add Badges
```
Suggest 6-8 relevant badges for this project:

Tech: [List technologies]
Platform: [Target platforms]
License: [Type]
Status: [Development stage]

Use shields.io format.
```

#### Create Comparison Table
```
Create "Traditional vs [Project]" comparison table:

Traditional approach problems: [List 3-5]
Project solutions: [List 3-5]

Format as 2-column markdown table.
```

---

## 📊 Token Optimization Strategies

### 1. Modular Generation

**❌ Expensive:** "Generate complete README in one prompt" (2000+ tokens)

**✅ Efficient:** Generate in sections:
```
1. Header + Intro (500 tokens)
2. Features (500 tokens)
3. Installation (500 tokens)
4. Rest (500 tokens)
```

**Savings:** 40-50% tokens

---

### 2. Reuse Context

**❌ Expensive:** Re-read files for each task

**✅ Efficient:** Read once, reuse analysis:
```
Step 1: Analyze project → Save summary
Step 2: [PASTE summary] + "Create README"
Step 3: [PASTE summary] + "Create CONTRIBUTING"
```

**Savings:** 60-70% tokens

---

### 3. Template-Based

**❌ Expensive:** "Create documentation from scratch"

**✅ Efficient:** "Fill this template with project info":
```
Use this template:
# [Project Name]
[BADGES]
[Tagline]
[Features Section]
...

Fill with: [Project details]
```

**Savings:** 30-40% tokens

---

### 4. Batch Similar Tasks

**❌ Expensive:** Separate prompts for each file

**✅ Efficient:** One prompt for multiple files:
```
Create these 3 files in one response:
1. docs/GETTING_STARTED.md
2. docs/FEATURES.md
3. docs/CONTRIBUTING.md

Use consistent style and cross-linking.
```

**Savings:** 25-35% tokens

---

### 5. Use Agent Hierarchy

**❌ Expensive:** Main agent for everything

**✅ Efficient:** Delegate appropriately:
```
Main Agent: Strategy + final review
Explore Agent: File analysis, structure mapping
Write Agent: Documentation generation
```

**Savings:** 50-60% tokens

---

## 🎯 Complete Workflow Script

Create `generate-docs.sh`:

```bash
#!/bin/bash

# Documentation Generator Workflow
# Usage: ./generate-docs.sh [project-name]

PROJECT_NAME=$1
echo "🚀 Generating documentation for $PROJECT_NAME"

# Step 1: Analysis
echo "📊 Step 1: Analyzing project..."
# Run analysis prompt, save to temp file

# Step 2: README
echo "📝 Step 2: Generating README..."
# Use analysis + README prompt

# Step 3: Supporting Docs
echo "📚 Step 3: Creating supporting documentation..."
# Generate GETTING_STARTED, CONTRIBUTING, FEATURES

# Step 4: Finalize
echo "✨ Step 4: Finalizing..."
# Cross-link, validate, create screenshot guide

echo "✅ Documentation complete!"
echo "📁 Files created:"
echo "   - README.md"
echo "   - CONTRIBUTING.md"
echo "   - LICENSE"
echo "   - docs/GETTING_STARTED.md"
echo "   - docs/FEATURES.md"
echo "   - docs/screenshots/README.md"
```

---

## 📋 Quality Checklist

Use this checklist for every project:

### README.md
- [ ] 4+ badges at top
- [ ] Clear tagline (one sentence)
- [ ] Navigation links
- [ ] What/Why section
- [ ] 6+ feature categories
- [ ] Screenshot placeholders
- [ ] Quick start guide
- [ ] Architecture diagram
- [ ] Tech stack table
- [ ] Roadmap section
- [ ] Contributing guidelines
- [ ] License

### Supporting Docs
- [ ] CONTRIBUTING.md with templates
- [ ] GETTING_STARTED.md with commands
- [ ] FEATURES.md with status badges
- [ ] LICENSE file
- [ ] Screenshot guidelines

### Quality Standards
- [ ] All sections have emoji headers
- [ ] 5+ tables for comparisons
- [ ] 3+ code blocks with commands
- [ ] Cross-linked navigation
- [ ] Consistent terminology
- [ ] 400-600 lines (README)
- [ ] Mobile-friendly formatting

---

## 🎓 Training Examples

### Example 1: Flutter App

**Input:**
```
Project: Fitness Tracker App
Tech: Flutter, Firebase, Provider
Platform: iOS, Android
Features: Workout tracking, nutrition, progress photos
```

**Output:** Use workflow to generate complete docs in 30 minutes.

---

### Example 2: Python Library

**Input:**
```
Project: DataValidator
Tech: Python 3.8+, Pydantic, pytest
Platform: Cross-platform
Features: Schema validation, type checking, custom rules
```

**Output:** Adapt workflow for library documentation.

---

### Example 3: Node.js API

**Input:**
```
Project: TaskAPI
Tech: Node.js, Express, MongoDB
Platform: Cloud (AWS)
Features: CRUD operations, auth, rate limiting
```

**Output:** Focus on API documentation, endpoints, authentication.

---

## 🔁 Repeatable Process

**For each new project:**

1. **Copy this workflow** to your workspace
2. **Run Step 1** analysis prompt
3. **Save analysis** to a variable/file
4. **Execute Steps 2-4** using saved analysis
5. **Review** against quality checklist
6. **Iterate** on specific sections as needed

**Time per project:** 30-45 minutes
**Token cost:** 5000-8000 tokens (vs 20000+ without workflow)
**Quality:** Consistent top 1% documentation

---

## 📞 Quick Reference

### Essential Prompts

| Task | Prompt File | Tokens |
|------|-------------|--------|
| Project Analysis | `prompts/01-analyze.md` | 500 |
| README Generation | `prompts/02-readme.md` | 1500 |
| Getting Started | `prompts/03-start.md` | 1000 |
| Contributing | `prompts/04-contrib.md` | 1200 |
| Features | `prompts/05-features.md` | 1000 |
| Finalize | `prompts/06-finalize.md` | 500 |

**Total:** ~5700 tokens per project

---

## 🎁 Bonus: Copy-Paste Prompt Templates

See `prompts/` folder for ready-to-use templates.

---

**Save this workflow** and use it for every new project to achieve consistent, high-quality documentation! 🚀
