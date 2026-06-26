import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/types.dart';
import '../services/storage_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/image_widgets.dart';
import '../config/constants.dart';
import 'entry_editor.dart';

class JournalViewerScreen extends ConsumerStatefulWidget {
  final JournalEntry entry;

  const JournalViewerScreen({super.key, required this.entry});

  @override
  ConsumerState<JournalViewerScreen> createState() =>
      _JournalViewerScreenState();
}

class _JournalViewerScreenState extends ConsumerState<JournalViewerScreen> {
  // Local mutable copy so an edit reflects in place rather than popping the
  // screen back to the list.
  late JournalEntry _entry;

  // Whether anything changed this session. Returned on back so the calendar's
  // day sheet (which holds a pre-edit snapshot) can close/refresh.
  bool _changed = false;

  JournalEntry get entry => _entry;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.slate900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text('Delete Entry?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              // Capture the full entry and provider handles BEFORE popping the
              // screen — this State (and its `ref`) is disposed on pop, but the
              // SnackBar's UNDO runs afterwards. The root ScaffoldMessenger and
              // the revision notifier both outlive this route.
              final deleted = entry;
              final storage = ref.read(storageServiceProvider);
              final revision = ref.read(journalRevisionProvider.notifier);
              final messenger = ScaffoldMessenger.of(context);

              await storage.deleteJournalEntry(deleted.id);
              revision.bump();
              if (context.mounted) {
                Navigator.pop(context,
                    true); // Close screen, return true to signify deletion
              }

              messenger
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(
                    content: const Text('Entry deleted'),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: 'UNDO',
                      onPressed: () async {
                        // Re-save restores the entry verbatim (upsert by id).
                        await storage.saveJournalEntry(deleted);
                        revision.bump();
                      },
                    ),
                  ),
                );
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.rose500)),
          ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EntryEditor(
        initialDate: entry.date,
        initialType: entry.type,
        initialEntry: entry, // Pass the entry for editing
        onCancel: () => Navigator.pop(ctx),
        onSave: (updatedEntry) async {
          await ref.read(storageServiceProvider).saveJournalEntry(updatedEntry);
          // Refresh any journal-backed screens still alive.
          ref.read(journalRevisionProvider.notifier).bump();
          if (!ctx.mounted) return;
          Navigator.pop(ctx); // Close editor, stay on the updated viewer.
          setState(() {
            _entry = updatedEntry;
            _changed = true;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStory = entry.type == EntryType.story;
    final color = isStory ? AppColors.indigo500 : AppColors.emerald500;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isStory
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
                // App Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip: 'Back',
                        // Report whether anything changed so the calendar's day
                        // sheet can close its stale snapshot.
                        onPressed: () => Navigator.pop(context, _changed),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white54),
                            tooltip: 'Edit entry',
                            onPressed: () => _openEditor(context, ref),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.rose500),
                            tooltip: 'Delete entry',
                            onPressed: () => _confirmDelete(context, ref),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    child: ResponsiveCenter(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Image Carousel
                        if (entry.images.isNotEmpty)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final carouselHeight =
                                  (constraints.maxWidth * 9 / 16).clamp(200.0, 400.0);
                              return SizedBox(
                                height: carouselHeight,
                                width: double.infinity,
                                child: entry.images.length == 1
                                    ? Stack(
                                        children: [
                                          ImageThumbnailWidget(
                                            imageRef: entry.images.first,
                                            fit: BoxFit.cover,
                                            showTapToZoom: true,
                                          ),
                                          Positioned(
                                            bottom: 12,
                                            right: 12,
                                            child: GlassContainer(
                                              borderRadius: 16,
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 6),
                                              child: Text(
                                                moodIcons[entry.mood] ?? '',
                                                style: const TextStyle(fontSize: 28),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : PageView.builder(
                                        itemCount: entry.images.length,
                                        itemBuilder: (context, index) {
                                          return Stack(
                                            children: [
                                              ImageThumbnailWidget(
                                                imageRef: entry.images[index],
                                                fit: BoxFit.cover,
                                                showTapToZoom: true,
                                              ),
                                              if (index == 0)
                                                Positioned(
                                                  bottom: 12,
                                                  right: 12,
                                                  child: GlassContainer(
                                                    borderRadius: 16,
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 12, vertical: 6),
                                                    child: Text(
                                                      moodIcons[entry.mood] ?? '',
                                                      style:
                                                          const TextStyle(fontSize: 28),
                                                    ),
                                                  ),
                                                ),
                                              // Page indicator
                                              Positioned(
                                                bottom: 12,
                                                left: 0,
                                                right: 0,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: List.generate(
                                                    entry.images.length,
                                                    (i) => Container(
                                                      margin: const EdgeInsets.symmetric(
                                                          horizontal: 3),
                                                      width: 8,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: i == index
                                                            ? Colors.white
                                                            : Colors.white
                                                                .withValues(
                                                                    alpha: 0.4),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                              );
                            },
                          ),

                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Metadata Row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (entry.images.isEmpty)
                                    Text(
                                      moodIcons[entry.mood] ?? '',
                                      style: const TextStyle(fontSize: 32),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isStory
                                          ? (entry.feeling ?? 'STORY')
                                              .toUpperCase()
                                          : (entry.timeBucket != null
                                                  ? timeBucketLabel(
                                                      entry.timeBucket!)
                                                  : 'EVENT')
                                              .toUpperCase(),
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Date and Location
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      size: 14, color: AppColors.slate400),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${entry.date.day}/${entry.date.month}/${entry.date.year}",
                                    style: const TextStyle(
                                      color: AppColors.slate400,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (entry.location != null) ...[
                                    const SizedBox(width: 16),
                                    const Icon(Icons.location_on,
                                        size: 14, color: AppColors.emerald500),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        entry.location!.name,
                                        style: const TextStyle(
                                          color: AppColors.slate400,
                                          fontSize: 14,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Headline
                              Text(
                                entry.headline,
                                style: isStory
                                    ? GoogleFonts.libreBaskerville(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        height: 1.2,
                                      )
                                    : GoogleFonts.outfit(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1.2,
                                      ),
                              ),
                              const SizedBox(height: 24),

                              // Content Divider
                              Divider(
                                  color: Colors.white.withValues(alpha: 0.1)),
                              const SizedBox(height: 24),

                              // Body Content
                              Text(
                                entry.content,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 18,
                                  height: 1.8,
                                ),
                              ),

                              const SizedBox(height: 60), // Bottom padding
                            ],
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
