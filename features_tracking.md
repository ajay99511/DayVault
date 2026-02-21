# Features Tracking & Documentation

> **Project**: Memory Palace (DayVault)  
> **Status**: Prototype / MVP Alpha  
> **Last Updated**: 2026-02-11

## Overview
Memory Palace is a futuristic, offline-first journaling and identity tracking application built with Flutter. It focuses on aesthetics (Glassmorphism, animated backgrounds) and structural memory organizing ("Engrams", "Preference Drift").

## 🟢 Implemented Features

### 1. Journaling (The Core)
*   **Dual Modes**:
    *   **Story Mode**: For reflecting on the day. Prompts "How was your day?" and tracks feelings/moods.
    *   **Event Mode**: For logging specific events. Prompts "What happened?" and tracks specific time buckets (Morning, Evening, etc.).
*   **Rich Entry Creation**:
    *   Headline and Content text input.
    *   **Mood Tracking**: 14 distinct mood states (Euphoric, Happy, Melancholic, etc.) with associated icons.
    *   **Image Attachments**: UI for adding images to entries.
    *   **Dynamic UI**: Background gradients change based on entry type (Indigo for Story, Emerald for Event).
*   **Timeline View**:
    *   Vertical timeline connecting entries.
    *   Visual indicators for time and type.

### 2. Time Recall (Calendar)
*   **Visual Calendar**: Month view to see days with activity.
*   **Heatmap-style dots**: Visual markers (Indigo/Emerald dots) indicating creating stories or events on specific days.

### 3. Identity & Preference Drift
*   **Ranking System**: ability to track "favorites" across categories (Movies, Restaurants, Places, People, Books).
*   **Visual Ranking**: Custom gradients for Top 3 items (Gold, Silver, Bronze/Orange).
*   **Concept**: Designed to track how user tastes change over time ("Preference Drift").

### 4. System & Security
*   **Lock Screen**: Numeric keypad with haptic feedback.
*   **Biometric Trigger**: UI button for biometric unlock.
*   **Profile Stats**: "Cognitive Metrics" display (Total Memories, Streak, Clarity).
*   **Security Toggle**: Ability to enable/disable app lock from Profile.

### 5. UI/UX Design System
*   **Glassmorphism**: Extensive use of `GlassContainer` and blur effects.
*   **Animations**: Floating orb backgrounds, page transitions, tactile feedback.
*   **Custom Inputs**: Radial Time Picker (Visual prototype).

---

## 🟡 Limitations & Mocked Functionality
*This section tracks features that are visually implemented but functionally limited or mocked.*

| Feature | Limitation | Status |
| :--- | :--- | :--- |
| **Data Persistence** | **CRITICAL**: No persistent storage. `StorageService` uses in-memory lists. Data is lost on restart. | 🛑 Mock Only |
| **Security** | PIN is hardcoded to `1234`. Biometric button bypasses security immediately without checking hardware. | ⚠️ Insecure |
| **Images** | "Add Photo" button adds random `picsum.photos` URLs. No gallery/camera integration. | 🚧 Placeholder |
| **Calendar** | Hardcoded to display February 2026. Navigation buttons do not change months. | 🚧 Static |
| **Identity** | "Add Item" button in Identity screen does nothing. | 🚧 Incomplete |
| **Time Picker** | Radial Time Picker is a visual demo; gestures do not accurately select time. | 🚧 Visual Only |
| **Profile Stats** | "Streak" and "Clarity" are hardcoded values. | 🚧 Static |

---

## 🔵 Future Recommendations

### Phase 1: Foundation (Stability)
- [ ] **Implement Persistence**: Replace in-memory `StorageService` with `ObjectBox` or `Isar` for fast, offline-first storage.
- [ ] **Real Image Storage**: Implement `image_picker` and save images locally to `ApplicationDocumentsDirectory`.
- [ ] **Dynamic Calendar**: Connect `CalendarScreen` to real data to show actual entry distribution.

### Phase 2: Security & Privacy
- [ ] **Secure Storage**: Implement `flutter_secure_storage` for storing the PIN/Password.
- [ ] **Real Biometrics**: Integrate `local_auth` package for FaceID/TouchID.
- [ ] **Encryption**: Encrypt entry content in the database.

### Phase 3: Enhanced Feature Set
- [ ] **Search**: Full-text search across headlines and content.
- [ ] **Export**: Ability to export journal as Markdown or PDF.
- [ ] **Preference Analytics**: Visualize how rankings change over time (Charts for Identity).
