import 'package:flutter/material.dart';

class WinDialog extends StatelessWidget {
  final int levelId;
  final String difficultyLabel;
  final int userMoves;
  final int optimalMoves;
  final int earnedStars;
  final bool hasNextLevel;
  final VoidCallback onReplay;
  final VoidCallback onNextLevel;
  final VoidCallback onBackToLevels;

  const WinDialog({
    super.key,
    required this.levelId,
    required this.difficultyLabel,
    required this.userMoves,
    required this.optimalMoves,
    required this.earnedStars,
    required this.hasNextLevel,
    required this.onReplay,
    required this.onNextLevel,
    required this.onBackToLevels,
  });

  String get _headline {
    if (earnedStars == 3) return 'PERFECT ESCAPE!';
    if (earnedStars == 2) return 'GREAT DRIVING!';
    return 'LEVEL CLEARED!';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E2126),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Colors.white12, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Level $levelId • $difficultyLabel',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _headline,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 18),
            // Animated Stars Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                final isEarned = index < earnedStars;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 350 + index * 180),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          isEarned
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: index == 1 ? 54 : 44,
                          color: isEarned ? Colors.amberAccent : Colors.white24,
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatColumn(label: 'Your Moves', value: '$userMoves'),
                  Container(width: 1, height: 30, color: Colors.white12),
                  _StatColumn(label: 'Optimal', value: '$optimalMoves'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: onBackToLevels,
                  tooltip: 'Level Select',
                  icon: const Icon(Icons.grid_view_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReplay,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Replay'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (hasNextLevel) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onNextLevel,
                      icon: const Icon(Icons.skip_next_rounded),
                      label: const Text('Next'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
