import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/types.dart';
import '../models/paged_result.dart';
import '../services/storage_service.dart';
import '../utils/debouncer.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/image_widgets.dart';
import '../config/constants.dart';
import '../theme/app_tokens.dart';
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
    Set<EntryType> selectedTypes = const {},
    Set<Mood> selectedMoods = const {},
  }) {
    final q = query.trim().toLowerCase();
    final wanted = selectedTags.map((t) => t.toLowerCase()).toSet();

    return entries.where((e) {
      if (spotlightOnly && !e.isSpotlight) return false;

      if (selectedTypes.isNotEmpty && !selectedTypes.contains(e.type)) {
        return false;
      }

      if (selectedMoods.isNotEmpty && !selectedMoods.contains(e.mood)) {
        return false;
      }

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

  // Pagination state. The list is loaded a page at a time while browsing
  // (no filter). When a search/filter is active we load the full set once so
  // results are correct across the entire journal, then filter in memory.
  static const int _pageSize = 20;
  PaginationCursor? _cursor;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  bool _showingFullSet = false;
  int _totalCount = 0;
  final ScrollController _scrollController = ScrollController();

  // Scroll-to-top affordance. Appears once the user has scrolled past roughly
  // one viewport so it never clutters the top of a short list. The flag is only
  // flipped when the threshold is *crossed* (not on every scroll frame) to keep
  // scrolling cheap.
  static const double _scrollTopThreshold = 600;
  bool _showScrollToTop = false;

  // "On this day" — past-year memories for today's calendar day.
  List<JournalEntry> _onThisDay = const [];
  bool _onThisDayDismissed = false;

  // Search state
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Filter state
  bool _spotlightOnly = false;
  final Set<String> _selectedTags = {};
  final Set<EntryType> _selectedTypes = {};
  final Set<Mood> _selectedMoods = {};
  final Debouncer _searchDebouncer =
      Debouncer(delay: const Duration(milliseconds: 300));

  /// True when any search/filter is active — in this mode we need the complete
  /// entry set for correct results and disable lazy pagination.
  bool get _isFilterActive =>
      _searchQuery.trim().isNotEmpty ||
      _spotlightOnly ||
      _selectedTags.isNotEmpty ||
      _selectedTypes.isNotEmpty ||
      _selectedMoods.isNotEmpty;

  /// Debounced search update — coalesces rapid keystrokes into one rebuild.
  void _onSearchChanged(String value) {
    _searchDebouncer.run(() {
      if (mounted) {
        setState(() => _searchQuery = value);
        _syncLoadMode();
      }
    });
  }

  /// Clear the query immediately (cancels any pending debounced update).
  void _clearSearch() {
    _searchDebouncer.cancel();
    _searchCtrl.clear();
    setState(() => _searchQuery = '');
    _syncLoadMode();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _reload();
    _loadOnThisDay();
  }

  /// Load past-year memories for today. Best-effort: failures just hide the
  /// banner and are never surfaced as errors.
  Future<void> _loadOnThisDay() async {
    try {
      final memories =
          await ref.read(storageServiceProvider).getOnThisDay(DateTime.now());
      if (mounted) setState(() => _onThisDay = memories);
    } catch (e, st) {
      debugPrint('On this day load failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _searchCtrl.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Append the next page when the user scrolls within ~600px of the bottom,
  /// and toggle the scroll-to-top affordance when the threshold is crossed.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 600) {
      _loadNextPage();
    }

    final shouldShow = pos.pixels > _scrollTopThreshold;
    if (shouldShow != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShow);
    }
  }

  /// Smoothly return to the top of the list.
  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  /// Reload from scratch using whichever mode the current filter state implies.
  Future<void> _reload() async {
    if (_isFilterActive) {
      await _loadFullSet();
    } else {
      await _loadFirstPage();
    }
  }

  /// Switch between paged browsing and full-set filtering when the active
  /// filter state changes. Re-filtering within the full set (e.g. extra
  /// keystrokes) needs no reload — only the mode transitions do.
  void _syncLoadMode() {
    if (_isFilterActive && !_showingFullSet) {
      _loadFullSet();
    } else if (!_isFilterActive && _showingFullSet) {
      _loadFirstPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });
    try {
      final page =
          await ref.read(storageServiceProvider).getJournalPage(_pageSize);
      if (!mounted) return;
      setState(() {
        entries = page.items;
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _showingFullSet = false;
        _totalCount = ref.read(storageServiceProvider).journalCount();
        _showScrollToTop = false;
        isLoading = false;
      });
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

  Future<void> _loadFullSet() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });
    try {
      final data = await ref.read(storageServiceProvider).getJournal();
      if (!mounted) return;
      setState(() {
        entries = data;
        _cursor = null;
        _hasMore = false;
        _showingFullSet = true;
        _totalCount = data.length;
        _showScrollToTop = false;
        isLoading = false;
      });
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

  /// Append the next page while browsing. No-op while filtering or when there
  /// is nothing more to load. On failure the list and cursor are preserved so
  /// scrolling again retries (Req 6.7).
  Future<void> _loadNextPage() async {
    if (_isLoadingMore || !_hasMore || _showingFullSet) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await ref
          .read(storageServiceProvider)
          .getJournalPage(_pageSize, _cursor);
      if (!mounted) return;
      setState(() {
        entries = [...entries, ...page.items];
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _isLoadingMore = false;
      });
    } catch (e, st) {
      debugPrint('Journal page load failed: $e\n$st');
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load more entries.')),
        );
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
        tagSuggestions: JournalScreen.availableTags(entries),
        onCancel: () => Navigator.pop(ctx),
        onSave: (entry) async {
          await ref.read(storageServiceProvider).saveJournalEntry(entry);
          // Notify all journal-backed screens (including this one, via the
          // revision listener in build) to refresh.
          ref.read(journalRevisionProvider.notifier).bump();
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A mutation anywhere (this screen, the calendar, or the viewer) bumps the
    // revision — reload so the list never shows stale data.
    ref.listen(journalRevisionProvider, (_, __) {
      _reload();
      _loadOnThisDay();
    });

    // Filtered entries
    final filteredEntries = JournalScreen.filterEntries(
      entries,
      query: _searchQuery,
      spotlightOnly: _spotlightOnly,
      selectedTags: _selectedTags,
      selectedTypes: _selectedTypes,
      selectedMoods: _selectedMoods,
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
                          color: context.tokens.textPrimary,
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
                                    Icon(Icons.search,
                                        color: context.tokens.textTertiary,
                                        size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchCtrl,
                                        autofocus: true,
                                        onChanged: _onSearchChanged,
                                        style: GoogleFonts.outfit(
                                            color: context.tokens.textPrimary,
                                            fontSize: 14),
                                        decoration: InputDecoration(
                                          hintText: 'Search memories...',
                                          hintStyle: GoogleFonts.outfit(
                                              color: context.tokens.textTertiary,
                                              fontSize: 14),
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    if (_searchQuery.isNotEmpty)
                                      GestureDetector(
                                        onTap: _clearSearch,
                                        child: Icon(Icons.close,
                                            color: context.tokens.textTertiary,
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
                                "$_totalCount Memories",
                                style: TextStyle(
                                  color: context.tokens.textTertiary,
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
                              // Leaving search may clear the active filter —
                              // switch back to paged browsing if so.
                              _syncLoadMode();
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
              const SizedBox(height: 12),
              if (!isLoading && loadError == null && entries.isNotEmpty)
                _buildFilterBar(availableTags),
              // "On this day" memory banner — only when browsing (not filtering).
              if (!_isFilterActive &&
                  !_onThisDayDismissed &&
                  _onThisDay.isNotEmpty)
                _buildOnThisDayBanner(),
              const SizedBox(height: 8),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : loadError != null
                        ? _buildErrorState()
                        : filteredEntries.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                controller: _scrollController,
                                padding:
                                    const EdgeInsets.only(bottom: 120, top: 20),
                                // One extra slot for the paging footer.
                                itemCount: filteredEntries.length +
                                    (_hasMore ? 1 : 0),
                                itemBuilder: (ctx, i) {
                                  if (i >= filteredEntries.length) {
                                    return _buildPagingFooter();
                                  }
                                  return _buildEntryItem(filteredEntries[i]);
                                },
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

          // Scroll-to-top — fades/slides in once past one viewport, sitting just
          // above the add FAB and sharing its wide-layout right alignment.
          Positioned(
            bottom: 196,
            right: 32 +
                (MediaQuery.of(context).size.width -
                            Breakpoints.contentMaxWidth)
                        .clamp(0, double.infinity) /
                    2,
            child: IgnorePointer(
              ignoring: !_showScrollToTop,
              child: AnimatedSlide(
                offset: _showScrollToTop ? Offset.zero : const Offset(0, 0.4),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: _showScrollToTop ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: _scrollToTop,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.tokens.surfaceGlassFill,
                        border: Border.all(color: context.tokens.glassBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_up,
                        color: context.tokens.textPrimary,
                        size: 26,
                      ),
                    ),
                  ),
                ),
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
              labelStyle: TextStyle(
                  fontSize: 12, color: context.tokens.textPrimary),
              backgroundColor: context.tokens.surfaceGlassFill,
              selectedColor: AppColors.amber500.withValues(alpha: 0.25),
              side: BorderSide(
                color: _spotlightOnly
                    ? AppColors.amber500.withValues(alpha: 0.5)
                    : context.tokens.glassBorder,
              ),
              onSelected: (v) {
                setState(() => _spotlightOnly = v);
                _syncLoadMode();
              },
            ),
          ),
          // Type filters (Story / Event).
          _typeChip(EntryType.story, 'Stories', AppColors.indigo500),
          _typeChip(EntryType.event, 'Events', AppColors.emerald500),
          // Mood filter (multi-select via a bottom sheet).
          _moodFilterChip(),
          // Tag filters.
          ...availableTags.map((tag) {
            final selected = _selectedTags.contains(tag);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(tag),
                selected: selected,
                showCheckmark: false,
                labelStyle: TextStyle(
                    fontSize: 12, color: context.tokens.textPrimary),
                backgroundColor: context.tokens.surfaceGlassFill,
                selectedColor: AppColors.indigo500.withValues(alpha: 0.3),
                side: BorderSide(
                  color: selected
                      ? AppColors.indigo500.withValues(alpha: 0.6)
                      : context.tokens.glassBorder,
                ),
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                  _syncLoadMode();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  /// A Story/Event type filter chip.
  Widget _typeChip(EntryType type, String label, Color color) {
    final selected = _selectedTypes.contains(type);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        labelStyle:
            TextStyle(fontSize: 12, color: context.tokens.textPrimary),
        backgroundColor: context.tokens.surfaceGlassFill,
        selectedColor: color.withValues(alpha: 0.3),
        side: BorderSide(
          color: selected
              ? color.withValues(alpha: 0.6)
              : context.tokens.glassBorder,
        ),
        onSelected: (v) {
          setState(() {
            if (v) {
              _selectedTypes.add(type);
            } else {
              _selectedTypes.remove(type);
            }
          });
          _syncLoadMode();
        },
      ),
    );
  }

  /// Mood filter chip — opens a multi-select sheet of moods.
  Widget _moodFilterChip() {
    final active = _selectedMoods.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(active ? 'Mood (${_selectedMoods.length})' : 'Mood'),
        avatar: Icon(Icons.mood,
            size: 16,
            color: active ? AppColors.fuchsia500 : Colors.white54),
        selected: active,
        showCheckmark: false,
        labelStyle:
            TextStyle(fontSize: 12, color: context.tokens.textPrimary),
        backgroundColor: context.tokens.surfaceGlassFill,
        selectedColor: AppColors.fuchsia500.withValues(alpha: 0.3),
        side: BorderSide(
          color: active
              ? AppColors.fuchsia500.withValues(alpha: 0.6)
              : context.tokens.glassBorder,
        ),
        onSelected: (_) => _openMoodFilterSheet(),
      ),
    );
  }

  /// Bottom sheet to pick which moods to keep. Mutates a local copy and applies
  /// on close so the list isn't rebuilt on every toggle.
  Future<void> _openMoodFilterSheet() async {
    final working = {..._selectedMoods};
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.slate900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filter by mood',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        if (working.isNotEmpty)
                          TextButton(
                            onPressed: () =>
                                setSheetState(() => working.clear()),
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: Mood.values.map((mood) {
                        final sel = working.contains(mood);
                        return GestureDetector(
                          onTap: () => setSheetState(() {
                            if (sel) {
                              working.remove(mood);
                            } else {
                              working.add(mood);
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.fuchsia500.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel
                                    ? AppColors.fuchsia500
                                    : Colors.white12,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(moodIcons[mood] ?? '',
                                    style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 6),
                                Text(mood.name,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.indigo500,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted) return;
    setState(() {
      _selectedMoods
        ..clear()
        ..addAll(working);
    });
    _syncLoadMode();
  }

  /// "On this day" banner summarising past-year memories for today.
  Widget _buildOnThisDayBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: GestureDetector(
        onTap: _showOnThisDaySheet,
        child: GlassContainer(
          borderRadius: 16,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.fuchsia500.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome,
                    color: AppColors.fuchsia500, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'On this day',
                      style: TextStyle(
                        color: context.tokens.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _onThisDay.length == 1
                          ? '1 memory from a previous year'
                          : '${_onThisDay.length} memories from previous years',
                      style: TextStyle(
                        color: context.tokens.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close,
                    size: 18, color: context.tokens.textTertiary),
                tooltip: 'Dismiss',
                onPressed: () => setState(() => _onThisDayDismissed = true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom sheet listing the "On this day" memories; tapping one opens it.
  void _showOnThisDaySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.slate900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('On this day',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Memories from previous years',
                    style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _onThisDay.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final entry = _onThisDay[i];
                      final isStory = entry.type == EntryType.story;
                      final color = isStory
                          ? AppColors.indigo500
                          : AppColors.emerald500;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  JournalViewerScreen(entry: entry),
                            ),
                          );
                        },
                        child: GlassContainer(
                          borderRadius: 14,
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              if (entry.images.isNotEmpty) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: ImageThumbnailWidget(
                                      imageRef: entry.images.first,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('${entry.date.year}',
                                        style: TextStyle(
                                            color: color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(entry.headline,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              Text(moodIcons[entry.mood] ?? '',
                                  style: const TextStyle(fontSize: 18)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Footer shown beneath the list while the next page is being fetched.
  Widget _buildPagingFooter() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
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
            color: context.tokens.textDisabled,
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching
                ? "No matching memories found."
                : "Your journal is waiting.",
            style: TextStyle(color: context.tokens.textTertiary),
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
            Text(
              "Failed to Load Memories",
              style: TextStyle(
                color: context.tokens.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "There was a problem loading your journal entries.",
              textAlign: TextAlign.center,
              style: TextStyle(color: context.tokens.textTertiary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _reload,
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
                  Container(width: 2, color: context.tokens.divider),
                  Container(
                    margin: const EdgeInsets.only(top: 24),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: context.tokens.surfaceBase, width: 2),
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
                // Edits/deletes in the viewer bump the journal revision, which
                // the build-method listener picks up to refresh the list.
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => JournalViewerScreen(entry: entry),
                  ),
                ),
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
                                          : (entry.timeBucket != null
                                              ? timeBucketLabel(
                                                  entry.timeBucket!)
                                              : 'EVENT'),
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
                                      color: context.tokens.textPrimary,
                                    )
                                  : GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: context.tokens.textPrimary,
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              entry.content,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.tokens.textSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Divider(color: context.tokens.divider),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: context.tokens.textTertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "${entry.date.day}/${entry.date.month}",
                                  style: TextStyle(
                                    color: context.tokens.textTertiary,
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
                                      style: TextStyle(
                                        color: context.tokens.textTertiary,
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
