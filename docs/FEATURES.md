# ✨ DayVault Features Catalog

Explore the full capabilities of DayVault. This document provides a detailed breakdown of every module and its current status.

---

## 📋 Table of Contents
- [Journaling System](#-journaling-system)
- [Identity Snapshots](#-identity-snapshots)
- [Calendar Recall](#-calendar-recall)
- [Security Suite](#-security-suite)
- [Local AI Assistant](#-local-ai-assistant)
- [System Diagnostics](#-system-diagnostics)
- [Roadmap](#-roadmap)

---

## 📝 Journaling System

The heart of DayVault, designed for effortless and structured capture of your life.

| Feature | Status | Description |
|---------|--------|-------------|
| **Story Mode** | ✅ | Daily long-form reflections with mood tracking. |
| **Event Mode** | ✅ | Capture specific moments with time-bucket classification. |
| **Auto-Save** | ✅ | 3-second debounced background saving to Secure Storage. |
| **Image Attachments** | ✅ | Support for Camera, Gallery, and Remote URLs. |
| **Full-Text Search** | ✅ | Instant search across headlines and content. |
| **Rich Text Editor** | 🚧 | Planned support for Markdown/Formatting. |

### 🎭 Moods & Feelings
Track 14 distinct emotional states including:
- 🌈 **Euphoric**
- ⚡ **Productive**
- 🧘 **Peaceful**
- 🌪️ **Chaos**
- 🌑 **Melancholy**

---

## 👤 Identity Snapshots

Track your "Preference Drift" and see how you evolve over time.

| Feature | Status | Description |
|---------|--------|-------------|
| **Rankings** | ✅ | 0-5 star ratings for movies, books, places, etc. |
| **Drag-to-Reorder** | ✅ | Intuitively manage your top priorities. |
| **Custom Categories** | ✅ | Create your own tracking lists (e.g., "Life Goals"). |
| **Drift Tracking** | ✅ | Visual indicators of how rankings change over time. |
| **Top 3 Badges** | ✅ | Automatic 🥇🥈🥉 badges for top-tier items. |

---

## 📅 Calendar Recall

A visual heatmap of your life's journey.

- **Heatmap Dots**: 🔵 Indigo (Story), 🟢 Emerald (Event).
- **Infinite Scroll**: Powered by `PageController` for zero-lag navigation.
- **Year Picker**: Jump to any point in your history instantly.
- **Contextual Entry**: Add entries directly from the calendar day view.

---

## 🔐 Security Suite

Enterprise-grade protection for your most private thoughts.

| Layer | Technology | Status |
|-------|------------|--------|
| **Authentication** | PBKDF2 (100k iterations) | ✅ |
| **Encryption** | AES-256-CBC | ✅ |
| **Biometrics** | FaceID / Fingerprint | ✅ |
| **Lockout** | Rate limiting (5 attempts) | ✅ |
| **Recovery** | 25-Question Pool (2-of-3) | ✅ |
| **Backups** | Encrypted JSON Export | ✅ |

---

## 🧠 Local AI Assistant

Privacy-first intelligence that lives on your device.

- **Local LLM**: Supports GGUF (via llamadart) and Android AICore.
- **Semantic Search**: Find memories based on meaning, not just keywords.
- **Smart Insights**: Ask questions like "How has my mood been this month?"
- **Low-Battery Pause**: Intelligent background indexing to save power.

---

## ⚙️ System Diagnostics

Real-time health monitoring for your "Identity OS."

- **Battery Health**: Level and state tracking.
- **Memory Usage**: RAM polling every 5 seconds.
- **Device Info**: Complete hardware/software specifications.
- **Secure Keystore Status**: Monitoring of platform security layers.

---

## 🎯 Roadmap

### v1.2.0 (Q2 2026)
- [ ] **Rich Text Support**: Bold, Italics, Lists.
- [ ] **Screenshot Shield**: Prevent data leaks via screenshots.
- [ ] **Mood Trends**: Monthly/Yearly emotional visualization.

### v1.3.0 (Q3 2026)
- [ ] **Cloud Sync**: End-to-end encrypted sync (WebDAV).
- [ ] **Voice Memos**: Transcribed audio entries.
- [ ] **Panic Mode**: Emergency data wipe PIN.

---

<div align="center">
  <p>Suggest a feature by opening an <a href="https://github.com/yourusername/dayvault/issues">Issue</a>!</p>
</div>
