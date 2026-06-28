// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../config/constants.dart';
import '../models/types.dart';
import '../services/storage_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/image_widgets.dart';
import 'entry_editor.dart' show ImageSection;

// ─── Category helpers ─────────────────────────────────────────────────────────

const Map<String, Color> _categoryColors = {
  'Career': AppColors.indigo500,
  'Health': AppColors.emerald500,
  'Travel': AppColors.amber500,
  'Relationships': AppColors.rose500,
  'Finance': Color(0xFF06B6D4), // cyan
  'Growth': AppColors.fuchsia500,
  'Creative': Color(0xFFEAB308), // yellow
  'Other': AppColors.slate400,
};

Color _colorForCategory(String cat) =>
    _categoryColors[cat] ?? AppColors.indigo500;

// ─── Main Screen ─────────────────────────────────────────────────────────────

class VisionBoardScreen extends ConsumerStatefulWidget {
  const VisionBoardScreen({super.key});

  @override
  ConsumerState<VisionBoardScreen> createState() => _VisionBoardScreenState();
}

class _VisionBoardScreenState extends ConsumerState<VisionBoardScreen> {
  int _year = DateTime.now().year;
  VisionBoard? _board;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final storage = ref.read(storageServiceProvider);
    final board = storage.getVisionBoardForYear(_year);
    setState(() => _board = board);
  }

  void _changeYear(int delta) {
    setState(() {
      _year += delta;
      _board = null;
    });
    _load();
  }

  List<VisionBoardItem> get _items => _board?.items ?? const [];

  void _openItemEditor({VisionBoardItem? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemEditorSheet(
        year: _year,
        existing: existing,
        onSaved: _load,
      ),
    );
  }

  void _toggleAchieved(VisionBoardItem item) {
    final updated = item.copyWith(isAchieved: !item.isAchieved);
    ref.read(storageServiceProvider).updateVisionBoardItem(_year, updated);
    _load();
  }

  void _confirmDelete(VisionBoardItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.slate900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove vision?',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Text(
          '"${item.title}" will be removed from your $_year vision board.',
          style: const TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.slate400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(color: AppColors.rose500)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(storageServiceProvider).deleteVisionBoardItem(_year, item.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: _items.isEmpty
                  ? _buildEmptyState()
                  : _buildBoard(),
            ),
          ],
        ),
      ),
      // Hidden on the empty state, which carries its own "Add first vision" CTA.
      floatingActionButton: _items.isEmpty ? null : _buildFab(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vision Board',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '${_items.where((i) => i.isAchieved).length} of ${_items.length} achieved',
                      style: const TextStyle(
                        color: AppColors.slate400,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              _buildYearSelector(),
            ],
          ),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildProgressBar(),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _yearArrow(Icons.chevron_left, () => _changeYear(-1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$_year',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _yearArrow(Icons.chevron_right,
              _year < DateTime.now().year + 5 ? () => _changeYear(1) : null),
        ],
      ),
    );
  }

  Widget _yearArrow(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 20,
          color: onTap != null ? Colors.white70 : Colors.white24,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final achieved = _items.where((i) => i.isAchieved).length;
    final ratio = _items.isEmpty ? 0.0 : achieved / _items.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 4,
        backgroundColor: Colors.white10,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald500),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.indigo500.withValues(alpha: 0.3),
                    AppColors.fuchsia500.withValues(alpha: 0.2),
                  ],
                ),
                border: Border.all(
                    color: AppColors.indigo500.withValues(alpha: 0.4)),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.indigo500,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your $_year Vision',
              style: GoogleFonts.libreBaskerville(
                color: Colors.white,
                fontSize: 22,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create a visual map of your goals,\ndreams, and intentions for the year.',
              style: TextStyle(
                color: AppColors.slate400,
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => _openItemEditor(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.indigo500, AppColors.fuchsia500],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.indigo500.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  'Add first vision',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard() {
    // Two-column masonry layout — distribute items alternately.
    final leftItems = <VisionBoardItem>[];
    final rightItems = <VisionBoardItem>[];
    for (int i = 0; i < _items.length; i++) {
      if (i.isEven) {
        leftItems.add(_items[i]);
      } else {
        rightItems.add(_items[i]);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildColumn(leftItems)),
          const SizedBox(width: 8),
          Expanded(child: _buildColumn(rightItems)),
        ],
      ),
    );
  }

  Widget _buildColumn(List<VisionBoardItem> items) {
    return Column(
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _VisionCard(
                  item: item,
                  onTap: () => _openItemEditor(existing: item),
                  onToggleAchieved: () => _toggleAchieved(item),
                  onDelete: () => _confirmDelete(item),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildFab() {
    // bottom: 100 lifts the button clear of the floating glass nav pill, matching
    // the IdentityScreen FAB placement.
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.indigo500, AppColors.fuchsia500],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.indigo500.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () => _openItemEditor(),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ─── Vision Card ─────────────────────────────────────────────────────────────

class _VisionCard extends StatelessWidget {
  final VisionBoardItem item;
  final VoidCallback onTap;
  final VoidCallback onToggleAchieved;
  final VoidCallback onDelete;

  const _VisionCard({
    required this.item,
    required this.onTap,
    required this.onToggleAchieved,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.colorAccent != 0
        ? Color(item.colorAccent)
        : _colorForCategory(item.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.slate900,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isAchieved
                ? AppColors.emerald500.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image collage (only shown when images exist)
            if (item.images.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: _ImageCollage(images: item.images),
              ),

            // Content area
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category + achieved badge row
                  Row(
                    children: [
                      if (item.category.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.category,
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      const Spacer(),
                      GestureDetector(
                        onTap: onToggleAchieved,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            item.isAchieved
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 18,
                            color: item.isAchieved
                                ? AppColors.emerald500
                                : Colors.white24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    item.title,
                    style: GoogleFonts.outfit(
                      color: item.isAchieved
                          ? Colors.white54
                          : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      decoration: item.isAchieved
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Description
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: const TextStyle(
                        color: AppColors.slate400,
                        fontSize: 11,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Affirmation
                  if (item.affirmation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '"${item.affirmation}"',
                      style: GoogleFonts.libreBaskerville(
                        color: accent.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Target date
                  if (item.targetDate != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 10,
                          color: _isOverdue(item)
                              ? AppColors.rose500
                              : AppColors.slate400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(item.targetDate!),
                          style: TextStyle(
                            color: _isOverdue(item)
                                ? AppColors.rose500
                                : AppColors.slate400,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isOverdue(VisionBoardItem item) {
    if (item.isAchieved || item.targetDate == null) return false;
    return item.targetDate!.isBefore(DateTime.now());
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// ─── Image Collage ────────────────────────────────────────────────────────────

/// Renders 1-4+ images in a magazine-style collage layout on vision board cards.
class _ImageCollage extends StatelessWidget {
  final List<ImageReference> images;

  const _ImageCollage({required this.images});

  @override
  Widget build(BuildContext context) {
    // Cap at 4 for the layout; track overflow count separately.
    final shown = images.take(4).toList();
    final overflow = images.length - 4;

    switch (shown.length) {
      case 1:
        return _single(shown[0]);
      case 2:
        return _double(shown[0], shown[1]);
      case 3:
        return _triple(shown[0], shown[1], shown[2]);
      default:
        return _quad(shown[0], shown[1], shown[2], shown[3], overflow);
    }
  }

  // 1 image — full-width hero, 3:2 ratio
  Widget _single(ImageReference img) {
    return AspectRatio(
      aspectRatio: 3 / 2,
      child: ImageThumbnailWidget(
        imageRef: img,
        fit: BoxFit.cover,
        showTapToZoom: true,
      ),
    );
  }

  // 2 images — equal side-by-side with a 1px gap
  Widget _double(ImageReference a, ImageReference b) {
    return AspectRatio(
      aspectRatio: 3 / 2,
      child: Row(
        children: [
          Expanded(child: _thumb(a)),
          const SizedBox(width: 1),
          Expanded(child: _thumb(b)),
        ],
      ),
    );
  }

  // 3 images — large left (60%), two stacked on right (40%)
  Widget _triple(ImageReference a, ImageReference b, ImageReference c) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Row(
        children: [
          Expanded(flex: 6, child: _thumb(a)),
          const SizedBox(width: 1),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Expanded(child: _thumb(b)),
                const SizedBox(height: 1),
                Expanded(child: _thumb(c)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4 images — 2×2 grid; last cell shows "+N" when there are more than 4
  Widget _quad(ImageReference a, ImageReference b, ImageReference c,
      ImageReference d, int overflow) {
    return AspectRatio(
      aspectRatio: 1,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _thumb(a)),
                const SizedBox(width: 1),
                Expanded(child: _thumb(b)),
              ],
            ),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _thumb(c)),
                const SizedBox(width: 1),
                Expanded(
                  child: overflow > 0
                      ? _overflowThumb(d, overflow)
                      : _thumb(d),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(ImageReference img) {
    return ImageThumbnailWidget(
      imageRef: img,
      fit: BoxFit.cover,
      showTapToZoom: true,
    );
  }

  Widget _overflowThumb(ImageReference img, int count) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _thumb(img),
        Container(color: Colors.black54),
        Center(
          child: Text(
            '+$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Item Editor Bottom Sheet ─────────────────────────────────────────────────

class _ItemEditorSheet extends ConsumerStatefulWidget {
  final int year;
  final VisionBoardItem? existing;
  final VoidCallback onSaved;

  const _ItemEditorSheet({
    required this.year,
    this.existing,
    required this.onSaved,
  });

  @override
  ConsumerState<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends ConsumerState<_ItemEditorSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _affirmationCtrl;
  late String _category;
  late List<ImageReference> _images;
  late bool _isAchieved;
  DateTime? _targetDate;
  late Color _accent;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _affirmationCtrl = TextEditingController(text: e?.affirmation ?? '');
    _category = e?.category ?? visionBoardCategories.first;
    _images = List.from(e?.images ?? []);
    _isAchieved = e?.isAchieved ?? false;
    _targetDate = e?.targetDate;
    _accent = e != null && e.colorAccent != 0
        ? Color(e.colorAccent)
        : _colorForCategory(_category);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _affirmationCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Give your vision a title'),
          backgroundColor: AppColors.rose500,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final storage = ref.read(storageServiceProvider);

    final item = VisionBoardItem(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _category,
      images: _images,
      isAchieved: _isAchieved,
      targetDate: _targetDate,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      colorAccent: _accent.toARGB32(),
      affirmation: _affirmationCtrl.text.trim(),
    );

    if (_isEditing) {
      storage.updateVisionBoardItem(widget.year, item);
    } else {
      storage.addVisionBoardItem(widget.year, item);
    }

    widget.onSaved();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) {
          return Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      _isEditing ? 'Edit Vision' : 'New Vision',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (_isEditing)
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.rose500),
                        onPressed: _confirmDelete,
                        tooltip: 'Delete',
                      ),
                    IconButton(
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.emerald500,
                              ),
                            )
                          : const Icon(Icons.check_circle,
                              color: AppColors.emerald500, size: 28),
                      onPressed: _saving ? null : _save,
                      tooltip: 'Save',
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white10, height: 1),

              // Scrollable body
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
                  children: [
                    // Title
                    _sectionLabel('TITLE'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleCtrl,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: _inputDecoration('What do you want to manifest?'),
                      maxLines: null,
                    ),
                    const SizedBox(height: 24),

                    // Category
                    _sectionLabel('CATEGORY'),
                    const SizedBox(height: 10),
                    _buildCategoryPicker(),
                    const SizedBox(height: 24),

                    // Images
                    _sectionLabel('IMAGES'),
                    const SizedBox(height: 10),
                    ImageSection(
                      images: _images,
                      onChanged: (next) => setState(() => _images = next),
                      onError: (msg) => ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(
                        content: Text(msg),
                        backgroundColor: AppColors.rose500,
                        behavior: SnackBarBehavior.floating,
                      )),
                    ),
                    const SizedBox(height: 24),

                    // Description
                    _sectionLabel('DESCRIPTION'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descCtrl,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14, height: 1.5),
                      decoration: _inputDecoration(
                          'Why does this matter to you? Paint the picture…'),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),

                    // Affirmation
                    _sectionLabel('AFFIRMATION'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _affirmationCtrl,
                      style: GoogleFonts.libreBaskerville(
                        color: _accent,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                      decoration: _inputDecoration('A short mantra or intention…'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),

                    // Target date
                    _sectionLabel('TARGET DATE'),
                    const SizedBox(height: 10),
                    _buildDatePicker(),
                    const SizedBox(height: 24),

                    // Color accent
                    _sectionLabel('CARD ACCENT'),
                    const SizedBox(height: 10),
                    _buildColorPicker(),
                    const SizedBox(height: 24),

                    // Achieved toggle
                    _buildAchievedToggle(),
                    const SizedBox(height: 32),

                    // Save button
                    GestureDetector(
                      onTap: _saving ? null : _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_accent, _accent.withValues(alpha: 0.7)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _isEditing ? 'Update Vision' : 'Manifest Vision',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.slate400,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _accent),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
    );
  }

  Widget _buildCategoryPicker() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visionBoardCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = visionBoardCategories[i];
          final isSel = _category == cat;
          final color = _colorForCategory(cat);
          return GestureDetector(
            onTap: () => setState(() {
              _category = cat;
              if (widget.existing == null ||
                  widget.existing!.colorAccent == 0) {
                _accent = color;
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSel
                    ? color.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      isSel ? color : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: isSel ? color : Colors.white54,
                  fontSize: 12,
                  fontWeight:
                      isSel ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: _targetDate != null ? _accent : Colors.white38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _targetDate != null
                    ? _formatDate(_targetDate!)
                    : 'Set a target date (optional)',
                style: TextStyle(
                  color: _targetDate != null
                      ? Colors.white
                      : Colors.white38,
                  fontSize: 14,
                ),
              ),
            ),
            if (_targetDate != null)
              GestureDetector(
                onTap: () => setState(() => _targetDate = null),
                child: const Icon(Icons.close,
                    size: 16, color: Colors.white38),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: _accent,
            onPrimary: Colors.white,
            surface: AppColors.slate900,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Widget _buildColorPicker() {
    final colors = [
      AppColors.indigo500,
      AppColors.fuchsia500,
      AppColors.emerald500,
      AppColors.amber500,
      AppColors.rose500,
      const Color(0xFF06B6D4), // cyan
      const Color(0xFFEAB308), // yellow
      AppColors.slate400,
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((c) {
        final isSel = _accent.toARGB32() == c.toARGB32();
        return GestureDetector(
          onTap: () => setState(() => _accent = c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSel ? Colors.white : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: isSel
                  ? [
                      BoxShadow(
                        color: c.withValues(alpha: 0.6),
                        blurRadius: 8,
                      )
                    ]
                  : null,
            ),
            child: isSel
                ? const Icon(Icons.check,
                    size: 14, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAchievedToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isAchieved = !_isAchieved),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isAchieved
              ? AppColors.emerald500.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isAchieved
                ? AppColors.emerald500.withValues(alpha: 0.5)
                : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isAchieved ? Icons.check_circle : Icons.circle_outlined,
              color: _isAchieved
                  ? AppColors.emerald500
                  : Colors.white38,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mark as Achieved',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (_isAchieved)
                    const Text(
                      'Celebrate this win! 🎉',
                      style: TextStyle(
                          color: AppColors.emerald500, fontSize: 11),
                    ),
                ],
              ),
            ),
            Switch(
              value: _isAchieved,
              onChanged: (v) => setState(() => _isAchieved = v),
              activeThumbColor: AppColors.emerald500,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.slate900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove vision?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This vision will be removed from your board.',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.slate400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(color: AppColors.rose500)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(storageServiceProvider).deleteVisionBoardItem(
            widget.year,
            widget.existing!.id,
          );
      widget.onSaved();
      Navigator.pop(context);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
