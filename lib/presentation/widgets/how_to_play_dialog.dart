import 'package:flutter/material.dart';
import '../theme/daylight_theme.dart';
import 'tactile_widgets.dart';

class HowToPlayDialog extends StatelessWidget {
  final VoidCallback? onReplayTutorial;

  const HowToPlayDialog({
    super.key,
    this.onReplayTutorial,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onReplayTutorial,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => HowToPlayDialog(onReplayTutorial: onReplayTutorial),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DaylightColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: DaylightColors.surfaceLip, width: 2),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: DaylightColors.frontierFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DaylightColors.frontierAmber),
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    color: DaylightColors.frontierAmberLip,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'How to Play RushOut',
                    style: DaylightTypography.rounded(
                      color: DaylightColors.inkPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _RuleItem(
              icon: Icons.directions_car_filled_rounded,
              color: Color(0xFFE91E63),
              title: 'Escape the Parking Lot',
              description:
                  'Slide obstructing cars and trucks so the pink target car (↔) can exit through the yellow/black hazard gate on the right side of Row 3.',
            ),
            const SizedBox(height: 14),
            const _RuleItem(
              icon: Icons.open_with_rounded,
              color: Color(0xFF1E88E5),
              title: 'Fixed Movement Axes',
              description:
                  'Vehicles marked with ↔ only slide horizontally (left/right). Vehicles marked with ↕ only slide vertically (up/down).',
            ),
            const SizedBox(height: 14),
            const _RuleItem(
              icon: Icons.star_rounded,
              color: DaylightColors.frontierAmberLip,
              title: 'Earn 3 Stars',
              description:
                  '• 3 Stars: Moves ≤ Optimal Moves\n'
                  '• 2 Stars: Moves ≤ Optimal + 3\n'
                  '• 1 Star: Moves > Optimal + 3',
            ),
            const SizedBox(height: 14),
            const _RuleItem(
              icon: Icons.lightbulb_outline_rounded,
              color: DaylightColors.completedMintLip,
              title: 'Smart Hint & Undo',
              description:
                  'Stuck in traffic? Use Undo to step back, or tap Hint to highlight the shortest next move from your current board!',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (onReplayTutorial != null) ...[
                  Expanded(
                    child: TactileKeycap(
                      onTap: () {
                        Navigator.of(context).pop();
                        onReplayTutorial!();
                      },
                      surfaceColor: DaylightColors.canvasBg,
                      lipColor: DaylightColors.surfaceLip,
                      borderColor: DaylightColors.surfaceLip,
                      borderRadius: 12,
                      lipHeight: 3,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.school_rounded,
                            color: DaylightColors.inkPrimary,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tutorial',
                            style: DaylightTypography.rounded(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: DaylightColors.inkPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: TactileKeycap(
                    onTap: () => Navigator.of(context).pop(),
                    surfaceColor: DaylightColors.brandRed,
                    lipColor: DaylightColors.brandRedLip,
                    borderRadius: 12,
                    lipHeight: 3,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Center(
                      child: Text(
                        'Got It!',
                        style: DaylightTypography.rounded(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
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
    );
  }
}

class _RuleItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _RuleItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: DaylightTypography.rounded(
                  color: DaylightColors.inkPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: DaylightTypography.rounded(
                  color: DaylightColors.inkSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ).copyWith(height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
