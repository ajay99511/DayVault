import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/types.dart';
import '../config/constants.dart';
import '../widgets/glass_widgets.dart';
import '../services/storage_service.dart';
import '../services/encryption_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class EntryEditor extends ConsumerStatefulWidget {
  final DateTime initialDate;
  final EntryType initialType;
  final JournalEntry? initialEntry;
  final Function(JournalEntry) onSave;
  final VoidCallback onCancel;

  const EntryEditor({
    super.key,
    required this.initialDate,
    this.initialType = EntryType.story,
    this.initialEntry,
    required this.onSave,
    required this.onCancel,
  });

  @override
  ConsumerState<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends ConsumerState<EntryEditor> {
  late EntryType type;
  late final TextEditingController _headlineCtrl;
  late final TextEditingController _contentCtrl;
  late Mood selectedMood;
  String? selectedFeeling;
  late TimeBucket selectedBucket;
  late List<String> images;
  bool showTimePicker = false;

  // Auto-save functionality
  Timer? _autoSaveTimer;
  bool _isSaving = false;
  bool _hasChanges = false;
  String? _draftId;
  static const _autoSaveDelay = Duration(seconds: 3);

  // Image picker
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    type = widget.initialEntry?.type ?? widget.initialType;
    _headlineCtrl = TextEditingController(text: widget.initialEntry?.headline ?? '');
    _contentCtrl = TextEditingController(text: widget.initialEntry?.content ?? '');
    selectedMood = widget.initialEntry?.mood ?? Mood.happy;
    selectedFeeling = widget.initialEntry?.feeling;
    selectedBucket = widget.initialEntry?.timeBucket ?? TimeBucket.morning;
    images = List.from(widget.initialEntry?.images ?? []);
    
    // Set draft ID for existing or new entries
    _draftId = widget.initialEntry?.id ?? const Uuid().v4();
    
    // Load any existing draft for new entries
    if (widget.initialEntry == null) {
      _loadDraft();
    }
    
    // Setup auto-save listeners
    _setupAutoSave();
  }
  
  void _setupAutoSave() {
    _headlineCtrl.addListener(_onTextChanged);
    _contentCtrl.addListener(_onTextChanged);
  }
  
  void _onTextChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
    
    // Cancel existing timer
    _autoSaveTimer?.cancel();
    
    // Start new timer for auto-save
    _autoSaveTimer = Timer(_autoSaveDelay, _saveDraft);
  }
  
  Future<void> _saveDraft() async {
    if (!_hasChanges || _isSaving) return;
    
    setState(() => _isSaving = true);
    
    try {
      final draftData = {
        'id': _draftId,
        'type': type.index,
        'date': widget.initialDate.toIso8601String(),
        'headline': _headlineCtrl.text,
        'content': _contentCtrl.text,
        'mood': selectedMood.index,
        'feeling': selectedFeeling,
        'timeBucket': selectedBucket.index,
        'images': images,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final draftJson = jsonEncode(draftData);
      
      // Optionally encrypt the draft
      final encryptionService = EncryptionService();
      final encryptedDraft = await encryptionService.encrypt(draftJson);
      
      await ref
          .read(storageServiceProvider)
          .saveDraft(_draftId!, encryptedDraft ?? draftJson);
          
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
    if (_draftId == null) return;
    
    try {
      final draftJson = await ref
          .read(storageServiceProvider)
          .getDraft(_draftId!);
      
      if (draftJson != null) {
        // Try to decrypt first
        final encryptionService = EncryptionService();
        final decryptedJson = await encryptionService.decrypt(draftJson);
        
        final draftData = jsonDecode(decryptedJson) as Map<String, dynamic>;
        
        if (mounted) {
          setState(() {
            type = EntryType.values[draftData['type'] as int];
            _headlineCtrl.text = draftData['headline'] as String;
            _contentCtrl.text = draftData['content'] as String;
            selectedMood = Mood.values[draftData['mood'] as int];
            selectedFeeling = draftData['feeling'] as String?;
            selectedBucket = TimeBucket.values[draftData['timeBucket'] as int];
            images = List<String>.from(draftData['images'] as List);
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
            await ref.read(storageServiceProvider).deleteDraft(_draftId!);
          },
        ),
      ),
    );
  }
  
  Future<void> _clearDraft() async {
    if (_draftId != null) {
      await ref.read(storageServiceProvider).deleteDraft(_draftId!);
    }
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
        id: widget.initialEntry?.id ?? _draftId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        date: widget.initialDate,
        headline: _headlineCtrl.text,
        content: _contentCtrl.text,
        mood: selectedMood,
        feeling: selectedFeeling,
        timeBucket: type == EntryType.event ? selectedBucket : null,
        images: images,
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
    _headlineCtrl.dispose();
    _contentCtrl.dispose();
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        // Date
                        Text(
                          "${_getWeekday(widget.initialDate.weekday)}, ${widget.initialDate.day}",
                          style: const TextStyle(
                            color: AppColors.slate400,
                            letterSpacing: 2,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
                                ? Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_isSaving)
                                          const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.emerald500,
                                            ),
                                          )
                                        else
                                          const Icon(
                                            Icons.edit,
                                            color: AppColors.amber500,
                                            size: 18,
                                          ),
                                      ],
                                    ),
                                  )
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

                        const SizedBox(height: 40),
                        _buildImageSection(),
                        const SizedBox(height: 100),
                      ],
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

  Widget _buildStoryFeelings() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: essentialFeelings.map((f) {
          bool isSel = selectedFeeling == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => selectedFeeling = f),
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
                      selectedBucket.toString().split('.').last,
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
          child: SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: moodIcons.entries.map((e) {
                bool isSel = selectedMood == e.key;
                return GestureDetector(
                  onTap: () => setState(() => selectedMood = e.key),
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
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Column(
      children: [
        if (images.isNotEmpty)
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: _getImageProvider(images.last),
                fit: BoxFit.cover,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white24,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                child: const Icon(Icons.add_a_photo, color: Colors.white54),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image(
                            image: _getImageProvider(images[i]),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                images.removeAt(i);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: AppColors.rose500,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  ImageProvider _getImageProvider(String imagePath) {
    if (imagePath.startsWith('http')) {
      return NetworkImage(imagePath);
    }
    return FileImage(File(imagePath));
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        // Save image to app documents directory
        final dir = await getApplicationDocumentsDirectory();
        final imageDir = Directory('${dir.path}/images');
        
        if (!await imageDir.exists()) {
          await imageDir.create(recursive: true);
        }
        
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.jpg';
        final savedImage = await File(image.path).copy('${imageDir.path}/$fileName');
        
        setState(() {
          images.add(savedImage.path);
        });
      }
    } catch (e) {
      debugPrint('Image pick failed: $e');
      if (mounted) {
        _showError('Failed to pick image. Please try again.');
      }
    }
  }

  Widget _buildRadialTimePickerOverlay() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => showTimePicker = false),
          child: Container(color: Colors.black87),
        ),
        Center(
          child: GlassContainer(
            borderRadius: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Select Time",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 250,
                  height: 250,
                  child: CustomPaint(
                    painter: RadialTimePickerPainter(),
                    child: GestureDetector(
                      onPanDown: (details) {
                        setState(() {
                          selectedBucket = TimeBucket.evening;
                          showTimePicker = false;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class RadialTimePickerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40;

    const colors = [
      AppColors.indigo500,
      AppColors.rose500,
      AppColors.amber500,
      AppColors.emerald500,
      AppColors.fuchsia500,
      AppColors.slate400,
    ];

    double startAngle = -math.pi / 2;
    const sweepAngle = 2 * math.pi / 6;

    for (int i = 0; i < 6; i++) {
      paint.color = colors[i].withValues(alpha: 0.8);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 20),
        startAngle,
        sweepAngle - 0.1,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
