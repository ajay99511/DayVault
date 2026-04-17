# ✨ Step 4: Finalize & Polish Prompt

**Token Cost:** ~500 tokens  
**Usage:** After completing Steps 1-3

---

## Complete Finalization Prompt

```markdown
Review and finalize all documentation created in previous steps.

## Tasks:

### 1. Cross-Linking

Add navigation between all documents:

**In README.md:**
- Add link to CONTRIBUTING.md
- Add link to docs/GETTING_STARTED.md
- Add link to docs/FEATURES.md
- Add link to docs/ARCHITECTURE.md (if exists)

**In CONTRIBUTING.md:**
- Link to README.md
- Link to docs/GETTING_STARTED.md
- Link to code style guide

**In docs/GETTING_STARTED.md:**
- Link to README.md
- Link to CONTRIBUTING.md
- Link to other docs

**In docs/FEATURES.md:**
- Link to README.md
- Link to relevant technical docs

### 2. Documentation Index

Create or update docs/ARCHITECTURE.md or create docs/README.md with:

```markdown
# 📚 Documentation Index

| Document | Description |
|----------|-------------|
| [README](../README.md) | Main project overview |
| [Getting Started](GETTING_STARTED.md) | Developer onboarding |
| [Features](FEATURES.md) | Feature catalog |
| [Contributing](../CONTRIBUTING.md) | Contribution guidelines |
| [Architecture](ARCHITECTURE.md) | System design |
```

### 3. Consistency Check

Verify:
- [ ] Project name is consistent
- [ ] Terminology is consistent
- [ ] Version numbers match
- [ ] Links work (no 404s)
- [ ] Code blocks use correct syntax highlighting

### 4. Badge Validation

Check all badges:
- [ ] Shields.io URLs are valid
- [ ] Version numbers are current
- [ ] License badge matches LICENSE file
- [ ] Platform badges are accurate

### 5. Code Block Review

Verify all commands:
- [ ] Installation commands are correct
- [ ] Run commands work
- [ ] Test commands are accurate
- [ ] Paths are correct

### 6. Screenshot Guide

Create docs/screenshots/README.md with:

```markdown
# 📸 Screenshot Guide

## Required Screenshots

| Filename | View | Status |
|----------|------|--------|
| view1.png | Main view | ⏳ Pending |
| view2.png | Feature view | ⏳ Pending |

## Guidelines

- Resolution: 1920×1080 minimum
- Format: PNG (lossless)
- Show realistic data
- Include full window

## Capture Commands

```bash
# Windows
Win + Shift + S

# macOS
Cmd + Shift + 4

# Linux
PrintScreen
```
```

### 7. Output Checklist

Provide a report:

```markdown
## Documentation Status

### Files Created
- [ ] README.md
- [ ] CONTRIBUTING.md
- [ ] LICENSE
- [ ] docs/GETTING_STARTED.md
- [ ] docs/FEATURES.md
- [ ] docs/screenshots/README.md

### Quality Checks
- [ ] All badges valid
- [ ] All links work
- [ ] Commands tested
- [ ] Consistent terminology
- [ ] Cross-linked navigation

### Remaining Tasks
1. [Task 1]
2. [Task 2]
3. [Task 3]
```
```

---

## Quick Polish Prompt (Lower Token)

```markdown
Quick documentation polish:

1. **Add cross-links** between README, CONTRIBUTING, and docs/*
2. **Create docs index** table in ARCHITECTURE.md
3. **Verify badges** - check 4 badge URLs
4. **Test commands** - verify 5 key commands work
5. **Create screenshot guide** in docs/screenshots/

Output checklist of what was done + what's remaining.
```

---

## Screenshot Guide Template

```markdown
Create docs/screenshots/README.md:

# 📸 Chronos Planner Screenshots

This folder contains screenshots for documentation.

---

## 📋 Required Screenshots

| Filename | View | Description | Status |
|----------|------|-------------|--------|
| main.png | Main View | Primary interface | ⏳ Pending |
| feature1.png | Feature 1 | Key feature demo | ⏳ Pending |
| feature2.png | Feature 2 | Another feature | ⏳ Pending |

---

## 📷 Screenshot Guidelines

### Best Practices

1. **Clean State** - Use realistic sample data
2. **Consistent Styling** - Same theme across all
3. **High Quality** - Minimum 1920×1080, PNG format
4. **Proper Framing** - Show full window or relevant portion

### Capture Methods

#### Windows
- `Win + Shift + S` - Snip & Sketch
- `Alt + PrintScreen` - Active window

#### macOS
- `Cmd + Shift + 4` - Selected area
- `Cmd + Shift + 4, Space` - Window

#### Linux
- `PrintScreen` - Full screen
- `Alt + PrintScreen` - Active window

---

## 📤 Uploading

1. Save as PNG
2. Optimize with TinyPNG if needed
3. Name properly (descriptive filenames)
4. Update this table with status

---

## 📐 Current Status

| Screenshot | Status | Last Updated |
|------------|--------|--------------|
| main.png | ⏳ Pending | - |
| feature1.png | ⏳ Pending | - |

---

Thank you for contributing screenshots! 📸
```

