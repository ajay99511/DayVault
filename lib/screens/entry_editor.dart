
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/types.dart';
import '../config/constants.dart';
import '../widgets/glass_widgets.dart';

class EntryEditor extends StatefulWidget {
  final DateTime initialDate;
  final EntryType initialType;
  final Function(JournalEntry) onSave;
  final VoidCallback onCancel;

  const EntryEditor({
    super.key,
    required this.initialDate,
    this.initialType = EntryType.story,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  late EntryType type;
  final TextEditingController _headlineCtrl = TextEditingController();
  final TextEditingController _contentCtrl = TextEditingController();
  Mood selectedMood = Mood.happy;
  String? selectedFeeling;
  TimeBucket selectedBucket = TimeBucket.morning;
  List<String> images = [];
  bool showTimePicker = false;

  @override
  void initState() {
    super.initState();
    type = widget.initialType;
  }

  void handleSave() {
    if (_headlineCtrl.text.isEmpty) return;

    final entry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      date: widget.initialDate,
      headline: _headlineCtrl.text,
      content: _contentCtrl.text,
      mood: selectedMood,
      feeling: selectedFeeling,
      timeBucket: type == EntryType.event ? selectedBucket : null,
      images: images,
    );
    widget.onSave(entry);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Base
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
                        AppColors.indigo500.withOpacity(0.2),
                        AppColors.rose500.withOpacity(0.1),
                      ]
                    : [
                        AppColors.emerald500.withOpacity(0.2),
                        AppColors.amber500.withOpacity(0.1),
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
                          "${widget.initialDate.weekday == 7 ? 'Sunday' : 'Monday'}, ${widget.initialDate.day}",
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
                          decoration: const InputDecoration(
                            hintText: 'Headline...',
                            hintStyle: TextStyle(color: Colors.white24),
                            border: InputBorder.none,
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
                        const SizedBox(height: 100), // Keyboard spacing
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white54),
            onPressed: widget.onCancel,
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
            icon: const Icon(Icons.check, color: AppColors.emerald500),
            onPressed: handleSave,
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
                      : Colors.white.withOpacity(0.05),
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
                    color: AppColors.emerald500.withOpacity(0.2),
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
                image: NetworkImage(images.last),
                fit: BoxFit.cover,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  images.add(
                    "https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/800/600",
                  );
                });
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white24,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(0.05),
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        images[i],
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
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

    final colors = [
      AppColors.indigo500,
      AppColors.rose500,
      AppColors.amber500,
      AppColors.emerald500,
      AppColors.fuchsia500,
      AppColors.slate400,
    ];

    double startAngle = -pi / 2;
    final sweepAngle = 2 * pi / 6;

    for (int i = 0; i < 6; i++) {
      paint.color = colors[i].withOpacity(0.8);
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
