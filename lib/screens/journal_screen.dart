
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/types.dart';
import '../services/storage_service.dart';
import '../widgets/glass_widgets.dart';
import '../config/constants.dart';
import 'entry_editor.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<JournalEntry> entries = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await StorageService().getJournal();
    if (mounted) {
      setState(() {
        entries = data;
        isLoading = false;
      });
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
          await StorageService().saveJournalEntry(entry);
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
      body: Stack(
        children: [
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Journal",
                      style: GoogleFonts.outfit(
                        fontSize: 40,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                      ),
                    ),
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
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : entries.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 120, top: 20),
                        itemCount: entries.length,
                        itemBuilder: (ctx, i) => _buildEntryItem(entries[i]),
                      ),
              ),
            ],
          ),

          // FAB
          Positioned(
            bottom: 120,
            right: 24,
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
                      color: AppColors.indigo500.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book,
            size: 48,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            "Your journal is waiting.",
            style: TextStyle(color: Colors.white24),
          ),
        ],
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
                          color: color.withOpacity(0.5),
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
              child: GlassContainer(
                borderRadius: 24,
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.images.isNotEmpty)
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(entry.images.first),
                            fit: BoxFit.cover,
                          ),
                        ),
                        alignment: Alignment.bottomRight,
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          moodIcons[entry.mood] ?? '',
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (entry.images.isEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    color: color.withOpacity(0.1),
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
                          Divider(color: Colors.white.withOpacity(0.1)),
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
          ],
        ),
      ),
    );
  }
}
