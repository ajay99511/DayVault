import 'package:flutter/material.dart';
import '../widgets/glass_widgets.dart';
import '../config/constants.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "February",
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      "2026",
                      style: TextStyle(fontSize: 18, color: AppColors.slate400),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _navBtn(Icons.chevron_left),
                    const SizedBox(width: 8),
                    _navBtn(Icons.chevron_right),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
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
                          .map(
                            (d) => Text(
                              d,
                              style: const TextStyle(
                                color: AppColors.slate400,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    // Grid (Mock)
                    Expanded(
                      child: GridView.builder(
                        itemCount: 35,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                            ),
                        itemBuilder: (ctx, i) {
                          final day = i - 2; // Offset for mock
                          if (day < 1 || day > 28) return const SizedBox();
                          final isToday = day == 2;
                          return Center(
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: isToday
                                  ? const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.indigo500,
                                          AppColors.fuchsia500,
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    )
                                  : null,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "$day",
                                    style: TextStyle(
                                      color: isToday
                                          ? Colors.white
                                          : AppColors.slate400,
                                      fontWeight: isToday
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  if (day == 2 || day == 5 || day == 12)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 4,
                                          margin: const EdgeInsets.all(1),
                                          decoration: const BoxDecoration(
                                            color: AppColors.emerald500,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        if (day == 5)
                                          Container(
                                            width: 4,
                                            height: 4,
                                            margin: const EdgeInsets.all(1),
                                            decoration: const BoxDecoration(
                                              color: AppColors.indigo500,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}
