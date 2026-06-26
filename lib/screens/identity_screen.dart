import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../services/storage_service.dart';
import '../services/image_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/types.dart';
import '../config/constants.dart';
import '../theme/app_tokens.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/image_widgets.dart';

/// How the active category's items are ordered for display. [manual] keeps the
/// user's drag-ordered rank; the others are derived (and disable reordering).
enum _ItemSort { manual, ratingDesc, dateDesc }

class IdentityScreen extends ConsumerStatefulWidget {
  const IdentityScreen({super.key});

  @override
  ConsumerState<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends ConsumerState<IdentityScreen> {
  List<RankingCategory> categories = [];
  String activeId = 'movies';
  bool _showFavoritesOnly = false;
  bool _isLoading = true;
  bool _isMasked = true; // PII masking state (R3.2)

  // Search state
  bool _isSearching = false;
  bool _globalSearch = false; // search across all categories
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Sort mode for the active category list.
  _ItemSort _sortMode = _ItemSort.manual;

  /// Apply the active sort to [items]. [manual] preserves the incoming (rank)
  /// order. Non-manual sorts return a new list and are pure for testability.
  List<RankedItem> _applySort(List<RankedItem> items) {
    switch (_sortMode) {
      case _ItemSort.manual:
        return items;
      case _ItemSort.ratingDesc:
        return [...items]..sort((a, b) => b.rating.compareTo(a.rating));
      case _ItemSort.dateDesc:
        return [...items]..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = ref.read(storageServiceProvider);
    final d = _showFavoritesOnly
        ? await storage.getFavoriteRankings()
        : await storage.getRankings();

    if (d.isNotEmpty && !d.any((c) => c.id == activeId)) {
      activeId = d.first.id;
    }
    setState(() {
      categories = d;
      _isLoading = false;
    });
  }

  RankingCategory get _activeCategory => categories.firstWhere(
        (c) => c.id == activeId,
        orElse: () => categories.first,
      );

  // ─── Category Management ──────────────────────────────────────────────

  Future<void> _showCategoryDialog({RankingCategory? existingCat}) async {
    final titleCtrl = TextEditingController(text: existingCat?.title ?? '');
    bool isFav = existingCat?.isFavorite ?? false;
    String selectedIcon = existingCat?.iconName ?? 'category';
    int selectedColor = existingCat?.colorValue ?? 0;
    final isEditing = existingCat != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) {
        return AlertDialog(
          backgroundColor: ctx.tokens.surfaceBase,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEditing ? 'Edit Category' : 'New Category',
              style: TextStyle(color: ctx.tokens.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: TextStyle(color: ctx.tokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Video Games',
                    hintStyle: TextStyle(color: ctx.tokens.textTertiary),
                    filled: true,
                    fillColor: ctx.tokens.surfaceGlassFill,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                _dialogLabel(ctx, 'ICON'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categoryIcons.keys.map((key) {
                    final sel = key == selectedIcon;
                    final accent = selectedColor == 0
                        ? AppColors.indigo500
                        : Color(selectedColor);
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedIcon = key),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: sel
                              ? accent.withValues(alpha: 0.25)
                              : ctx.tokens.surfaceGlassFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? accent : ctx.tokens.glassBorder,
                          ),
                        ),
                        child: Icon(categoryIconFor(key),
                            size: 20,
                            color: sel ? accent : ctx.tokens.textSecondary),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                _dialogLabel(ctx, 'COLOR'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _colorDot(ctx, 0, selectedColor == 0,
                        () => setModalState(() => selectedColor = 0)),
                    ...categoryColors.map((c) {
                      final v = c.toARGB32();
                      return _colorDot(ctx, v, selectedColor == v,
                          () => setModalState(() => selectedColor = v));
                    }),
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  title: Text('Favourite',
                      style: TextStyle(color: ctx.tokens.textPrimary)),
                  value: isFav,
                  activeThumbColor: AppColors.amber500,
                  onChanged: (val) => setModalState(() => isFav = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL',
                    style: TextStyle(color: AppColors.slate400))),
            TextButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final storage = ref.read(storageServiceProvider);
                final cat = RankingCategory(
                  id: existingCat?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  title: titleCtrl.text.trim(),
                  iconName: selectedIcon,
                  items: existingCat?.items ?? [],
                  isFavorite: isFav,
                  colorValue: selectedColor,
                );
                await storage.addRankingCategory(cat);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('SAVE',
                  style: TextStyle(color: AppColors.indigo500)),
            ),
          ],
        );
      }),
    );

