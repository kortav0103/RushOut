import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/daylight_theme.dart';
import 'tactile_widgets.dart';

class WinDialog extends StatefulWidget {
  final int levelId;
  final String difficultyLabel;
  final int userMoves;
  final int optimalMoves;
  final int earnedStars;
  final bool hasNextLevel;
  final bool isTutorialComplete;
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
    this.isTutorialComplete = false,
    required this.onReplay,
    required this.onNextLevel,
    required this.onBackToLevels,
  });

  @override
  State<WinDialog> createState() => _WinDialogState();
}

class _WinDialogState extends State<WinDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.levelId * 31 + widget.earnedStars);
    const palette = [
      Colors.amberAccent,
      Color(0xFFE53935),
      Colors.cyanAccent,
      Colors.greenAccent,
      Colors.pinkAccent,
    ];
    final count = widget.earnedStars == 3 ? 36 : 20;
    _particles = List.generate(count, (i) {
      return _ConfettiParticle(
        xFraction: rng.nextDouble(),
        speedY: 0.45 + rng.nextDouble() * 0.7,
        driftX: (rng.nextDouble() - 0.5) * 0.25,
        size: 5.0 + rng.nextDouble() * 5.0,
        rotation: rng.nextDouble() * math.pi * 2,
        color: palette[i % palette.length],
      );
    });
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String get _headline {
    if (widget.isTutorialComplete) return 'TUTORIAL COMPLETE!';
    if (widget.earnedStars == 3) return 'PERFECT ESCAPE!';
    if (widget.earnedStars == 2) return 'GREAT DRIVING!';
    return 'LEVEL CLEARED!';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DaylightColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: DaylightColors.surfaceLip, width: 2),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AnimatedBuilder(
                  animation: _confettiController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _ConfettiPainter(
                        particles: _particles,
                        progress: _confettiController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Level #${widget.levelId}',
                  style: DaylightTypography.rounded(
                    color: DaylightColors.inkSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    tabular: true,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _headline,
                  textAlign: TextAlign.center,
                  style: DaylightTypography.rounded(
                    color: DaylightColors.inkPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                if (widget.isTutorialComplete) ...[
                  const SizedBox(height: 6),
                  Text(
                    'You\'re ready to solve puzzles on your own!',
                    textAlign: TextAlign.center,
                    style: DaylightTypography.rounded(
                      color: DaylightColors.inkSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                // Animated Stars Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final isEarned = index < widget.earnedStars;
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
                              Icons.star_rounded,
                              size: index == 1 ? 54 : 44,
                              color: isEarned
                                  ? DaylightColors.starGold
                                  : DaylightColors.emptyStar,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: DaylightColors.canvasBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: DaylightColors.surfaceLip),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatColumn(
                        label: 'Your Moves',
                        value: '${widget.userMoves}',
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: DaylightColors.surfaceLip,
                      ),
                      _StatColumn(
                        label: 'Optimal',
                        value: '${widget.optimalMoves}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    TactileKeycap(
                      onTap: widget.onBackToLevels,
                      surfaceColor: DaylightColors.canvasBg,
                      lipColor: DaylightColors.surfaceLip,
                      borderColor: DaylightColors.surfaceLip,
                      borderRadius: 12,
                      lipHeight: 3,
                      padding: const EdgeInsets.all(10),
                      child: const Icon(
                        Icons.grid_view_rounded,
                        color: DaylightColors.inkPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TactileKeycap(
                        onTap: widget.onReplay,
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
                              Icons.replay_rounded,
                              color: DaylightColors.inkPrimary,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Replay',
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
                    if (widget.hasNextLevel) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: TactileKeycap(
                          onTap: widget.onNextLevel,
                          surfaceColor: DaylightColors.brandRed,
                          lipColor: DaylightColors.brandRedLip,
                          borderRadius: 12,
                          lipHeight: 3,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.skip_next_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Next',
                                style: DaylightTypography.rounded(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
    );
  }
}

class _ConfettiParticle {
  final double xFraction;
  final double speedY;
  final double driftX;
  final double size;
  final double rotation;
  final Color color;

  const _ConfettiParticle({
    required this.xFraction,
    required this.speedY,
    required this.driftX,
    required this.size,
    required this.rotation,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  const _ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final dx = (p.xFraction + p.driftX * progress) * size.width;
      final dy = -12 + progress * p.speedY * size.height * 1.15;
      final paint = Paint()..color = p.color.withValues(alpha: opacity * 0.85);

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rotation + progress * 6.0);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
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
          style: DaylightTypography.rounded(
            color: DaylightColors.inkSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: DaylightTypography.rounded(
            color: DaylightColors.inkPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            tabular: true,
          ),
        ),
      ],
    );
  }
}
