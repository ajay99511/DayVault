# DayVault: Lib Architecture & Advanced Initialization Plan

## Overview of `lib` Directory
The `lib` directory contains the core logic, UI, and state management for DayVault. Currently, the application uses an in-memory storage approach. Below is the documentation of the main components:

### 1. Configurations (`lib/config/`)
* **`constants.dart`**: Contains the visual design system definitions, mostly colors (`AppColors.slate950`, `AppColors.indigo500`, etc.) mapping to the app's dark sci-fi aesthetic.

### 2. Models (`lib/models/`)
* **`types.dart`**: Defines the core data structures used throughout the app:
  * `Mood` (enum): 14 distinct moods (euphoric, happy, etc.).
  * `TimeBucket` (enum): Specific times of day (morning, evening, etc.).
  * `EntryType` (enum): `story` or `event`.
  * `LocationData`: Standard lat/lng and name for geo-tagging.
  * `JournalEntry`: Core domain model for storing entries, containing text, mood, tags, location, images, and time details.
  * `RankedItem` & `RankingCategory`: Models for tracking "Preference Drift" and identity metrics.
  * `UserSettings`: Tracks `securityEnabled`, `username`, and `theme`.

### 3. Services (`lib/services/`)
* **`storage_service.dart`**: The central repository for data access. **Currently uses mock, in-memory lists** (`_mockEntries`, `_mockCategories`). Data in `StorageService` is destroyed every time the app closes. 

### 4. UI Components (`lib/widgets/ & lib/screens/`)
* **`glass_widgets.dart`**: Contains reusable `GlassContainer` widgets for the app's signature Glassmorphism look.
* **`main.dart`**: The entry point. Initializes `MemoryPalaceApp`, handles routing, and contains the `RootOrchestrator` to manage auth/lock states.
* **Screens**:
  * `journal_screen.dart` (Journal Timeline)
  * `calendar_screen.dart` (Recall View)
  * `identity_screen.dart` (Preference lists)
  * `profile_screen.dart` (User Profile / Stats)
  * `lock_screen.dart` (Security PIN entry)
  * `entry_editor.dart` (Creating new entries)

---

## Next Initialization: Advanced Local Storage Plan
To ensure DayVault **saves data locally** and persists across sessions, the next initialization phase must integrate a local database. The current `StorageService` interface is already asynchronous (`Future`), which makes dropping in a database seamless.

### Recommended Technology: **Isar** or **ObjectBox**
Given the need for fast, offline-first performance with complex querying on dates and moods, a NoSQL database tailored for Flutter like Isar or ObjectBox is optimal.

### Phase 1: Model Migration
1. **Convert Data Classes**: Add annotations to classes in `models/types.dart` (e.g., `@collection` for Isar).
2. **Handle Enums**: Ensure enums (`Mood`, `TimeBucket`) are stored effectively (usually as integer indices or strings).

### Phase 2: Storage Service Refactoring
1. **Initialize Database**: In `main.dart` (`main()` method), add `await StorageService.initialize()` before `runApp`.
2. **Replace Mocks**: Inside `StorageService`:
   * Replace `_mockEntries` with actual DB read queries.
   * `saveJournalEntry()`: `db.writeTxn(() => db.journalEntries.put(entry))`
   * `getJournal()`: Return sorted list from the DB.
   * Do the same for `RankingCategory` and `UserSettings`.

### Phase 3: Files & Assets (Images)
* The `JournalEntry.images` is currently a list of strings (`picsum.photos` URLs). 
* To save images locally, integrate the `path_provider` package to get the `ApplicationDocumentsDirectory`.
* Save picked images to the local directory, and store the **local file path** as the string in `images`.

### Phase 4: Validating Security
* Local persistence means data is now on disk. If `securityEnabled` is true in `UserSettings`, consider encrypting sensitive entries. Isar and ObjectBox support encrypted databases, though we can also use `flutter_secure_storage` to store encryption keys or the PIN securely instead of plaintext.

By implementing this architecture, DayVault will successfully transition from a volatile prototype into a persistent, production-ready application.
