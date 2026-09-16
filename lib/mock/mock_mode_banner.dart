import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/constants.dart';
import '../providers/mock_mode_provider.dart';

/// A persistent marker shown on every screen while demo mode is on.
///
/// Not decoration. The demo backend is deliberately indistinguishable from the
/// real one in every other respect — same screens, same interactions, same
/// write behaviour — which is exactly what makes an unlabelled demo dangerous:
/// a screenshot, a bug report or a support call built on fabricated entries is
/// worse than useless. This is the one place the app admits the data is not
/// real, so it is always visible, cannot be dismissed, and disappears the
/// instant the toggle goes off.
///
/// [IgnorePointer] keeps it out of the way of the screen underneath — it marks,
/// it never intercepts.
///
/// Sits bottom-centre, in the gap between the glass nav pill and the screens'
/// floating actions. The top of the frame is not available: every tab puts a
/// large title on the left and action icons on the right at exactly the height
/// a centred badge would occupy, so a top-centre badge overlapped the "Journal"
/// heading on narrow phones. The bottom strip is dead space on all five tabs.
class MockModeBanner extends ConsumerWidget {
  const MockModeBanner({super.key});

  /// Clearance above the nav pill: its own height (~76) plus its 16pt bottom
  /// margin, measured from inside the safe area, plus a little breathing room.
  static const double _navBarClearance = 100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(mockModeProvider)) return const SizedBox.shrink();

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: _navBarClearance),
            child: Semantics(
              liveRegion: true,
              label: 'Demo data is active. Entries shown are samples, '
                  'not your own journal.',
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.amber500.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.amber500.withValues(alpha: 0.55),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.science_outlined,
                        size: 14, color: AppColors.amber500),
                    const SizedBox(width: 6),
                    Text(
                      'DEMO DATA',
                      style: GoogleFonts.outfit(
                        color: AppColors.amber500,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
