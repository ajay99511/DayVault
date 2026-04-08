import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/types.dart';
import '../widgets/image_widgets.dart';
import '../services/storage_service.dart';
import '../widgets/glass_widgets.dart';
import '../config/constants.dart';
import 'entry_editor.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _currentDate = DateTime.now();
  List<JournalEntry> _entries = [];
  bool _isLoading = true;
  String? _loadError;

  // To simulate infinite calendar scrolling (page 1200 = current month when initialized)
  static const int _initialPage = 1200;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage);
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final data = await ref.read(storageServiceProvider).getJournal();
      if (mounted) {
        setState(() {
          _entries = data;
          _isLoading = false;
          _loadError = null;
        });
      }
    } catch (e, st) {
      debugPrint('Calendar loading failed: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  void _changeMonth(int delta) {
    _pageController.animateToPage(
      (_pageController.page?.round() ?? _initialPage) + delta,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _jumpToToday() {
    final currentPage = _pageController.page?.round() ?? _initialPage;
    final diff = (_initialPage - currentPage).abs();

    if (diff > 12) {
      // If far away, jump instantly to prevent lag
      _pageController.jumpToPage(_initialPage);
    } else {
      // If close, animate smoothly
      _pageController.animateToPage(
        _initialPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _jumpToMonth(int targetYear, int targetMonth) {
    if (!mounted) return;
    final now = DateTime.now();
    // Calculate the total month offset from the current real-world month
    final targetOffset =
        (targetYear - now.year) * 12 + (targetMonth - now.month);
    final targetPage = _initialPage + targetOffset;

    // Immediately jump without animation to avoid rendering thousands of frames
    _pageController.jumpToPage(targetPage);
    setState(() {
      _currentDate = DateTime(targetYear, targetMonth, 1);
    });
  }

  void _onPageChanged(int index) {
    final monthOffset = index - _initialPage;
    final now = DateTime.now();
    setState(() {
      _currentDate = DateTime(now.year, now.month + monthOffset, 1);
    });
  }

  List<JournalEntry> _getEntriesForDay(DateTime date) {
    return _entries.where((e) {
      return e.date.year == date.year &&
          e.date.month == date.month &&
          e.date.day == date.day;
    }).toList();
  }

  void _showDayDetails(BuildContext context, DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DayDetailSheet(
        date: date,
        entries: _getEntriesForDay(date),
        onAddEntry: (type) {
          Navigator.pop(ctx);
          _openEditor(date, type);
        },
      ),
    );
  }

  void _openEditor(DateTime date, EntryType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EntryEditor(
        initialDate: date,
        initialType: type,
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          const SizedBox(height: 60),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMMM').format(_currentDate),
                      style: GoogleFonts.outfit(
                        fontSize: 40,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showYearSelector(context),
                      child: Row(
                        children: [
                          Text(
                            DateFormat('yyyy').format(_currentDate),
                            style: const TextStyle(
                                fontSize: 18, color: AppColors.slate400),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down,
                              color: AppColors.slate400, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _navBtn(Icons.today, _jumpToToday),
                    const SizedBox(width: 12),
                    _navBtn(Icons.chevron_left, () => _changeMonth(-1)),
                    const SizedBox(width: 8),
                    _navBtn(Icons.chevron_right, () => _changeMonth(1)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Calendar Grid Wrapper
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassContainer(
                child: Column(
                  children: [
                    // Week headers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                          .map((d) => Text(d,
                              style: const TextStyle(
                                  color: AppColors.slate400,
                                  fontWeight: FontWeight.bold)))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    // Swipeable area
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (ctx, index) {
                          // Calculate the date for the current page
                          final monthOffset = index - _initialPage;
                          final now = DateTime.now();
                          final pageDate =
                              DateTime(now.year, now.month + monthOffset, 1);

                          final daysInMonth =
                              DateTime(pageDate.year, pageDate.month + 1, 0)
                                  .day;
                          final firstDayWeekday =
                              DateTime(pageDate.year, pageDate.month, 1)
                                  .weekday;
                          final firstDayOffset =
                              firstDayWeekday == 7 ? 0 : firstDayWeekday;

                          return GridView.builder(
                            padding: EdgeInsets.zero,
                            physics:
                                const NeverScrollableScrollPhysics(), // Scroll handled by PageView
                            itemCount: daysInMonth + firstDayOffset,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 4,
                            ),
                            itemBuilder: (ctx, i) {
                              if (i < firstDayOffset) return const SizedBox();

                              final day = i - firstDayOffset + 1;
                              final date =
                                  DateTime(pageDate.year, pageDate.month, day);
                              final dayEntries = _getEntriesForDay(date);
                              final isToday = day == now.day &&
                                  pageDate.month == now.month &&
                                  pageDate.year == now.year;

                              final hasStory = dayEntries
                                  .any((e) => e.type == EntryType.story);
                              final hasEvent = dayEntries
                                  .any((e) => e.type == EntryType.event);

                              return GestureDetector(
                                onTap: () => _showDayDetails(context, date),
                                child: Container(
                                  decoration: isToday
                                      ? const BoxDecoration(
                                          gradient: LinearGradient(colors: [
                                            AppColors.indigo500,
                                            AppColors.fuchsia500
                                          ]),
                                          shape: BoxShape.circle)
                                      : null,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text("$day",
                                          style: TextStyle(
                                              color: isToday
                                                  ? Colors.white
                                                  : AppColors.slate400,
                                              fontWeight: isToday
                                                  ? FontWeight.bold
                                                  : FontWeight.normal)),
                                      if (hasStory || hasEvent)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              if (hasEvent)
                                                Container(
                                                    width: 4,
                                                    height: 4,
                                                    margin: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 1),
                                                    decoration:
                                                        const BoxDecoration(
                                                            color:
                                                                AppColors
                                                                    .emerald500,
                                                            shape: BoxShape
                                                                .circle)),
                                              if (hasStory)
                                                Container(
                                                    width: 4,
                                                    height: 4,
                                                    margin: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 1),
                                                    decoration:
                                                        const BoxDecoration(
                                                            color: AppColors
                                                                .indigo500,
                                                            shape: BoxShape
                                                                .circle)),
                                            ],
                                          ),
                                        )
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  void _showYearSelector(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(100, (index) => currentYear - 50 + index);

    // Find initial scroll index
    final initialIndex = years.indexOf(_currentDate.year);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: BoxDecoration(
            color: AppColors.slate900.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Select Year",
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2,
                  ),
                  itemCount: years.length,
                  // Use a controller to jump near the currently viewed year
                  controller: ScrollController(
                    initialScrollOffset: (initialIndex / 4).floor() * 46.0,
                  ),
                  itemBuilder: (ctx, i) {
                    final year = years[i];
                    final isSelected = year == _currentDate.year;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        if (year == currentYear) {
                          _jumpToToday();
                        } else {
                          // Jump to Jan of selected year
                          _jumpToMonth(year, 1);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.indigo500
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.fuchsia500, width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          year.toString(),
                          style: GoogleFonts.outfit(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DayDetailSheet extends StatelessWidget {
  final DateTime date;
  final List<JournalEntry> entries;
  final Function(EntryType) onAddEntry;

  const DayDetailSheet(
      {super.key,
      required this.date,
      required this.entries,
      required this.onAddEntry});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.slate900.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 50)
        ],
      ),
      child: Stack(
        children: [
          // Background Glows
          Positioned(
              top: -50,
              right: -50,
              child: AnimatedOrb(
                  width: 200,
                  height: 200,
                  color: AppColors.indigo500.withValues(alpha: 0.1))),
          Positioned(
              bottom: -50,
              left: -50,
              child: AnimatedOrb(
                  width: 200,
                  height: 200,
                  color: AppColors.emerald500.withValues(alpha: 0.1))),

          Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${date.day}",
                          style: GoogleFonts.outfit(
                              fontSize: 60,
                              height: 1,
                              fontWeight: FontWeight.w100,
                              color: Colors.white),
                        ),
                        Text(
                          DateFormat('EEEE, MMMM d').format(date).toUpperCase(),
                          style: const TextStyle(
                              color: AppColors.slate400,
                              letterSpacing: 2,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                    )
                  ],
                ),
              ),

              // Content List
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today,
                                size: 48,
                                color: Colors.white.withValues(alpha: 0.1)),
                            const SizedBox(height: 16),
                            const Text("No memories captured.",
                                style: TextStyle(color: Colors.white24)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                        itemCount: entries.length,
                        itemBuilder: (ctx, i) {
                          final entry = entries[i];
                          final isStory = entry.type == EntryType.story;
                          final color = isStory
                              ? AppColors.indigo500
                              : AppColors.emerald500;

                          return IntrinsicHeight(
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  child: Column(
                                    children: [
                                      Container(
                                          width: 2,
                                          height: 20,
                                          color: AppColors.slate800),
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                  color: color.withValues(
                                                      alpha: 0.5),
                                                  blurRadius: 8)
                                            ]),
                                      ),
                                      Expanded(
                                          child: Container(
                                              width: 2,
                                              color: AppColors.slate800)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    child: GlassContainer(
                                      padding: const EdgeInsets.all(16),
                                      borderRadius: 16,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                    color: color.withValues(
                                                        alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4)),
                                                child: Text(
                                                    entry.type.name
                                                        .toUpperCase(),
                                                    style: TextStyle(
                                                        color: color,
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                              Text(moodIcons[entry.mood] ?? '',
                                                  style: const TextStyle(
                                                      fontSize: 16)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          if (entry.images.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: SizedBox(
                                                  width: 60,
                                                  height: 60,
                                                  child: ImageThumbnailWidget(
                                                    imageRef:
                                                        entry.images.first,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          Text(entry.headline,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(entry.content,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: AppColors.slate400,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onAddEntry(EntryType.story),
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                              color: AppColors.indigo500,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.indigo500
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4))
                              ]),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text("STORY",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onAddEntry(EntryType.event),
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                              color: AppColors.emerald500,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.emerald500
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4))
                              ]),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_on,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text("EVENT",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}
