import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/types.dart';
import '../config/constants.dart';
import '../widgets/glass_widgets.dart';

class IdentityScreen extends ConsumerStatefulWidget {
  const IdentityScreen({super.key});

  @override
  ConsumerState<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends ConsumerState<IdentityScreen> {
  List<RankingCategory> categories = [];
  String activeId = 'movies';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await ref.read(storageServiceProvider).getRankings();
    setState(() => categories = d);
  }

  RankingCategory get _activeCategory => categories.firstWhere(
        (c) => c.id == activeId,
        orElse: () => categories.first,
      );

  // ─── Add / Edit Dialog ────────────────────────────────────────────────

  Future<void> _showAddEditDialog({RankedItem? existingItem}) async {
    final nameCtrl = TextEditingController(text: existingItem?.name ?? '');
    final subtitleCtrl =
        TextEditingController(text: existingItem?.subtitle ?? '');
    final notesCtrl = TextEditingController(text: existingItem?.notes ?? '');
    double rating = existingItem?.rating ?? 0;
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
                                color: Colors.white,
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

                        // Rating
                        Text(
                          'RATING',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.slate400,
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
                            item.name,
                            style: GoogleFonts.libreBaskerville(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (item.subtitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                item.subtitle,
                                style: GoogleFonts.outfit(
                                  color: AppColors.slate400,
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
                    _buildStarRow(item.rating, size: 22),
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
                      color: AppColors.slate400,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      item.notes,
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Date
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 14, color: AppColors.slate400),
                    const SizedBox(width: 6),
                    Text(
                      'Added ${_formatDate(item.dateAdded)}',
                      style: GoogleFonts.outfit(
                        color: AppColors.slate400,
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
        backgroundColor: AppColors.slate900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove "${item.name}"?',
          style: GoogleFonts.outfit(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will remove it from your rankings. You can always add it back later.',
          style: GoogleFonts.outfit(color: AppColors.slate400),
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
      await ref
          .read(storageServiceProvider)
          .deleteRankedItem(activeId, item.id);
      await _load();
    }
  }

  // ─── Reorder Handler ──────────────────────────────────────────────────

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final items = List<RankedItem>.from(_activeCategory.items);
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    await ref.read(storageServiceProvider).reorderRankedItems(activeId, items);
    await _load();
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: categories.length,
      initialIndex: categories
          .indexWhere((c) => c.id == activeId)
          .clamp(0, categories.length - 1),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Preference Drift",
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "The evolution of your taste.",
                style: TextStyle(color: AppColors.slate400),
              ),
            ),
            const SizedBox(height: 24),

            // Tabs
            Builder(builder: (ctx) {
              final tabController = DefaultTabController.of(ctx);
              tabController.addListener(() {
                if (!tabController.indexIsChanging && ctx.mounted) {
                  final newId = categories[tabController.index].id;
                  if (activeId != newId) {
                    setState(() => activeId = newId);
                  }
                }
              });

              return TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                labelColor: Colors.black,
                unselectedLabelColor: AppColors.slate400,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                tabs: categories.map((cat) {
                  return Tab(
                    height: 40,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(cat.title.toUpperCase()),
                    ),
                  );
                }).toList(),
              );
            }),
            const SizedBox(height: 24),

            // TabBarView Content (Swipeable lists)
            Expanded(
              child: TabBarView(
                children: categories.map((cat) {
                  if (cat.items.isEmpty) {
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
                                  AppColors.indigo500.withValues(alpha: 0.2),
                                  AppColors.fuchsia500.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.emoji_events_outlined,
                              size: 40,
                              color: Colors.white24,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "No favourites ranked yet.",
                            style: GoogleFonts.outfit(
                                color: Colors.white38, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Tap + to add your first ${cat.title.toLowerCase()} item",
                            style: GoogleFonts.outfit(
                                color: Colors.white24, fontSize: 13),
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
                                    AppColors.fuchsia500,
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
                      ),
                    );
                  }

                  return ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    proxyDecorator: _proxyDecorator,
                    onReorder: (oldIndex, newIndex) {
                      // Ensure activeId matches current tab when reordering
                      if (activeId != cat.id) setState(() => activeId = cat.id);
                      _onReorder(oldIndex, newIndex);
                    },
                    itemCount: cat.items.length,
                    itemBuilder: (ctx, i) {
                      final item = cat.items[i];
                      return _RankedItemTile(
                        key: ValueKey(item.id),
                        index: i,
                        item: item,
                        getRankGradient: _getRankGradient,
                        onTap: () {
                          if (activeId != cat.id) {
                            setState(() => activeId = cat.id);
                          }
                          _showItemDetail(item);
                        },
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        floatingActionButton: Padding(
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
            color: AppColors.slate400,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(color: Colors.white24, fontSize: 14),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.08)),
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

  static Widget _buildStarRow(double rating, {double size = 16}) {
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
              color: Colors.white24, size: size);
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
  final LinearGradient Function(int) getRankGradient;
  final VoidCallback onTap;

  const _RankedItemTile({
    super.key,
    required this.index,
    required this.item,
    required this.getRankGradient,
    required this.onTap,
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
              // Rank badge
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
                      item.name,
                      style: GoogleFonts.libreBaskerville(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.subtitle,
                          style: GoogleFonts.outfit(
                            color: AppColors.slate400,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (item.rating > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _IdentityScreenState._buildStarRow(item.rating,
                            size: 14),
                      ),
                  ],
                ),
              ),

              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: Colors.white.withValues(alpha: 0.2),
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
              color: isFull || isHalf ? AppColors.amber500 : Colors.white24,
              size: 36,
            ),
          ),
        );
      }),
    );
  }
}
