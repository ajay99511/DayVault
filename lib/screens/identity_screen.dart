
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';
import '../models/types.dart';
import '../config/constants.dart';
import '../widgets/glass_widgets.dart';

class IdentityScreen extends StatefulWidget {
  const IdentityScreen({super.key});

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  List<RankingCategory> categories = [];
  String activeId = 'movies';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await StorageService().getRankings();
    setState(() => categories = d);
  }

  @override
  Widget build(BuildContext context) {
    final activeCategory = categories.firstWhere(
      (c) => c.id == activeId,
      orElse: () => categories.first,
    );

    return Scaffold(
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
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: categories.length,
              itemBuilder: (ctx, i) {
                final cat = categories[i];
                final isActive = cat.id == activeId;
                return GestureDetector(
                  onTap: () => setState(() => activeId = cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat.title.toUpperCase(),
                      style: TextStyle(
                        color: isActive ? Colors.black : AppColors.slate400,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // List
          Expanded(
            child: activeCategory.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.emoji_events_outlined,
                          size: 48,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "No favorites ranked yet.",
                          style: TextStyle(color: Colors.white24),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text(
                            "START RANKING",
                            style: TextStyle(
                              color: AppColors.indigo500,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: activeCategory.items.length,
                    itemBuilder: (ctx, i) {
                      final item = activeCategory.items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassContainer(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: _getRankGradient(item.rank),
                                ),
                                child: Text(
                                  "${item.rank}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
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
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "${item.dateAdded.year}",
                                style: const TextStyle(
                                  color: AppColors.slate400,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton(
          backgroundColor: AppColors.indigo500,
          onPressed: () {}, // Add item modal logic
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

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
    return LinearGradient(colors: [AppColors.slate800, AppColors.slate900]);
  }
}