    if (result == true) {
      await _load();
    }
  }

  void _showCategoryOptions(RankingCategory cat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.tokens.surfaceBase,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.edit, color: context.tokens.textPrimary),
            title: Text('Edit Category',
                style: TextStyle(color: context.tokens.textPrimary)),
            onTap: () {
              Navigator.pop(ctx);
              _showCategoryDialog(existingCat: cat);
            },
          ),
          ListTile(
            leading: Icon(cat.isFavorite ? Icons.star : Icons.star_border,
                color: AppColors.amber500),
            title: Text(
                cat.isFavorite ? 'Remove from Favourites' : 'Add to Favourites',
                style: TextStyle(color: context.tokens.textPrimary)),
            onTap: () async {
              Navigator.pop(ctx);
              final updated = cat.copyWith(isFavorite: !cat.isFavorite);
              await ref
                  .read(storageServiceProvider)
                  .addRankingCategory(updated);
              _load();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: AppColors.rose500),
            title: const Text('Delete Category',
                style: TextStyle(color: AppColors.rose500)),
            onTap: () async {
              Navigator.pop(ctx);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: c.tokens.surfaceBase,
                  title: Text('Delete Category?',
                      style: TextStyle(color: c.tokens.textPrimary)),
                  content: Text(
                      'This will delete the category and all its items.',
                      style: TextStyle(color: c.tokens.textSecondary)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('CANCEL',
                            style: TextStyle(color: AppColors.slate400))),
                    TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('DELETE',
                            style: TextStyle(color: AppColors.rose500))),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref
                    .read(storageServiceProvider)
                    .deleteRankingCategory(cat.id);
                _load();
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── Add / Edit Dialog ────────────────────────────────────────────────

  Future<void> _showAddEditDialog({RankedItem? existingItem}) async {
    final nameCtrl = TextEditingController(text: existingItem?.name ?? '');
    final subtitleCtrl =
        TextEditingController(text: existingItem?.subtitle ?? '');
    final notesCtrl = TextEditingController(text: existingItem?.notes ?? '');
    double rating = existingItem?.rating ?? 0;
    ImageReference? selectedImage = existingItem?.image;
    final isEditing = existingItem != null;

    final result = await showModalBottomSheet<RankedItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: GlassContainer(
                  borderRadius: 28,
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.indigo500,
                                    AppColors.fuchsia500,
                                  ],
                                ),
                              ),
                              child: Icon(
                                isEditing
                                    ? Icons.edit_rounded
                                    : Icons.add_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              isEditing ? 'Edit Item' : 'Add Favourite',
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: context.tokens.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _activeCategory.title.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.indigo500,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Name
                        _glassTextField(
                          controller: nameCtrl,
                          label: 'Name *',
                          hint: 'e.g. Interstellar',
                        ),
                        const SizedBox(height: 14),

                        // Subtitle
                        _glassTextField(
                          controller: subtitleCtrl,
                          label: 'Subtitle',
                          hint: 'e.g. Christopher Nolan',
                        ),
                        const SizedBox(height: 18),

                        // Cover image
                        Text(
                          'COVER',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: context.tokens.textTertiary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (selectedImage != null) ...[
                              SizedBox(
                                width: 56,
                                height: 56,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: ImageThumbnailWidget(
                                          imageRef: selectedImage!,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: GestureDetector(
                                        onTap: () => setModalState(
                                            () => selectedImage = null),
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
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            _coverSourceButton(
                              icon: Icons.link,
                              label: 'URL',
                              onTap: () async {
                                final img = await _promptImageUrl();
                                if (img != null) {
                                  setModalState(() => selectedImage = img);
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            _coverSourceButton(
                              icon: Icons.folder_open,
                              label: 'File',
                              onTap: () async {
                                final img = await _pickImageFromFile();
                                if (img != null) {
                                  setModalState(() => selectedImage = img);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Rating
                        Text(
                          'RATING',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: context.tokens.textTertiary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _StarRatingPicker(
                          rating: rating,
                          onChanged: (v) => setModalState(() => rating = v),
                        ),
                        const SizedBox(height: 18),

                        // Notes
                        _glassTextField(
                          controller: notesCtrl,
                          label: 'Notes',
                          hint: 'What makes this special to you?',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'CANCEL',
                                  style: GoogleFonts.outfit(
                                    color: AppColors.slate400,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.indigo500,
                                      AppColors.fuchsia500,
                                    ],
                                  ),
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    if (nameCtrl.text.trim().isEmpty) return;
                                    final item = RankedItem(
                                      id: existingItem?.id ??
                                          DateTime.now()
                                              .microsecondsSinceEpoch
                                              .toString(),
                                      rank: existingItem?.rank ??
                                          (_activeCategory.items.length + 1),
                                      name: nameCtrl.text.trim(),
                                      rating: rating,
                                      subtitle: subtitleCtrl.text.trim(),
                                      notes: notesCtrl.text.trim(),
                                      dateAdded: existingItem?.dateAdded ??
                                          DateTime.now(),
                                      image: selectedImage,
                                    );
                                    Navigator.pop(ctx, item);
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    isEditing ? 'UPDATE' : 'SAVE',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    final storage = ref.read(storageServiceProvider);
    if (isEditing) {
      // Replace the item in-place
      final cat = _activeCategory;
      final updatedItems = cat.items.map((i) {
        return i.id == result.id ? result : i;
      }).toList();
      await storage.updateRankingCategory(cat.copyWith(items: updatedItems));
    } else {
      await storage.addRankedItem(activeId, result);
    }
    await _load();
  }

  // ─── Item Detail Bottom Sheet ─────────────────────────────────────────

  Future<void> _showItemDetail(RankedItem item) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: GlassContainer(
            borderRadius: 28,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image (hidden in privacy mode).
                if (item.image != null && !_isMasked) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 160,
                      child: ImageThumbnailWidget(
                        imageRef: item.image!,
                        fit: BoxFit.cover,
                        showTapToZoom: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Rank badge + title
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: _getRankGradient(item.rank),
                      ),
                      child: Text(
                        '#${item.rank}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isMasked ? '••••••••' : item.name,
                            style: GoogleFonts.libreBaskerville(
                              color: context.tokens.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (item.subtitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                _isMasked ? '••••••••' : item.subtitle,
                                style: GoogleFonts.outfit(
                                  color: context.tokens.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Stars row
                Row(
                  children: [
                    _buildStarRow(item.rating,
                        size: 22, emptyColor: context.tokens.textDisabled),
                    const SizedBox(width: 10),
                    Text(
                      item.rating.toStringAsFixed(1),
                      style: GoogleFonts.outfit(
                        color: AppColors.amber500,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Notes
                if (item.notes.isNotEmpty) ...[
                  Text(
                    'NOTES',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: context.tokens.textTertiary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.tokens.surfaceGlassFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.tokens.glassBorder),
                    ),
                    child: Text(
                      _isMasked ? '••••••••••••••••' : item.notes,
                      style: GoogleFonts.outfit(
                        color: context.tokens.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Preference drift (only once there's movement to show).
                if (item.history.length >= 2 && !_isMasked) ...[
                  Text(
                    'PREFERENCE DRIFT',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: context.tokens.textTertiary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _RankSparkline(
                      history: item.history, color: AppColors.indigo500),
                  const SizedBox(height: 6),
                  Text(
                    _driftSummary(item),
                    style: GoogleFonts.outfit(
                      color: context.tokens.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Date
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 14, color: context.tokens.textTertiary),
                    const SizedBox(width: 6),
                    Text(
                      'Added ${_formatDate(item.dateAdded)}',
                      style: GoogleFonts.outfit(
                        color: context.tokens.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: _glassActionButton(
                        icon: Icons.edit_rounded,
                        label: 'EDIT',
                        color: AppColors.indigo500,
                        onTap: () {
                          Navigator.pop(ctx);
                          _showAddEditDialog(existingItem: item);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _glassActionButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'DELETE',
                        color: AppColors.rose500,
                        onTap: () async {
                          Navigator.pop(ctx);
                          _confirmDelete(item);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(RankedItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.tokens.surfaceBase,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove "${item.name}"?',
          style: GoogleFonts.outfit(
              color: ctx.tokens.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will remove it from your rankings. You can always add it back later.',
          style: GoogleFonts.outfit(color: ctx.tokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL',
                style: GoogleFonts.outfit(color: AppColors.slate400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('DELETE',
                style: GoogleFonts.outfit(color: AppColors.rose500)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final storage = ref.read(storageServiceProvider);
      // Snapshot the whole category (items + ranks) so UNDO restores the exact
      // prior order, not just an appended copy.
      final categorySnapshot = _activeCategory;
      final messenger = ScaffoldMessenger.of(context);

      await storage.deleteRankedItem(activeId, item.id);
      await _load();

      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            // Don't leak the item name while privacy masking is on.
            content: Text(_isMasked ? 'Item removed' : 'Removed "${item.name}"'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                await storage.updateRankingCategory(categorySnapshot);
                await _load();
              },
            ),
          ),
        );
    }
  }

  // ─── Reorder Handler ──────────────────────────────────────────────────

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final items = List<RankedItem>.from(_activeCategory.items);
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    // Record a drift snapshot for every item whose rank changed. The new rank
    // is its 1-based position; reorderRankedItems re-stamps the same rank from
    // position, so this stays consistent.
    final now = DateTime.now();
    final stamped = [
      for (int i = 0; i < items.length; i++)
        _withRankSnapshot(items[i], i + 1, now),
    ];

    await ref
        .read(storageServiceProvider)
        .reorderRankedItems(activeId, stamped);
    await _load();
  }

  /// Append a [newRank] snapshot to an item's drift history if its rank
  /// changed. Seeds the pre-move rank as the first point so a delta exists
  /// after the first reorder. History is capped to the most recent 30 points.
  RankedItem _withRankSnapshot(RankedItem item, int newRank, DateTime when) {
    if (item.rank == newRank) return item;
    final history = [...item.history];
    if (history.isEmpty) {
      history.add(RankSnapshot(date: item.dateAdded, rank: item.rank));
    }
    history.add(RankSnapshot(date: when, rank: newRank));
    final capped =
        history.length > 30 ? history.sublist(history.length - 30) : history;
    return item.copyWith(history: capped);
  }

  /// Drift delta from the last two recorded snapshots: positive = moved up
  /// (toward #1), negative = moved down, null = not enough history.
  static int? _driftDelta(RankedItem item) {
    if (item.history.length < 2) return null;
    final prev = item.history[item.history.length - 2].rank;
    final last = item.history.last.rank;
    return prev - last;
  }

  /// Human summary of an item's overall drift since first ranked.
  String _driftSummary(RankedItem item) {
    final first = item.history.first.rank;
    final last = item.history.last.rank;
    final diff = first - last; // positive = improved (toward #1)
    if (diff > 0) {
      return 'Climbed $diff ${diff == 1 ? 'spot' : 'spots'} since first ranked';
    }
    if (diff < 0) {
      final n = diff.abs();
      return 'Fell $n ${n == 1 ? 'spot' : 'spots'} since first ranked';
    }
    return 'Back to where it started';
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // A restore (or any rankings change made from another surface) bumps the
    // shared revision — reload so this kept-alive tab never shows stale data.
    ref.listen(journalRevisionProvider, (_, __) => _load());

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final int initialIndex = categories.isEmpty
        ? 0
        : categories
            .indexWhere((c) => c.id == activeId)
            .clamp(0, categories.length - 1)
            .toInt();

    return DefaultTabController(
      length: categories.isEmpty ? 1 : categories.length,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ResponsiveCenter(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!_isSearching)
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Preference Drift",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w300,
                              color: context.tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "The evolution of your taste.",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: context.tokens.textTertiary),
                          ),
                        ],
                      ),
                    ),

                  // Search and Actions
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_isSearching)
                          Expanded(
                            child: GlassContainer(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              borderRadius: 20,
                              child: Row(
                                children: [
                                  Icon(Icons.search,
                                      color: context.tokens.textTertiary,
                                      size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchCtrl,
                                      autofocus: true,
                                      onChanged: (val) =>
                                          setState(() => _searchQuery = val),
                                      style: GoogleFonts.outfit(
                                          color: context.tokens.textPrimary,
                                          fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'Search items...',
                                        hintStyle: GoogleFonts.outfit(
                                            color: context.tokens.textTertiary,
                                            fontSize: 14),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  // Toggle: search this list vs all categories.
                                  GestureDetector(
                                    onTap: () => setState(
                                        () => _globalSearch = !_globalSearch),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _globalSearch
                                            ? AppColors.indigo500
                                                .withValues(alpha: 0.3)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _globalSearch
                                              ? AppColors.indigo500
                                              : context.tokens.glassBorder,
                                        ),
                                      ),
                                      child: Text(
                                        'ALL',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _globalSearch
                                              ? Colors.white
                                              : context.tokens.textTertiary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_searchQuery.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        _searchCtrl.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                      child: Icon(Icons.close,
                                          color: context.tokens.textTertiary,
                                          size: 16),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (!_isSearching) _buildTopActions(),
                        _sortButton(),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isSearching = !_isSearching;
                              if (!_isSearching) {
                                _searchCtrl.clear();
                                _searchQuery = '';
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.tokens.surfaceGlassFill,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: context.tokens.glassBorder),
                            ),
                            child: Icon(
                              _isSearching ? Icons.close : Icons.search,
                              color: context.tokens.textPrimary,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tabs — _SyncedTabBar is a descendant of DefaultTabController
            // so it can safely call DefaultTabController.of(context) in
            // didChangeDependencies without throwing. Hidden while showing
            // global (cross-category) search results.
            if (categories.isNotEmpty && !_isGlobalResults)
              _SyncedTabBar(
                categories: categories,
                activeId: activeId,
                onTabChanged: (newId) => setState(() => activeId = newId),
                onCategoryOptions: () => _showCategoryOptions(_activeCategory),
              ),
            const SizedBox(height: 24),

            // TabBarView Content (Swipeable lists), or global search results.
            Expanded(
              child: _isGlobalResults
                  ? _buildGlobalResults()
                  : categories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.category_outlined,
                              size: 60, color: context.tokens.textDisabled),
                          const SizedBox(height: 16),
                          Text('No categories found',
                              style: TextStyle(
                                  color: context.tokens.textTertiary,
                                  fontSize: 16)),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => _showCategoryDialog(),
                            child: const Text('ADD CATEGORY',
                                style: TextStyle(
                                    color: AppColors.indigo500,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5)),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      children: categories.map((cat) {
                        // Filter items. Searching is inert while masked so
                        // hidden content can't be probed via the query.
                        final effectiveQuery = _isMasked ? '' : _searchQuery;
                        final filteredItems = effectiveQuery.isEmpty
                            ? cat.items
                            : cat.items.where((item) {
                                final q = effectiveQuery.toLowerCase();
                                return item.name.toLowerCase().contains(q) ||
                                    item.subtitle.toLowerCase().contains(q);
                              }).toList();

                        // Apply sort. Reordering is only possible in manual
                        // sort while not searching.
                        final displayItems = _applySort(filteredItems);
                        final reorderable =
                            _sortMode == _ItemSort.manual && !_isSearching;

                        if (displayItems.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.indigo500
                                            .withValues(alpha: 0.2),
                                        AppColors.fuchsia500
                                            .withValues(alpha: 0.1),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    _isSearching
                                        ? Icons.search_off
                                        : Icons.emoji_events_outlined,
                                    size: 40,
                                    color: Colors.white24,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _isSearching
                                      ? "No matching items found."
                                      : "No favourites ranked yet.",
                                  style: GoogleFonts.outfit(
                                      color: context.tokens.textTertiary,
                                      fontSize: 16),
                                ),
                                if (!_isSearching) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    "Tap + to add your first ${cat.title.toLowerCase()} item",
                                    style: GoogleFonts.outfit(
                                        color: context.tokens.textDisabled,
                                        fontSize: 13),
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: () {
                                      setState(() => activeId = cat.id);
                                      _showAddEditDialog();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: const LinearGradient(
                                          colors: [
                                            AppColors.indigo500,
                                            AppColors.fuchsia500
                                          ],
                                        ),
                                      ),
                                      child: Text(
                                        "START RANKING",
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }

                        _RankedItemTile buildTile(int i) {
                          final item = displayItems[i];
                          return _RankedItemTile(
                            key: ValueKey(item.id),
                            index: i,
                            item: item,
                            isMasked: _isMasked,
                            showHandle: reorderable,
                            getRankGradient: _getRankGradient,
                            onTap: () {
                              if (activeId != cat.id) {
                                setState(() => activeId = cat.id);
                              }
                              _showItemDetail(item);
                            },
                          );
                        }

                        // Non-manual sort or active search → a plain,
                        // non-reorderable list.
                        if (!reorderable) {
                          return ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: displayItems.length,
                            itemBuilder: (ctx, i) => buildTile(i),
                          );
                        }

                        return ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          proxyDecorator: _proxyDecorator,
                          onReorder: (oldIndex, newIndex) {
                            if (activeId != cat.id) {
                              setState(() => activeId = cat.id);
                            }
                            _onReorder(oldIndex, newIndex);
                          },
                          itemCount: displayItems.length,
                          itemBuilder: (ctx, i) => buildTile(i),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
        ),
        floatingActionButton: categories.isEmpty
            ? null
            : Padding(
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
                        color: AppColors.indigo500.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    onPressed: () => _showAddEditDialog(),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
              ),
      ),
    );
  }

  // ─── Top Actions (adaptive) ───────────────────────────────────────────
  // On wide layouts the actions are shown as inline icons. On phones they
  // collapse into a single overflow menu so they never overflow / clip the
  // header as the title competes for width.

  Widget _buildTopActions() {
    final compact = MediaQuery.sizeOf(context).width < Breakpoints.mobile;
    return compact ? _compactTopActions() : _inlineTopActions();
  }

  Widget _inlineTopActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _toggleMask,
          tooltip: 'Toggle Privacy Mode',
          icon: Icon(
            _isMasked
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: _isMasked ? AppColors.indigo500 : context.tokens.textTertiary,
          ),
        ),
        IconButton(
          onPressed: _toggleFavoritesOnly,
          tooltip: 'Show favourites only',
          icon: Icon(
            _showFavoritesOnly ? Icons.star : Icons.star_border,
            color: _showFavoritesOnly
                ? AppColors.amber500
                : context.tokens.textTertiary,
          ),
        ),
        IconButton(
          onPressed: () => _showCategoryDialog(),
          tooltip: 'New category',
          icon: Icon(Icons.add_box_outlined, color: context.tokens.textPrimary),
        ),
      ],
    );
  }

  Widget _compactTopActions() {
    return PopupMenuButton<String>(
      tooltip: 'More options',
      color: context.tokens.surfaceBase,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(Icons.more_horiz, color: context.tokens.textPrimary),
      onSelected: (value) {
        switch (value) {
          case 'privacy':
            _toggleMask();
            break;
          case 'favorites':
            _toggleFavoritesOnly();
            break;
          case 'add':
            _showCategoryDialog();
            break;
        }
      },
      itemBuilder: (ctx) => [
        CheckedPopupMenuItem(
          value: 'privacy',
          checked: _isMasked,
          child: const Text('Privacy mode'),
        ),
        CheckedPopupMenuItem(
          value: 'favorites',
          checked: _showFavoritesOnly,
          child: const Text('Favourites only'),
        ),
        const PopupMenuItem(
          value: 'add',
          child: Row(
            children: [
              Icon(Icons.add_box_outlined, size: 20),
              SizedBox(width: 12),
              Text('New category'),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleFavoritesOnly() {
    setState(() => _showFavoritesOnly = !_showFavoritesOnly);
    _load();
  }

  /// Toggle privacy masking. Entering privacy mode also exits search so masked
  /// content can't be probed through the query field.
  void _toggleMask() {
    setState(() {
      _isMasked = !_isMasked;
      if (_isMasked && _isSearching) {
        _isSearching = false;
        _searchCtrl.clear();
        _searchQuery = '';
      }
    });
  }

  /// Sort selector for the active category list.
  Widget _sortButton() {
    return PopupMenuButton<_ItemSort>(
      tooltip: 'Sort',
      color: context.tokens.surfaceBase,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(
        Icons.sort_rounded,
        color: _sortMode == _ItemSort.manual
            ? context.tokens.textTertiary
            : AppColors.indigo500,
      ),
      onSelected: (m) => setState(() => _sortMode = m),
      itemBuilder: (ctx) => [
        CheckedPopupMenuItem(
          value: _ItemSort.manual,
          checked: _sortMode == _ItemSort.manual,
          child: const Text('Manual (rank)'),
        ),
        CheckedPopupMenuItem(
          value: _ItemSort.ratingDesc,
          checked: _sortMode == _ItemSort.ratingDesc,
          child: const Text('Rating (high → low)'),
        ),
        CheckedPopupMenuItem(
          value: _ItemSort.dateDesc,
          checked: _sortMode == _ItemSort.dateDesc,
          child: const Text('Recently added'),
        ),
      ],
    );
  }

  /// True when the global (cross-category) search results should be shown
  /// instead of the per-tab list.
  bool get _isGlobalResults =>
      _isSearching &&
      _globalSearch &&
      !_isMasked &&
      _searchQuery.trim().isNotEmpty;

  /// Flat list of items across every category matching the current query.
  Widget _buildGlobalResults() {
    final q = _searchQuery.trim().toLowerCase();
    final results = <(RankingCategory, RankedItem)>[];
    for (final cat in categories) {
      for (final item in cat.items) {
        if (item.name.toLowerCase().contains(q) ||
            item.subtitle.toLowerCase().contains(q)) {
          results.add((cat, item));
        }
      }
    }

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 48, color: context.tokens.textDisabled),
            const SizedBox(height: 16),
            Text('No matching items found.',
                style: GoogleFonts.outfit(
                    color: context.tokens.textTertiary, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: results.length,
      itemBuilder: (ctx, i) {
        final (cat, item) = results[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                children: [
                  Icon(categoryIconFor(cat.iconName),
                      size: 12,
                      color: cat.colorValue == 0
                          ? context.tokens.textTertiary
                          : Color(cat.colorValue)),
                  const SizedBox(width: 6),
                  Text(
                    cat.title.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: context.tokens.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            _RankedItemTile(
              key: ValueKey('global_${cat.id}_${item.id}'),
              index: i,
              item: item,
              isMasked: _isMasked,
              showHandle: false,
              getRankGradient: _getRankGradient,
              onTap: () {
                if (activeId != cat.id) {
                  setState(() => activeId = cat.id);
                }
                _showItemDetail(item);
              },
            ),
          ],
        );
      },
    );
  }

  // ─── Drag Proxy ───────────────────────────────────────────────────────

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (ctx, _) {
        final scale = Tween<double>(begin: 1.0, end: 1.04)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut))
            .value;
        return Transform.scale(
          scale: scale,
          child: Material(
            color: Colors.transparent,
            child: child,
          ),
        );
      },
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  LinearGradient _getRankGradient(int rank) {
    if (rank == 1) {
      return const LinearGradient(colors: [AppColors.amber500, Colors.yellow]);
    }
    if (rank == 2) {
      return const LinearGradient(colors: [Colors.grey, Colors.white]);
    }
    if (rank == 3) {
      return const LinearGradient(colors: [Colors.orange, Colors.deepOrange]);
    }
    return const LinearGradient(
        colors: [AppColors.slate800, AppColors.slate900]);
  }

  Widget _glassTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: context.tokens.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.outfit(
              color: context.tokens.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
                color: context.tokens.textDisabled, fontSize: 14),
            filled: true,
            fillColor: context.tokens.surfaceGlassFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.tokens.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.tokens.glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.indigo500),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _glassActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact outlined button used to add a cover image from a source.
  Widget _coverSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: context.tokens.surfaceGlassFill,
          border: Border.all(color: context.tokens.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: context.tokens.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: context.tokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pick a cover image file (reference-only — no copy into app storage).
  Future<ImageReference?> _pickImageFromFile() async {
    try {
      final res = await FilePicker.platform
          .pickFiles(type: FileType.image, allowMultiple: false);
      final path = res?.files.single.path;
      if (path != null) return createFileImageRef(path);
    } catch (e) {
      debugPrint('Item image pick failed: $e');
    }
    return null;
  }

  /// Prompt for a validated image URL; returns an [ImageReference] or null.
  Future<ImageReference?> _promptImageUrl() async {
    final urlCtrl = TextEditingController();
    String? error;
    bool validating = false;
    return showDialog<ImageReference?>(
      context: context,
      builder: (dctx) => StatefulBuilder(builder: (dctx, setD) {
        return AlertDialog(
          backgroundColor: dctx.tokens.surfaceBase,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Image from URL',
              style: TextStyle(color: dctx.tokens.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlCtrl,
                style: TextStyle(color: dctx.tokens.textPrimary),
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'https://example.com/cover.jpg',
                  hintStyle: TextStyle(color: dctx.tokens.textTertiary),
                  errorText: error,
                ),
              ),
              if (validating)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: const Text('Cancel')),
            TextButton(
              onPressed: validating
                  ? null
                  : () async {
                      final url = urlCtrl.text.trim();
                      if (url.isEmpty) {
                        setD(() => error = 'URL cannot be empty');
                        return;
                      }
                      setD(() {
                        error = null;
                        validating = true;
                      });
                      final (valid, msg) = await validateImageUrl(url);
                      setD(() => validating = false);
                      if (!valid) {
                        setD(() => error = msg);
                        return;
                      }
                      if (dctx.mounted) {
                        Navigator.pop(dctx, createUrlImageRef(url));
                      }
                    },
              child: const Text('Add'),
            ),
          ],
        );
      }),
    );
  }

  Widget _dialogLabel(BuildContext ctx, String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: ctx.tokens.textTertiary,
        letterSpacing: 1.5,
      ),
    );
  }

  /// A selectable color swatch. [value] 0 is the "use theme accent" default.
  Widget _colorDot(
      BuildContext ctx, int value, bool selected, VoidCallback onTap) {
    final color = value == 0 ? ctx.tokens.accent : Color(value);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? ctx.tokens.textPrimary : Colors.transparent,
              width: 2,
            ),
          ),
          child: value == 0
              ? Icon(Icons.format_color_reset,
                  size: 15, color: ctx.tokens.textPrimary)
              : (selected
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : null),
        ),
      ),
    );
  }

  static Widget _buildStarRow(double rating,
      {double size = 16, Color emptyColor = Colors.white24}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        if (rating >= starValue) {
          return Icon(Icons.star_rounded,
              color: AppColors.amber500, size: size);
        } else if (rating >= starValue - 0.5) {
          return Icon(Icons.star_half_rounded,
              color: AppColors.amber500, size: size);
        } else {
          return Icon(Icons.star_outline_rounded,
              color: emptyColor, size: size);
        }
      }),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// ━━━ Ranked Item Tile ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _RankedItemTile extends StatelessWidget {
  final int index;
  final RankedItem item;
  final bool isMasked;
  final bool showHandle;
  final LinearGradient Function(int) getRankGradient;
  final VoidCallback onTap;

  const _RankedItemTile({
    super.key,
    required this.index,
    required this.item,
    required this.isMasked,
    required this.getRankGradient,
    required this.onTap,
    this.showHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: GlassContainer(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Cover image (if present and not masked) with a small rank chip,
              // else the gradient rank badge.
              if (item.image != null && !isMasked)
                SizedBox(
                  width: 42,
                  height: 42,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ImageThumbnailWidget(
                            imageRef: item.image!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(6),
                              bottomLeft: Radius.circular(10),
                            ),
                            gradient: getRankGradient(item.rank),
                          ),
                          child: Text(
                            "${item.rank}",
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: getRankGradient(item.rank),
                  ),
                  child: Text(
                    "${item.rank}",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMasked ? '••••••••' : item.name,
                      style: GoogleFonts.libreBaskerville(
                        color: context.tokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          isMasked ? '••••••••' : item.subtitle,
                          style: GoogleFonts.outfit(
                            color: context.tokens.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (item.rating > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _IdentityScreenState._buildStarRow(item.rating,
                            size: 14, emptyColor: context.tokens.textDisabled),
                      ),
                    _DriftIndicator(delta: _IdentityScreenState._driftDelta(item)),
                  ],
                ),
              ),

              // Drag handle (only when manual reordering is available)
              if (showHandle)
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: context.tokens.textDisabled,
                    size: 22,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ━━━ Drift Indicator ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Small ▲/▼ chip showing how far an item moved on its last reorder. Renders
/// nothing when there's no recorded movement.
class _DriftIndicator extends StatelessWidget {
  final int? delta;
  const _DriftIndicator({required this.delta});

  @override
  Widget build(BuildContext context) {
    final d = delta;
    if (d == null || d == 0) return const SizedBox.shrink();
    final up = d > 0;
    final color = up ? AppColors.emerald500 : AppColors.rose500;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '${d.abs()}',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━ Rank Sparkline ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// A tiny line chart of rank over time. Rank 1 (best) is drawn at the top, so
/// an upward-trending line means improving rank.
class _RankSparkline extends StatelessWidget {
  final List<RankSnapshot> history;
  final Color color;
  const _RankSparkline({required this.history, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: CustomPaint(
        painter: _RankSparklinePainter(history: history, color: color),
      ),
    );
  }
}

class _RankSparklinePainter extends CustomPainter {
  final List<RankSnapshot> history;
  final Color color;
  _RankSparklinePainter({required this.history, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;
    final ranks = history.map((s) => s.rank).toList();
    final minRank = ranks.reduce((a, b) => a < b ? a : b);
    final maxRank = ranks.reduce((a, b) => a > b ? a : b);
    final span = (maxRank - minRank);

    // Map each snapshot to a point. Lower rank (better) → higher on screen.
    double xFor(int i) =>
        history.length == 1 ? 0 : i / (history.length - 1) * size.width;
    double yFor(int rank) {
      if (span == 0) return size.height / 2;
      final t = (rank - minRank) / span; // 0 = best rank
      return t * (size.height - 8) + 4; // best at top
    }

    final path = Path();
    for (int i = 0; i < history.length; i++) {
      final p = Offset(xFor(i), yFor(history[i].rank));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Endpoint dot.
    final lastPoint =
        Offset(xFor(history.length - 1), yFor(history.last.rank));
    canvas.drawCircle(lastPoint, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RankSparklinePainter old) =>
      old.history != history || old.color != color;
}

// ━━━ Synced Tab Bar ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Lives INSIDE DefaultTabController's scope so didChangeDependencies can
// safely call DefaultTabController.of(context) without throwing.

class _SyncedTabBar extends StatefulWidget {
  final List<RankingCategory> categories;
  final String activeId;
  final ValueChanged<String> onTabChanged;
  final VoidCallback onCategoryOptions;

  const _SyncedTabBar({
    required this.categories,
    required this.activeId,
    required this.onTabChanged,
    required this.onCategoryOptions,
  });

  @override
  State<_SyncedTabBar> createState() => _SyncedTabBarState();
}

class _SyncedTabBarState extends State<_SyncedTabBar> {
  TabController? _tabCtrl;
  VoidCallback? _tabListener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newCtrl = DefaultTabController.of(context);
    if (newCtrl != _tabCtrl) {
      if (_tabListener != null) _tabCtrl?.removeListener(_tabListener!);
      _tabCtrl = newCtrl;
      _tabListener = () {
        if (!newCtrl.indexIsChanging && mounted) {
          if (newCtrl.index < widget.categories.length) {
            final newId = widget.categories[newCtrl.index].id;
            if (widget.activeId != newId) widget.onTabChanged(newId);
          }
        }
      };
      _tabCtrl!.addListener(_tabListener!);
    }
  }

  @override
  void dispose() {
    if (_tabListener != null) _tabCtrl?.removeListener(_tabListener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              color: context.tokens.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: context.tokens.textTertiary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
            tabs: widget.categories.map((cat) {
              return Tab(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        categoryIconFor(cat.iconName),
                        size: 13,
                        color: cat.colorValue == 0
                            ? null
                            : Color(cat.colorValue),
                      ),
                      const SizedBox(width: 6),
                      if (cat.isFavorite) ...[
                        const Icon(Icons.star,
                            size: 12, color: AppColors.amber500),
                        const SizedBox(width: 4),
                      ],
                      Text(cat.title.toUpperCase()),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: AppColors.slate400),
          onPressed: widget.onCategoryOptions,
        ),
      ],
    );
  }
}

// ━━━ Star Rating Picker ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _StarRatingPicker extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onChanged;

  const _StarRatingPicker({required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        final isFull = rating >= starIndex;
        final isHalf = !isFull && rating >= starIndex - 0.5;

        return GestureDetector(
          onTap: () {
            // Tap toggles between full star and half star
            if (rating == starIndex.toDouble()) {
              onChanged(starIndex - 0.5);
            } else {
              onChanged(starIndex.toDouble());
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              isFull
                  ? Icons.star_rounded
                  : isHalf
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded,
              color: isFull || isHalf
                  ? AppColors.amber500
                  : context.tokens.textDisabled,
              size: 36,
            ),
          ),
        );
      }),
    );
  }
}
