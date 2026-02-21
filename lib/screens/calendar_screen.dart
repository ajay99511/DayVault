
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/types.dart';
import '../services/storage_service.dart';
import '../widgets/glass_widgets.dart';
import '../config/constants.dart';
import 'entry_editor.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _currentDate = DateTime.now();
  List<JournalEntry> _entries = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await StorageService().getJournal();
    if (mounted) {
      setState(() {
        _entries = data;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + delta, 1);
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
          await StorageService().saveJournalEntry(entry);
          await _loadData();
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_currentDate.year, _currentDate.month + 1, 0).day;
    // DateTime.weekday returns 1 for Monday, 7 for Sunday.
    // We want Sunday to be 0 for the grid, Monday 1, etc.
    final firstDayWeekday = DateTime(_currentDate.year, _currentDate.month, 1).weekday;
    final firstDayOffset = firstDayWeekday == 7 ? 0 : firstDayWeekday;

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
                    Text(
                      DateFormat('yyyy').format(_currentDate),
                      style: const TextStyle(fontSize: 18, color: AppColors.slate400),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _navBtn(Icons.chevron_left, () => _changeMonth(-1)),
                    const SizedBox(width: 8),
                    _navBtn(Icons.chevron_right, () => _changeMonth(1)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Calendar Grid
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
                          .map((d) => Text(d, style: const TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold)))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: GridView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: daysInMonth + firstDayOffset,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 4,
                        ),
                        itemBuilder: (ctx, i) {
                          if (i < firstDayOffset) return const SizedBox();
                          
                          final day = i - firstDayOffset + 1;
                          final date = DateTime(_currentDate.year, _currentDate.month, day);
                          final dayEntries = _getEntriesForDay(date);
                          final isToday = day == DateTime.now().day && 
                                          _currentDate.month == DateTime.now().month && 
                                          _currentDate.year == DateTime.now().year;
                          
                          final hasStory = dayEntries.any((e) => e.type == EntryType.story);
                          final hasEvent = dayEntries.any((e) => e.type == EntryType.event);

                          return GestureDetector(
                            onTap: () => _showDayDetails(context, date),
                            child: Container(
                              decoration: isToday ? const BoxDecoration(
                                gradient: LinearGradient(colors: [AppColors.indigo500, AppColors.fuchsia500]),
                                shape: BoxShape.circle
                              ) : null,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "$day", 
                                    style: TextStyle(
                                      color: isToday ? Colors.white : AppColors.slate400,
                                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal
                                    )
                                  ),
                                  if (hasStory || hasEvent)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (hasEvent)
                                            Container(width: 4, height: 4, margin:const EdgeInsets.symmetric(horizontal: 1), decoration: const BoxDecoration(color: AppColors.emerald500, shape: BoxShape.circle)),
                                          if (hasStory)
                                            Container(width: 4, height: 4, margin:const EdgeInsets.symmetric(horizontal: 1), decoration: const BoxDecoration(color: AppColors.indigo500, shape: BoxShape.circle)),
                                        ],
                                      ),
                                    )
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
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class DayDetailSheet extends StatelessWidget {
  final DateTime date;
  final List<JournalEntry> entries;
  final Function(EntryType) onAddEntry;

  const DayDetailSheet({
    super.key, 
    required this.date, 
    required this.entries, 
    required this.onAddEntry
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.slate900.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 50)],
      ),
      child: Stack(
        children: [
          // Background Glows
          Positioned(top: -50, right: -50, child: AnimatedOrb(width: 200, height: 200, color: AppColors.indigo500.withOpacity(0.1))),
          Positioned(bottom: -50, left: -50, child: AnimatedOrb(width: 200, height: 200, color: AppColors.emerald500.withOpacity(0.1))),

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
                          style: GoogleFonts.outfit(fontSize: 60, height: 1, fontWeight: FontWeight.w100, color: Colors.white),
                        ),
                        Text(
                          DateFormat('EEEE, MMMM d').format(date).toUpperCase(),
                          style: const TextStyle(color: AppColors.slate400, letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
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
                            Icon(Icons.calendar_today, size: 48, color: Colors.white.withOpacity(0.1)),
                            const SizedBox(height: 16),
                            const Text("No memories captured.", style: TextStyle(color: Colors.white24)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        itemCount: entries.length,
                        itemBuilder: (ctx, i) {
                          final entry = entries[i];
                          final isStory = entry.type == EntryType.story;
                          final color = isStory ? AppColors.indigo500 : AppColors.emerald500;
                          
                          return IntrinsicHeight(
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  child: Column(
                                    children: [
                                      Container(width: 2, height: 20, color: AppColors.slate800),
                                      Container(
                                        width: 12, height: 12,
                                        decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]),
                                      ),
                                      Expanded(child: Container(width: 2, color: AppColors.slate800)),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                child: Text(entry.type.name.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
                                              ),
                                              Text(moodIcons[entry.mood] ?? '', style: const TextStyle(fontSize: 16)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          if (entry.images.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(entry.images.first, height: 60, width: 60, fit: BoxFit.cover),
                                              ),
                                            ),
                                          Text(entry.headline, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(entry.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.slate400, fontSize: 12)),
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
                            boxShadow: [BoxShadow(color: AppColors.indigo500.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text("STORY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
                            boxShadow: [BoxShadow(color: AppColors.emerald500.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_on, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text("EVENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
