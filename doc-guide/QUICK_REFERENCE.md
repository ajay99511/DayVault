# 🎯 Quick Reference: Documentation Workflow

**One-page cheat sheet** for generating top 1% GitHub documentation.

---

## 📋 The 4-Step Process

| Step | Prompt | Tokens | Time | Output |
|------|--------|--------|------|--------|
| **1. Analyze** | `01-analyze.md` | 500 | 5 min | Project summary table |
| **2. README** | `02-readme.md` | 1500 | 10 min | README.md (400-600 lines) |
| **3. Docs** | `03-docs.md` | 2500 | 15 min | 3 supporting docs |
| **4. Finalize** | `04-finalize.md` | 500 | 5 min | Cross-linked, polished |

**Total:** ~5000 tokens, 35 minutes

---

## 🚀 Quick Start Commands

```bash
# For each new project:

# Step 1: Analyze
# Copy prompts/01-analyze.md → Paste to agent → Save output

# Step 2: README  
# Copy prompts/02-readme.md → Paste with Step 1 output → Save README.md

# Step 3: Supporting Docs
# Copy prompts/03-docs.md → Paste with Step 1 output → Save 3 files

# Step 4: Finalize
# Copy prompts/04-finalize.md → Review output → Fix issues

# Done! ✅
```

---

## 📁 File Structure

```
project/
├── README.md                    # Generated in Step 2
├── CONTRIBUTING.md              # Generated in Step 3
├── LICENSE                      # Generated in Step 3
├── docs/
│   ├── GETTING_STARTED.md       # Generated in Step 3
│   ├── FEATURES.md              # Generated in Step 3
│   ├── ARCHITECTURE.md          # Existing or generated
│   ├── screenshots/
│   │   └── README.md            # Generated in Step 4
│   └── prompts/                 # Keep for reuse
│       ├── 01-analyze.md
│       ├── 02-readme.md
│       ├── 03-docs.md
│       └── 04-finalize.md
└── docs-workflow.md             # This file
```

---

## 🎯 Essential Prompts (Copy-Paste)

### Prompt 1: Analysis
```
Analyze this project:
1. Project Name & Type
2. Tech Stack (top 5)
3. Entry Points
4. Key Features (5-10)
5. Current State

Read: package config + main file + README
Output as markdown table.
```

### Prompt 2: README
```
Create README.md with:
- Header with 4 badges
- Tagline + navigation
- What/Why comparison table
- 6 feature categories
- Quick start (prerequisites + install)
- Architecture diagram
- Tech stack table
- Roadmap
- Contributing + License

Project: [PASTE STEP 1 ANALYSIS]
```

### Prompt 3: Docs
```
Create 3 files:

1. docs/GETTING_STARTED.md
   - Prerequisites table
   - Installation steps (5-7)
   - Development workflow
   - Testing guide
   - Troubleshooting

2. CONTRIBUTING.md
   - Contribution types
   - Quick start (fork → PR)
   - Coding guidelines
   - Commit convention
   - PR template

3. docs/FEATURES.md
   - Feature catalog
   - Status badges
   - Roadmap
   - Under consideration

Project: [PASTE STEP 1 ANALYSIS]
```

### Prompt 4: Finalize
```
Review and finalize:
1. Cross-link all docs
2. Create documentation index
3. Verify badges (check URLs)
4. Test commands (run 5 key commands)
5. Create screenshot guide

Output checklist of fixes needed.
```

---

## ✅ Quality Checklist

### README.md (15 checks)
- [ ] 4+ badges
- [ ] One-sentence tagline
- [ ] 5+ navigation links
- [ ] Comparison table
- [ ] 6 feature categories
- [ ] Screenshot placeholders
- [ ] Prerequisites
- [ ] 4+ install steps
- [ ] Architecture diagram
- [ ] Tech stack table
- [ ] Project structure
- [ ] Roadmap
- [ ] Contributing link
- [ ] License
- [ ] Footer

### Supporting Docs (4 files)
- [ ] CONTRIBUTING.md with templates
- [ ] GETTING_STARTED.md with commands
- [ ] FEATURES.md with roadmap
- [ ] LICENSE file

### Overall
- [ ] All docs cross-linked
- [ ] Consistent emoji usage
- [ ] 5+ tables total
- [ ] 10+ code blocks
- [ ] All links work

---

## 💡 Token Optimization Tips

### ✅ DO (Efficient)
- Analyze once, reuse output
- Generate in modules (sections)
- Use templates (fill in blanks)
- Batch similar tasks
- Save intermediate results

### ❌ DON'T (Wasteful)
- Re-read files repeatedly
- Generate all-at-once (huge prompts)
- Start from scratch each time
- Mix unrelated tasks
- Skip saving analysis

---

## 🎓 Example Workflow

### Project: Flutter Todo App

**Step 1: Analysis** (5 min)
```
Agent reads: pubspec.yaml, lib/main.dart
Output: Table with Flutter, Provider, SQLite, etc.
```

**Step 2: README** (10 min)
```
Agent uses Step 1 output
Generates: 450-line README with badges, features, architecture
```

**Step 3: Docs** (15 min)
```
Agent generates:
- GETTING_STARTED.md (Flutter setup)
- CONTRIBUTING.md (Dart guidelines)
- FEATURES.md (Todo features + roadmap)
- LICENSE (MIT)
```

**Step 4: Finalize** (5 min)
```
Agent:
- Links all docs together
- Creates screenshot guide
- Outputs checklist
```

**Result:** Professional documentation in 35 minutes!

---

## 🔁 Reuse for Every Project

This workflow works for:
- ✅ Flutter apps
- ✅ Python libraries
- ✅ Node.js APIs
- ✅ React web apps
- ✅ CLI tools
- ✅ Any GitHub project

**Just:**
1. Copy prompts/ folder to new project
2. Run 4-step process
3. Customize as needed

---

## 📊 Token Budget

| Project Size | Tokens | Time | Files |
|--------------|--------|------|-------|
| **Small** (library) | 3000 | 20 min | 3 |
| **Medium** (app) | 5000 | 35 min | 6 |
| **Large** (platform) | 8000 | 60 min | 10+ |

**Average:** 5000 tokens = $0.01-0.02 (depending on provider)

---

## 🎁 Bonus: One-Liner Prompts

For quick tasks:

**Add badges:**
```
Suggest 6 badges for [project] using shields.io format.
```

**Create comparison:**
```
Traditional vs [Project] comparison table (3 rows).
```

**Write features:**
```
List 18 features in 6 categories with emoji headers.
```

**Fix formatting:**
```
Improve this section: [paste]. Make it concise with tables.
```

---

## 📞 When to Use What

| Need | Use This |
|------|----------|
| New project docs | Full 4-step workflow |
| Update README only | Step 2 + Step 4 |
| Add contribution guide | Step 3b + Step 4 |
| Quick polish | Step 4 only |
| Single section | One-liner prompts |

---

## 🏆 Success Metrics

After completing workflow, you should have:

- ✅ README.md (400-600 lines)
- ✅ 3+ supporting docs
- ✅ 15+ tables
- ✅ 20+ code blocks
- ✅ 30+ emoji headers
- ✅ All cross-linked
- ✅ Professional quality

**Benchmark:** Compare to top GitHub repos (10k+ stars)

---

**Save this file** and use it as your quick reference! 🚀

For detailed instructions, see `DOCUMENTATION_WORKFLOW.md`.
