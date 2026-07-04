// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../models/types.dart';
import '../config/constants.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/image_widgets.dart';
import '../services/storage_service.dart';
import '../services/encryption_service.dart';
import '../services/image_service.dart';
import '../services/vault_security_service.dart';
import 'vault_passcode_setup_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class EntryEditor extends ConsumerStatefulWidget {
  final DateTime initialDate;
  final EntryType initialType;
  final JournalEntry? initialEntry;
  final Function(JournalEntry) onSave;
  final VoidCallback onCancel;

  /// Existing tags from the journal, surfaced as quick-add suggestions.
  final List<String> tagSuggestions;

  const EntryEditor({
    super.key,
    required this.initialDate,
    this.initialType = EntryType.story,
    this.initialEntry,
    required this.onSave,
    required this.onCancel,
    this.tagSuggestions = const [],
  });

  @override
  ConsumerState<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends ConsumerState<EntryEditor> {
  late EntryType type;
  late DateTime selectedDate;
  late final TextEditingController _headlineCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _locationCtrl;
  late Mood selectedMood;
  String? selectedFeeling;
  late TimeBucket selectedBucket;
  late List<ImageReference> images;
  late List<String> tags;
  late bool isSpotlight;
  late bool isPrivate;
  bool showTimePicker = false;

  // Auto-save functionality
  Timer? _autoSaveTimer;
  bool _isSaving = false;
  bool _hasChanges = false;

  /// Secure-storage key the in-progress draft is written under. For an existing
  /// entry this is its id (so an interrupted edit is recovered next open); for a
  /// brand-new entry it's a single stable slot — a fresh UUID per open (the old
  /// behavior) meant a saved draft could never be found again.
  late final String _draftId;

  /// Id assigned to a brand-new entry when it is finally saved. Kept separate
  /// from [_draftId] so the stable new-entry draft key is never reused as an
  /// entry id (which would collide across new entries).
  late final String _newEntryId;

  /// Stable draft slot for the "new entry" composer.
  static const _newEntryDraftKey = '__new_entry_draft__';
  static const _autoSaveDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    type = widget.initialEntry?.type ?? widget.initialType;
    selectedDate = widget.initialEntry?.date ?? widget.initialDate;
    _headlineCtrl = TextEditingController(text: widget.initialEntry?.headline ?? '');
    _contentCtrl = TextEditingController(text: widget.initialEntry?.content ?? '');
    _locationCtrl = TextEditingController(
        text: widget.initialEntry?.location?.name ?? '');
    selectedMood = widget.initialEntry?.mood ?? Mood.happy;
    selectedFeeling = widget.initialEntry?.feeling;
    selectedBucket = widget.initialEntry?.timeBucket ?? TimeBucket.morning;
    images = List.from(widget.initialEntry?.images ?? []);
    tags = List.from(widget.initialEntry?.tags ?? const <String>[]);
    isSpotlight = widget.initialEntry?.isSpotlight ?? false;
    // Carried explicitly: the save path below reconstructs the entry from
    // scratch, so dropping this would silently un-vault an edited entry.
    isPrivate = widget.initialEntry?.isPrivate ?? false;
    
    // Draft slot: the entry's id when editing, else the stable new-entry slot.
    _draftId = widget.initialEntry?.id ?? _newEntryDraftKey;
    _newEntryId = widget.initialEntry?.id ?? const Uuid().v4();

    // Recover an interrupted draft for both new and existing entries. When none
    // exists this is a no-op, so a normal open shows the saved content as-is.
    _loadDraft();

    // Setup auto-save listeners
    _setupAutoSave();
  }
  
  void _setupAutoSave() {
    _headlineCtrl.addListener(_onTextChanged);
    _contentCtrl.addListener(_onTextChanged);
    _locationCtrl.addListener(_onTextChanged);
  }

  /// Build the entry's location from the text field. Returns null when blank so
  /// an empty field clears the location. Location is a free-text place name.
  LocationData? _buildLocation() {
    final name = _locationCtrl.text.trim();
    if (name.isEmpty) return null;
    return LocationData(name: name);
  }
  
  void _onTextChanged() => _scheduleAutoSave();

  /// Mark the entry dirty and (re)start the auto-save debounce. Routed through
  /// by every editable field so drafts capture non-text edits too.
  void _scheduleAutoSave() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDelay, _saveDraft);
  }
  
  /// Toggle "Move to Privacy Vault". Turning it ON requires the vault to be
  /// set up first — otherwise the entry would become invisible with no way to
  /// view it, which reads as data loss.
  Future<void> _handlePrivacyToggle(bool v) async {
    if (!v) {
      setState(() => isPrivate = false);
      _scheduleAutoSave();
      return;
    }

    final vault = ref.read(vaultSecurityServiceProvider);
    if (await vault.isPasscodeSet()) {
      setState(() => isPrivate = true);
      _scheduleAutoSave();
      return;
    }

    if (!mounted) return;
    final setupDone = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VaultPasscodeSetupScreen()),
    );
    if (setupDone == true && mounted) {
      setState(() => isPrivate = true);
      _scheduleAutoSave();
    }
  }

  Future<void> _saveDraft() async {
    if (!_hasChanges || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final draftData = {
        'id': _draftId,
        'type': type.index,
        'date': selectedDate.toIso8601String(),
        'headline': _headlineCtrl.text,
        'content': _contentCtrl.text,
        'mood': selectedMood.index,
        'feeling': selectedFeeling,
        'location': _buildLocation()?.toJson(),
        'timeBucket': selectedBucket.index,
        'images': images.map((img) => img.toJson()).toList(),
        'tags': tags,
        'isSpotlight': isSpotlight,
        'isPrivate': isPrivate,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final draftJson = jsonEncode(draftData);

      // StorageService.saveDraft encrypts the payload at rest in secure storage.
      await ref
          .read(storageServiceProvider)
          .saveDraft(_draftId, draftJson);

      if (mounted) {
        setState(() {
          _hasChanges = false;
          _isSaving = false;
        });
      }
    } catch (e) {
      debugPrint('Auto-save failed: $e');
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _loadDraft() async {
    try {
      final draftJson = await ref
          .read(storageServiceProvider)
          .getDraft(_draftId);

      if (draftJson != null) {
        // Try to decrypt in case old drafts were encrypted
        String plainJson;
        try {
          plainJson = await EncryptionService().decrypt(draftJson);
        } catch (_) {
          plainJson = draftJson; // Not encrypted, use as-is
        }

        final draftData = jsonDecode(plainJson) as Map<String, dynamic>;

        if (mounted) {
          setState(() {
            type = EntryType.values[draftData['type'] as int];
            final draftDate = draftData['date'] as String?;
            if (draftDate != null) {
              selectedDate = DateTime.tryParse(draftDate) ?? selectedDate;
            }
            _headlineCtrl.text = draftData['headline'] as String;
            _contentCtrl.text = draftData['content'] as String;
            selectedMood = Mood.values[draftData['mood'] as int];
            selectedFeeling = draftData['feeling'] as String?;
            final loc = draftData['location'] as Map<String, dynamic>?;
            _locationCtrl.text = loc != null ? (loc['name'] as String? ?? '') : '';
            selectedBucket = TimeBucket.values[draftData['timeBucket'] as int];
            images = _parseDraftImages(draftData['images'] as List?);
            tags = (draftData['tags'] as List?)
                    ?.map((e) => e as String)
                    .toList() ??
                <String>[];
            isSpotlight = draftData['isSpotlight'] as bool? ?? false;
            isPrivate = draftData['isPrivate'] as bool? ?? false;
          });

          // Show recovery message
          _showDraftRecoveredSnackbar();
        }
      }
    } catch (e) {
      debugPrint('Load draft failed: $e');
    }
  }
  
  void _showDraftRecoveredSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Unsaved draft recovered'),
        backgroundColor: AppColors.indigo500,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'DISCARD',
          textColor: Colors.white,
          onPressed: () async {
            await ref.read(storageServiceProvider).deleteDraft(_draftId);
          },
        ),
      ),
    );
  }
  
  Future<void> _clearDraft() async {
    await ref.read(storageServiceProvider).deleteDraft(_draftId);
    _autoSaveTimer?.cancel();
  }

  void handleSave() async {
    if (_headlineCtrl.text.isEmpty) {
      _showError('Please add a headline for your entry');
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      final entry = JournalEntry(
        id: widget.initialEntry?.id ?? _newEntryId,
        type: type,
        date: selectedDate,
        headline: _headlineCtrl.text,
        content: _contentCtrl.text,
        mood: selectedMood,
        feeling: selectedFeeling,
        location: _buildLocation(),
        timeBucket: type == EntryType.event ? selectedBucket : null,
        images: images,
        tags: tags,
        isSpotlight: isSpotlight,
        isPrivate: isPrivate,
      );
      
      await widget.onSave(entry);
      
      // Clear draft after successful save
      await _clearDraft();
      
      if (mounted) {
        setState(() => _isSaving = false);
      }
    } catch (e) {
      debugPrint('Save failed: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        _showError('Failed to save entry. Please try again.');
      }
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.rose500,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _headlineCtrl.removeListener(_onTextChanged);
    _contentCtrl.removeListener(_onTextChanged);
    _locationCtrl.removeListener(_onTextChanged);
    _headlineCtrl.dispose();
    _contentCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Dynamic Background Gradients
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: type == EntryType.story
                    ? [
                        AppColors.indigo500.withValues(alpha: 0.2),
                        AppColors.rose500.withValues(alpha: 0.1),
                      ]
                    : [
                        AppColors.emerald500.withValues(alpha: 0.2),
                        AppColors.amber500.withValues(alpha: 0.1),
                      ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ResponsiveCenter(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        // Date — tap to change (backfill / correct the date).
                        GestureDetector(
                          onTap: _pickDate,
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${_getWeekday(selectedDate.weekday)}, ${selectedDate.day}",
                                style: const TextStyle(
                                  color: AppColors.slate400,
                                  letterSpacing: 2,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.edit_calendar,
                                  size: 14, color: AppColors.slate400),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Prompt
                        Text(
                          type == EntryType.story
                              ? "How was your day?"
                              : "What happened?",
                          style: GoogleFonts.libreBaskerville(
                            color: Colors.white,
                            fontSize: 32,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Mode Specific Controls
                        if (type == EntryType.story) _buildStoryFeelings(),
                        if (type == EntryType.event) _buildEventControls(),

                        const SizedBox(height: 30),

                        // Inputs
                        TextField(
                          controller: _headlineCtrl,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Headline...',
                            hintStyle: const TextStyle(color: Colors.white24),
                            border: InputBorder.none,
                            suffixIcon: _hasChanges
                                ? _AutoSaveIndicator(isSaving: _isSaving)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _contentCtrl,
                          maxLines: null,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: type == EntryType.story
                                ? 'Reflect on the moments, lessons, and joy...'
                                : 'Details, people, vibes...',
                            hintStyle: const TextStyle(color: Colors.white12),
                            border: InputBorder.none,
                          ),
                        ),

                        const SizedBox(height: 30),
                        _buildLocationField(),
                        const SizedBox(height: 30),
                        TagPicker(
                          tags: tags,
                          suggestions: widget.tagSuggestions,
                          onChanged: (next) {
                            setState(() => tags = next);
                            _scheduleAutoSave();
                          },
                        ),
                        const SizedBox(height: 20),
                        SpotlightToggle(
                          value: isSpotlight,
                          onChanged: (v) {
                            setState(() => isSpotlight = v);
                            _scheduleAutoSave();
                          },
                        ),
                        const SizedBox(height: 12),
                        PrivacyVaultToggle(
                          value: isPrivate,
                          onChanged: _handlePrivacyToggle,
                        ),
                        const SizedBox(height: 30),
                        ImageSection(
                          images: images,
                          onChanged: (next) {
                            setState(() => images = next);
                            _scheduleAutoSave();
                          },
                          onError: _showError,
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (showTimePicker) _buildRadialTimePickerOverlay(),
        ],
      ),
    );
  }

  String _getWeekday(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  /// Let the user change the entry's date (e.g. backfilling a past day). The
  /// time-of-day component is preserved so entry ordering stays stable. The
  /// picker is forced dark to match the always-dark editor surface.
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      // Allow today plus a little headroom for near-future events without
      // tripping the picker's initialDate<=lastDate assertion.
      lastDate: selectedDate.isAfter(now) ? selectedDate : now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.indigo500,
            onPrimary: Colors.white,
            surface: AppColors.slate900,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      selectedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        selectedDate.hour,
        selectedDate.minute,
        selectedDate.second,
      );
    });
    _scheduleAutoSave();
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white54),
            onPressed: () async {
              // Save draft before closing if there are changes
              if (_hasChanges) {
                await _saveDraft();
              }
              widget.onCancel();
            },
          ),
          // Type Switcher
          GlassContainer(
            borderRadius: 30,
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _typeButton('Story', EntryType.story),
                _typeButton('Event', EntryType.event),
              ],
            ),
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.emerald500,
                    ),
                  )
                : const Icon(Icons.check, color: AppColors.emerald500),
            onPressed: _isSaving ? null : handleSave,
          ),
        ],
      ),
    );
  }

  Widget _typeButton(String label, EntryType t) {
    bool isActive = type == t;
    return GestureDetector(
      onTap: () => setState(() => type = t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (t == EntryType.story
                  ? AppColors.indigo500
                  : AppColors.emerald500)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// Free-form place input. Backs the `location` field that the journal card
  /// and viewer already display.
  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(
            color: AppColors.slate400,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _locationCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'Add a place…',
            hintStyle: const TextStyle(color: Colors.white38),
            isDense: true,
            prefixIcon: const Icon(Icons.location_on_outlined,
                color: AppColors.emerald500, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildStoryFeelings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mood is now editable for stories too (previously only events could
        // set it, so every story silently defaulted to "happy").
        MoodSelector(
          selected: selectedMood,
          onChanged: (m) {
            setState(() => selectedMood = m);
            _scheduleAutoSave();
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: essentialFeelings.map((f) {
              bool isSel = selectedFeeling == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  // Tap again to clear the feeling.
                  onTap: () {
                    setState(() => selectedFeeling = isSel ? null : f);
                    _scheduleAutoSave();
                  },
                  child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSel
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                    child: Text(
                      f,
                      style: TextStyle(
                        color: isSel ? AppColors.indigo500 : Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEventControls() {
    return Row(
      children: [
        // Time Trigger
        GestureDetector(
          onTap: () => setState(() => showTimePicker = true),
          child: GlassContainer(
            borderRadius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.emerald500.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppColors.emerald500,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "TIME",
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white54,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      timeBucketLabel(selectedBucket),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Moods
        Expanded(
          child: MoodSelector(
            selected: selectedMood,
            onChanged: (m) {
              setState(() => selectedMood = m);
              _scheduleAutoSave();
            },
          ),
        ),
      ],
    );
  }

  /// Parse images from draft data (backward compatible).
  List<ImageReference> _parseDraftImages(List? rawImages) {
    if (rawImages == null || rawImages.isEmpty) return [];

    final first = rawImages.first;
    if (first is Map && first.containsKey('source')) {
      // New format: ImageReference JSON
      return rawImages
          .map((m) => ImageReference.fromJson(m as Map<String, dynamic>))
          .toList();
    } else if (first is String) {
      // Old format: plain file paths
      return rawImages
          .map((path) => ImageReference(
                source: path as String,
                type: ImageSourceType.filePath,
              ))
          .toList();
    }
    return [];
  }

  Widget _buildRadialTimePickerOverlay() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => showTimePicker = false),
          child: Container(color: Colors.black87),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: GlassContainer(
              borderRadius: 32,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "When did it happen?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...TimeBucket.values.map(_buildTimeBucketOption),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// A single selectable row in the time-of-day picker.
  Widget _buildTimeBucketOption(TimeBucket bucket) {
    final isSel = selectedBucket == bucket;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedBucket = bucket;
            showTimePicker = false;
          });
          _scheduleAutoSave();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSel
                ? AppColors.emerald500.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSel ? AppColors.emerald500 : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Icon(
                timeBucketIcon(bucket),
                size: 18,
                color: isSel ? AppColors.emerald500 : Colors.white54,
              ),
              const SizedBox(width: 12),
              Text(
                timeBucketLabel(bucket),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (isSel)
                const Icon(Icons.check,
                    size: 18, color: AppColors.emerald500),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small auto-save status chip shown in the headline field's suffix.
class _AutoSaveIndicator extends StatelessWidget {
  final bool isSaving;
  const _AutoSaveIndicator({required this.isSaving});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSaving)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.emerald500,
              ),
            )
          else
            const Icon(Icons.edit, color: AppColors.amber500, size: 18),
        ],
      ),
    );
  }
}

/// Horizontal emoji mood picker.
class MoodSelector extends StatelessWidget {
  final Mood selected;
  final ValueChanged<Mood> onChanged;
  const MoodSelector({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: moodIcons.entries.map((e) {
          final isSel = selected == e.key;
          return GestureDetector(
            onTap: () => onChanged(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSel ? AppColors.emerald500 : AppColors.slate900,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSel ? AppColors.emerald500 : Colors.white12,
                ),
              ),
              alignment: Alignment.center,
              child: Text(e.value, style: const TextStyle(fontSize: 20)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Free-form tag input with removable chips.
class TagPicker extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  /// Known tags from the rest of the journal, offered as quick-add suggestions
  /// so the user reuses an existing tag instead of creating a near-duplicate.
  final List<String> suggestions;

  const TagPicker({
    super.key,
    required this.tags,
    required this.onChanged,
    this.suggestions = const [],
  });

  @override
  State<TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<TagPicker> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    // Normalize: collapse whitespace; ignore case-insensitive duplicates.
    final tag = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    final exists =
        widget.tags.any((t) => t.toLowerCase() == tag.toLowerCase());
    if (!exists) {
      widget.onChanged([...widget.tags, tag]);
    }
    _ctrl.clear();
    setState(() {}); // refresh suggestion list
  }

  void _add() => _addTag(_ctrl.text);

  void _remove(String tag) {
    widget.onChanged(widget.tags.where((t) => t != tag).toList());
  }

  /// Suggestions not yet added, matching the current input substring. Capped so
  /// the editor never floods with chips.
  List<String> _visibleSuggestions() {
    final added = widget.tags.map((t) => t.toLowerCase()).toSet();
    final q = _ctrl.text.trim().toLowerCase();
    return widget.suggestions
        .where((s) => !added.contains(s.toLowerCase()))
        .where((s) => q.isEmpty || s.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tags',
          style: TextStyle(
            color: AppColors.slate400,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                // Re-filter suggestions as the user types.
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Add a tag…',
                  hintStyle: const TextStyle(color: Colors.white38),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _add,
              icon: const Icon(Icons.add_circle, color: AppColors.indigo500),
              tooltip: 'Add tag',
            ),
          ],
        ),
        // Quick-add suggestions drawn from the user's existing tags.
        if (_visibleSuggestions().isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _visibleSuggestions().map((s) {
              return ActionChip(
                label: Text(s,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
                avatar: const Icon(Icons.add, size: 14, color: Colors.white54),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                onPressed: () => _addTag(s),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
        if (widget.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.tags.map((tag) {
              return Chip(
                label: Text(tag,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: AppColors.indigo500.withValues(alpha: 0.2),
                side: BorderSide(
                    color: AppColors.indigo500.withValues(alpha: 0.4)),
                deleteIcon: const Icon(Icons.close, size: 14),
                deleteIconColor: Colors.white70,
                onDeleted: () => _remove(tag),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// Toggle that marks an entry as a spotlight memory.
class SpotlightToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const SpotlightToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? AppColors.amber500.withValues(alpha: 0.5)
                : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              value ? Icons.star : Icons.star_border,
              color: value ? AppColors.amber500 : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Spotlight this memory',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.amber500,
            ),
          ],
        ),
      ),
    );
  }
}

/// Same pattern as [SpotlightToggle]: controlled switch tile for moving the
/// entry into the Privacy Vault (hidden everywhere outside the vault).
class PrivacyVaultToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const PrivacyVaultToggle(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? AppColors.fuchsia500.withValues(alpha: 0.5)
                : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              value ? Icons.shield_moon : Icons.shield_moon_outlined,
              color: value ? AppColors.fuchsia500 : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Move to Privacy Vault',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.fuchsia500,
            ),
          ],
        ),
      ),
    );
  }
}

/// Image picker + preview + reorder section. Controlled: it never owns the
/// list, it reports a new list via [onChanged]. Images are stored by reference
/// only (no copying into app storage).
class ImageSection extends StatefulWidget {
  final List<ImageReference> images;
  final ValueChanged<List<ImageReference>> onChanged;
  final void Function(String message) onError;

  const ImageSection({
    super.key,
    required this.images,
    required this.onChanged,
    required this.onError,
  });

  @override
  State<ImageSection> createState() => _ImageSectionState();
}

class _ImageSectionState extends State<ImageSection> {
  List<ImageReference> get _images => widget.images;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Images',
          style: TextStyle(
            color: AppColors.slate400,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _addImageButton(Icons.link, 'URL', _addFromUrl),
            const SizedBox(width: 8),
            _addImageButton(Icons.folder_open, 'Files', _pickFromFile),
          ],
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final previewHeight =
                  (constraints.maxWidth * 9 / 16).clamp(120.0, 250.0);
              return SizedBox(
                height: previewHeight,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ImageThumbnailWidget(
                          imageRef: _images.last,
                          fit: BoxFit.cover,
                          showTapToZoom: true,
                        ),
                      ),
                    ),
                    // Remove the previewed image. Reference-only: this drops the
                    // image from the entry; the source file on the device is
                    // never touched. Always available so single-image entries
                    // can be cleared (the thumbnail strip below only appears
                    // when there is more than one image).
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.transparent,
                        child: GestureDetector(
                          onTap: () => _removeAt(_images.length - 1),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.rose500,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        if (_images.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 76,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              onReorder: _reorder,
              buildDefaultDragHandles: false,
              itemBuilder: (context, index) {
                return Padding(
                  key: ValueKey('${_images[index].source}_$index'),
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 68,
                    height: 68,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: GestureDetector(
                              onTap: () => _moveToEnd(index),
                              child: ImageThumbnailWidget(
                                imageRef: _images[index],
                                fit: BoxFit.cover,
                                showTapToZoom: true,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Material(
                            color: Colors.transparent,
                            child: GestureDetector(
                              onTap: () => _removeAt(index),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.rose500,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 3,
                          left: 3,
                          child: Icon(
                            Icons.drag_indicator,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _addImageButton(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withValues(alpha: 0.05),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white54, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reorder(int oldIndex, int newIndex) {
    final list = [..._images];
    if (oldIndex < newIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    widget.onChanged(list);
  }

  void _removeAt(int index) {
    final list = [..._images]..removeAt(index);
    widget.onChanged(list);
  }

  /// Move an image to the end so it becomes the preview.
  void _moveToEnd(int index) {
    final list = [..._images];
    final item = list.removeAt(index);
    list.add(item);
    widget.onChanged(list);
  }

  /// Add image from URL with validation.
  Future<void> _addFromUrl() async {
    final urlCtrl = TextEditingController();
    String? error;
    bool isValidating = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.slate900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Add Image from URL',
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: urlCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'https://example.com/image.jpg',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      errorText: error,
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  if (isValidating)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isValidating
                      ? null
                      : () async {
                          final url = urlCtrl.text.trim();
                          if (url.isEmpty) {
                            setDialogState(() => error = 'URL cannot be empty');
                            return;
                          }
                          setDialogState(() {
                            error = null;
                            isValidating = true;
                          });
                          final (valid, errMsg) = await validateImageUrl(url);
                          setDialogState(() => isValidating = false);
                          if (!valid) {
                            setDialogState(() => error = errMsg);
                            return;
                          }
                          if (mounted) {
                            widget.onChanged([..._images, createUrlImageRef(url)]);
                            Navigator.pop(ctx);
                          }
                        },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Pick image from file system using file_picker (no copy, just path reference).
  Future<void> _pickFromFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null && mounted) {
        widget.onChanged(
            [..._images, createFileImageRef(result.files.single.path!)]);
      }
    } catch (e) {
      debugPrint('File pick failed: $e');
      if (mounted) {
        widget.onError('Failed to pick image file. Please try again.');
      }
    }
  }
}