---

## Quality Assurance Checklist

Use this to verify documentation quality:

```markdown
## README.md Quality

- [ ] 4+ badges at top (tech, license, platform, etc.)
- [ ] Clear one-sentence tagline
- [ ] 5+ navigation links
- [ ] What/Why section with comparison table
- [ ] 6 feature categories with emoji headers
- [ ] Screenshot placeholders (2x2 grid minimum)
- [ ] Prerequisites table
- [ ] 4+ installation steps with commands
- [ ] Build instructions for production
- [ ] Architecture diagram (ASCII art)
- [ ] Design decisions table
- [ ] Tech stack table
- [ ] Key packages/dependencies
- [ ] Documentation index with links
- [ ] Project structure tree
- [ ] Testing guide with commands
- [ ] Roadmap (Coming Soon + Under Consideration)
- [ ] Contributing guidelines (brief + link)
- [ ] License (brief + link)
- [ ] Acknowledgments section
- [ ] Footer with action links

## CONTRIBUTING.md Quality

- [ ] 7 contribution types with examples
- [ ] 6-step quick start for contributors
- [ ] Coding guidelines with examples
- [ ] Commit message convention table
- [ ] Testing guidelines + coverage goals
- [ ] Bug report template
- [ ] Feature request template
- [ ] PR checklist
- [ ] Review process explanation
- [ ] Help/contact links

## GETTING_STARTED.md Quality

- [ ] Prerequisites table (software/version/purpose/download)
- [ ] Platform-specific requirements
- [ ] 5-7 installation steps with commands
- [ ] Verification steps
- [ ] Development workflow guide
- [ ] Testing guide with examples
- [ ] Project structure tree
- [ ] 3-5 common development tasks
- [ ] Troubleshooting table (issues + solutions)
- [ ] Resource links (official docs, community)
- [ ] Next steps section

## FEATURES.md Quality

- [ ] Table of contents
- [ ] Core features with status badges
- [ ] Feature categories (6+)
- [ ] Properties tables
- [ ] Analytics/metrics (if applicable)
- [ ] Coming Soon (3-5 features)
- [ ] Version-based roadmap
- [ ] Under consideration (5-7 ideas)
- [ ] Feature status legend
- [ ] Feature request link

## Overall Quality

- [ ] All documents cross-linked
- [ ] Consistent terminology throughout
- [ ] Consistent formatting (headers, code blocks)
- [ ] Emoji usage consistent (section headers)
- [ ] 5+ tables across all docs
- [ ] 10+ code blocks with commands
- [ ] All links work (no 404s)
- [ ] Badges display correctly
- [ ] LICENSE file exists
- [ ] Screenshot guide created

## Token Efficiency

- [ ] Analysis done once, reused
- [ ] Modular generation (not all-at-once)
- [ ] Templates used (not from scratch)
- [ ] No redundant file re-reading
- [ ] Batch similar tasks

Total files: 6
Total tables: 15+
Total code blocks: 20+
Total emoji sections: 30+
```

---

## Final Output Example

```markdown
## ✅ Documentation Complete!

### Files Created (6/6)
- ✅ README.md (463 lines)
- ✅ CONTRIBUTING.md (350 lines)
- ✅ LICENSE (MIT)
- ✅ docs/GETTING_STARTED.md (400 lines)
- ✅ docs/FEATURES.md (500 lines)
- ✅ docs/screenshots/README.md (100 lines)

### Quality Checks (5/5)
- ✅ All badges valid
- ✅ All links working
- ✅ Commands tested
- ✅ Terminology consistent
- ✅ Cross-linked navigation

### Remaining Tasks
1. 📸 Add 6 screenshots to docs/screenshots/
2. 🧪 Run through all installation steps manually
3. 📝 Add version history to FEATURES.md
4. 🎨 Create social media preview image

### Next Steps
1. Commit all documentation
2. Add to gitignore: docs/prompts/, docs/DOCUMENTATION_WORKFLOW.md
3. Update GitHub repository description
4. Enable GitHub Discussions
```

---

**Usage:** Copy the "Complete Finalization" prompt and send to AI agent after Steps 1-3 are done.
