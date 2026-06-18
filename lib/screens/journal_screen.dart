import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/types.dart';
import '../services/storage_service.dart';
import '../utils/debouncer.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/image_widgets.dart';
import '../config/constants.dart';
import 'entry_editor.dart';
import 'journal_viewer_screen.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  /// Apply the active filters to [entries]. Pure + static for unit testing.
  ///
  /// - [query]: case-insensitive substring match over headline, content, tags.
  /// - [spotlightOnly]: keep only spotlighted entries.
  /// - [selectedTags]: keep entries carrying at least one selected tag (OR);
  ///   matching is case-insensitive. Empty set means "no tag filter".
  static List<JournalEntry> filterEntries(
    List<JournalEntry> entries, {
    String query = '',
    bool spotlightOnly = false,
    Set<String> selectedTags = const {},
  }) {
    final q = query.trim().toLowerCase();
    final wanted = selectedTags.map((t) => t.toLowerCase()).toSet();

    return entries.where((e) {
      if (spotlightOnly && !e.isSpotlight) return false;

      if (wanted.isNotEmpty) {
        final entryTags = e.tags.map((t) => t.toLowerCase()).toSet();
        if (entryTags.intersection(wanted).isEmpty) return false;
      }

      if (q.isNotEmpty) {
        final inText = e.headline.toLowerCase().contains(q) ||
            e.content.toLowerCase().contains(q);
        final inTags = e.tags.any((t) => t.toLowerCase().contains(q));
        if (!inText && !inTags) return false;
      }

      return true;
    }).toList();
  }

  /// Distinct tags present across [entries], sorted case-insensitively.
  /// First-seen original casing is preserved for display.
  static List<String> availableTags(List<JournalEntry> entries) {
    final seen = <String, String>{}; // lowercase -> display
    for (final e in entries) {
      for (final t in e.tags) {
        seen.putIfAbsent(t.toLowerCase(), () => t);
      }
    }
    final result = seen.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  List<JournalEntry> entries = [];
  bool isLoading = true;
  String? loadError;

  // Search state
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Filter state
  bool _spotlightOnly = false;
  final Set<String> _selectedTags = {};
  final Debouncer _searchDebouncer =
      Debouncer(delay: const Duration(milliseconds: 300));

  /// Debounced search update — coalesces rapid keystrokes into one rebuild.
  void _onSearchChanged(String value) {
    _searchDebouncer.run(() {
      if (mounted) setState(() => _searchQuery = value);
    });
  }

  /// Clear the query immediately (cancels any pending debounced update).
  void _clearSearch() {
    _searchDebouncer.cancel();
    _searchCtrl.clear();
    setState(() => _searchQuery = '');
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await ref.read(storageServiceProvider).getJournal();
      if (mounted) {
        setState(() {
          entries = data;
          isLoading = false;
          loadError = null;
        });
      }
    } catch (e, st) {
      debugPrint('Journal loading failed: $e\n$st');
      if (mounted) {
        setState(() {
          isLoading = false;
          loadError = e.toString();
        });
      }
    }
  }

  void _openEditor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EntryEditor(
        initialDate: DateTime.now(),
        onCancel: () => Navigator.pop(ctx),
        onSave: (entry) async {
          await ref.read(storageServiceProvider).saveJournalEntry(entry);
          await _loadData();
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filtered entries
    final filteredEntries = JournalScreen.filterEntries(
      entries,
      query: _searchQuery,
      spotlightOnly: _spotlightOnly,
      selectedTags: _selectedTags,
    );
    final availableTags = JournalScreen.availableTags(entries);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Content
          ResponsiveCenter(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 16),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!_isSearching)
                      Text(
                        "Journal",
                        style: GoogleFonts.outfit(
                          fontSize: 40,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                        ),
                      ),

                    // Search Bar / Actions
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
                                    const Icon(Icons.search,
                                        color: AppColors.slate400, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchCtrl,
                                        autofocus: true,
                                        onChanged: _onSearchChanged,
                                        style: GoogleFonts.outfit(
                                            color: Colors.white, fontSize: 14),
                                        decoration: InputDecoration(
                                          hintText: 'Search memories...',
                                          hintStyle: GoogleFonts.outfit(
                                              color: Colors.white54,
                                              fontSize: 14),
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    if (_searchQuery.isNotEmpty)
                                      GestureDetector(
                                        onTap: _clearSearch,
                                        child: const Icon(Icons.close,
                                            color: AppColors.slate400,
                                            size: 16),
                                      ),
                                  ],
                                ),
                              ),
                            )
                          else
                            GlassContainer(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              borderRadius: 20,
                              child: Text(
                                "${entries.length} Memories",
                                style: const TextStyle(
                                  color: AppColors.slate400,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isSearching = !_isSearching;
                                if (!_isSearching) {
                                  _searchDebouncer.cancel();
                                  _searchCtrl.clear();
                                  _searchQuery = '';
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isSearching ? Icons.close : Icons.search,
                                color: Colors.white,
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
              const SizedBox(height: 12),
              if (!isLoading && loadError == null && entries.isNotEmpty)
                _buildFilterBar(availableTags),
              const SizedBox(height: 8),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : loadError != null
                        ? _buildErrorState()
                        : filteredEntries.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.only(bottom: 120, top: 20),
                                itemCount: filteredEntries.length,
                                itemBuilder: (ctx, i) =>
                                    _buildEntryItem(filteredEntries[i]),
                              ),
              ),
            ],
          ),
          ),

          // FAB — aligned to the right edge of the centered content column so
          // it stays visually attached on wide (tablet/desktop) layouts.
          Positioned(
            bottom: 120,
            right: 24 +
                (MediaQuery.of(context).size.width -
                            Breakpoints.contentMaxWidth)
                        .clamp(0, double.infinity) /
                    2,
            child: GestureDetector(
              onTap: _openEditor,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.indigo500, AppColors.fuchsia500],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.indigo500.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(List<String> availableTags) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          // Spotlight filter.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Spotlight'),
              avatar: Icon(
                _spotlightOnly ? Icons.star : Icons.star_border,
                size: 16,
                color: _spotlightOnly ? AppColors.amber500 : Colors.white54,
              ),
              selected: _spotlightOnly,
              showCheckmark: false,
              labelStyle: const TextStyle(fontSize: 12, color: Colors.white),
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              selectedColor: AppColors.amber500.withValues(alpha: 0.25),
              side: BorderSide(
                color: _spotlightOnly
                    ? AppColors.amber500.withValues(alpha: 0.5)
                    : Colors.white12,
              ),
              onSelected: (v) => setState(() => _spotlightOnly = v),
            ),
          ),
          // Tag filters.
          ...availableTags.map((tag) {
            final selected = _selectedTags.contains(tag);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(tag),
                selected: selected,
                showCheckmark: false,
                labelStyle: const TextStyle(fontSize: 12, color: Colors.white),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                selectedColor: AppColors.indigo500.withValues(alpha: 0.3),
                side: BorderSide(
                  color: selected
                      ? AppColors.indigo500.withValues(alpha: 0.6)
                      : Colors.white12,
                ),
                onSelected: (v) => setState(() {
                  if (v) {
                    _selectedTags.add(tag);
                  } else {
                    _selectedTags.remove(tag);
                  }
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isSearching ? Icons.search_off : Icons.menu_book,
            size: 48,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching
                ? "No matching memories found."
                : "Your journal is waiting.",
            style: const TextStyle(color: Colors.white24),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            const Text(
              "Failed to Load Memories",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "There was a problem loading your journal entries.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryItem(JournalEntry entry) {
    final isStory = entry.type == EntryType.story;
    final color = isStory ? AppColors.indigo500 : AppColors.emerald500;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline Line
            SizedBox(
              width: 20,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(width: 2, color: AppColors.slate800),
                  Container(
                    margin: const EdgeInsets.only(top: 24),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.slate950, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Card
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JournalViewerScreen(entry: entry),
                    ),
                  );
                  if (result == true) {
                    _loadData(); // Refresh list if entry was edited or deleted
                  }
                },
                child: GlassContainer(
                  borderRadius: 24,
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.images.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ImageThumbnailWidget(
                                  imageRef: entry.images.first,
                                  fit: BoxFit.cover,
                                  showTapToZoom: true,
                                ),
                                // Gradient overlay at bottom for text readability
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 60,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.4),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Mood badge
                                Positioned(
                                  bottom: 8,
                                  right: 12,
                                  child: Text(
                                    moodIcons[entry.mood] ?? '',
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (entry.images.isEmpty)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    moodIcons[entry.mood] ?? '',
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isStory
                                          ? (entry.feeling ?? 'STORY')
                                          : (entry.timeBucket
                                                  ?.toString()
                                                  .split('.')
                                                  .last ??
                                              'EVENT'),
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            Text(
                              entry.headline,
                              style: isStory
                                  ? GoogleFonts.libreBaskerville(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    )
                                  : GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              entry.content,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.slate400,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Divider(color: Colors.white.withValues(alpha: 0.1)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: AppColors.slate400,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "${entry.date.day}/${entry.date.month}",
                                  style: const TextStyle(
                                    color: AppColors.slate400,
                                    fontSize: 10,
                                  ),
                                ),
                                if (entry.location != null) ...[
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.location_on,
                                    size: 12,
                                    color: AppColors.emerald500,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      entry.location!.name,
                                      style: const TextStyle(
                                        color: AppColors.slate400,
                                        fontSize: 10,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
