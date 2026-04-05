# 🚀 DayVault - Quick Start Guide

## Getting Started in 5 Minutes

### Step 1: Install Dependencies
```bash
cd dayvault
flutter pub get
```

### Step 2: Generate Code
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Step 3: Run on Device
```bash
# Android
flutter run

# iOS
flutter run -d ios

# Specific device
flutter devices
flutter run -d <device_id>
```

---

## First Launch Experience

### 1. PIN Setup
When you first launch the app:
1. You'll see the lock screen
2. Enter a 4-6 digit PIN
3. Confirm your PIN
4. ✅ PIN is now securely stored

**Security Tip:** Avoid obvious PINs like `1234` or `0000`

### 2. Biometric Setup (Optional)
If your device supports biometrics:
1. Tap the fingerprint icon
2. Authenticate with your device
3. ✅ Biometrics now enabled for quick access

---

## Creating Your First Journal Entry

### Step 1: Open Journal
- Tap the **Journal** tab at the bottom
- Tap the **+ (FAB)** button in the bottom right

### Step 2: Choose Entry Type
- **Story** (Indigo): Daily reflections
- **Event** (Emerald): Specific moments

### Step 3: Add Content
1. **Mood**: Select how you felt
2. **Feeling** (Story mode): Choose a feeling tag
3. **Time** (Event mode): Select time bucket
4. **Headline**: Add a catchy title
5. **Content**: Write your memory

### Step 4: Add Images (Optional)
1. Tap the camera icon
2. Choose **Camera** or **Gallery**
3. Select/take a photo
4. ✅ Image added to entry

### Step 5: Save
- Tap the **✓** button in the top right
- Or let **auto-save** handle it (saves after 3 seconds)

---

## Local AI Setup (On-Device)

The app now supports two local chat backends:
- **Local GGUF (`llamadart`)**
- **Android AICore (ML Kit Prompt API)**

> Android note: AICore integration requires **API 26+**.

### 1) Import GGUF models in-app
1. Go to **Profile**
2. Tap **AI Model Settings**
3. Tap **Import Chat Model** and/or **Import Embed Model**
4. Activate the desired model from the list

### 2) Configure runtime safely
In **AI Model Settings**, tune:
- Chat engine: `Local GGUF` or `Android AICore`
- Backend: `Auto`, `CPU`, or `Vulkan`
- Low-battery pause for embedding
- Max output tokens

If using **Android AICore**:
- Tap **Check AICore** to view readiness
- Tap **Download AICore** to request model download on-device

### 3) Open the AI assistant
- Go to **Journal**
- Tap the ✨ icon in the header
- Ask questions about your saved memories

### 4) Background indexing behavior
- On every save/edit/delete, an embedding job is queued
- Jobs are processed in background while app is open
- Interrupted jobs resume next launch

---

## Using the Calendar

### View Entries by Month
1. Tap the **Calendar** tab
2. Swipe left/right to change months
3. Tap year to jump to specific year

### Day Details
1. Tap any day with dots
2. View entries for that day
3. Add new entry for that date

**Visual Indicators:**
- 🟢 Emerald dot = Event entry
- 🔵 Indigo dot = Story entry
- Both dots = Both types present

---

## Managing Your Identity Rankings

### Add Favorites
1. Tap the **Identity** tab
2. Select a category (Movies, Books, etc.)
3. Tap the **+** button
4. Add item details:
   - Name (required)
   - Subtitle (director, author, etc.)
   - Rating (0-5 stars)
   - Notes (why it's special)

### Reorder Rankings
- Long press and drag to reorder
- Top 3 get special badges (🥇🥈🥉)

### Create Custom Category
1. Tap the **+** button in category bar
2. Enter category name
3. Toggle "Favourite" if needed
4. ✅ Category created

---

## Backing Up Your Data

### Export Encrypted Backup (Recommended)
1. Go to **Profile** tab
2. Tap **Export Backup**
3. Choose destination (Google Drive, iCloud, etc.)
4. ✅ Backup saved securely

### Export Unencrypted (For Reading)
1. Go to **Profile** tab
2. Tap **Export Unencrypted**
3. Save JSON file
4. ⚠️ Warning: This file is readable by anyone

### Manage Backups
1. Go to **Profile** tab
2. Tap **Manage Backups**
3. View all backups
4. Delete unwanted backups

**Backup Tip:** Export weekly to avoid data loss!

---

## Security Features

### Lock Screen
- Appears on every app launch
- Shows remaining attempts
- 30-second lockout after 5 failed attempts

### Change PIN
Currently, PIN can only be changed by:
1. Export backup
2. Uninstall app
3. Reinstall and import backup
4. Set new PIN

**Note:** This will be improved in future updates

### Biometric Unlock
- Tap fingerprint icon on lock screen
- Authenticate with Face ID / Fingerprint
- ✅ Instant access granted

---

## Tips & Tricks

### Auto-Save
- Entries auto-save every 3 seconds
- Look for the spinning indicator
- Draft recovered if app crashes

### Search
- Tap search icon in Journal
- Type to search headlines and content
- Clear search with X button

### Entry Types
- **Story**: Best for daily reflections
- **Event**: Perfect for specific moments

### Mood Tracking
- 13 moods available
- Visual icons for quick selection
- Track emotional patterns over time

---

## Troubleshooting

### App Won't Start
```bash
flutter clean
flutter pub get
flutter run
```

### Images Not Loading
- Check app permissions
- Grant camera/storage access
- Restart app

### Backup Import Fails
- Ensure file is valid JSON
- Check file isn't corrupted
- Try unencrypted export first

### Biometric Not Working
- Check device settings
- Ensure biometrics enrolled
- Use PIN as fallback

---

## Keyboard Shortcuts (External Keyboard)

| Key | Action |
|-----|--------|
| `Esc` | Go back |
| `Ctrl+S` | Save entry |
| `Enter` | New line |

---

## What's Next?

### Explore Features
- [ ] Create 3 journal entries
- [ ] Add images to entries
- [ ] Set up identity rankings
- [ ] Export your first backup
- [ ] Test biometric unlock

### Advanced Usage
- [ ] Create custom categories
- [ ] Use calendar navigation
- [ ] Try different moods
- [ ] Write long-form entries
- [ ] Organize by tags (coming soon)

---

## Need Help?

### Documentation
- `SECURITY_FEATURES.md` - Security details
- `CHANGELOG.md` - Version history
- `IMPLEMENTATION_SUMMARY.md` - Technical overview

### Common Questions

**Q: Can I recover a forgotten PIN?**  
A: No, PINs cannot be recovered for security reasons. Always export backups!

**Q: Where are my images stored?**  
A: In the app's private documents directory, encrypted and secure.

**Q: Can I use this on multiple devices?**  
A: Yes, export backup from one device and import on another.

**Q: Is my data encrypted?**  
A: Yes, all journal content is encrypted before storage.

---

**Happy Journaling! 🎉**

Remember: **Export backups regularly** to protect your memories!
