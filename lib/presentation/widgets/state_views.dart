import 'package:flutter/material.dart';
import '../theme/daylight_theme.dart';
import 'tactile_widgets.dart';

/// Animated centered loading card with a visual tactile progress bar.
class ShimmerLoadingView extends StatefulWidget {
  final bool isBoardLayout;
  final int itemCount;
  final String? label;
  final String? subtitle;
  final IconData icon;

  const ShimmerLoadingView({
    super.key,
    this.isBoardLayout = false,
    this.itemCount = 6,
    this.label,
    this.subtitle,
    this.icon = Icons.directions_car_rounded,
  });

  @override
  State<ShimmerLoadingView> createState() => _ShimmerLoadingViewState();
}

class _ShimmerLoadingViewState extends State<ShimmerLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.label ??
        (widget.isBoardLayout ? 'Loading Puzzle...' : 'Loading...');
    final subtitle =
        widget.subtitle ?? 'Please wait a moment while we get things ready.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
          decoration: BoxDecoration(
            color: DaylightColors.surfaceWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: DaylightColors.surfaceLip, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: DaylightColors.inkPrimary.withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              // Gentle vertical bobbing for the badge icon
              final bobOffset = -3.0 * (1.0 - (2.0 * t - 1.0).abs());

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: Offset(0, bobOffset),
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: DaylightColors.frontierFill,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DaylightColors.frontierAmber,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: DaylightColors.frontierAmberLip,
                            offset: Offset(0, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        size: 32,
                        color: DaylightColors.frontierAmberLip,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: DaylightTypography.rounded(
                      color: DaylightColors.inkPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: DaylightTypography.rounded(
                      color: DaylightColors.inkSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ).copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  _TactileIndeterminateProgressBar(progress: t),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TactileIndeterminateProgressBar extends StatelessWidget {
  final double progress;

  const _TactileIndeterminateProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    const double barFraction = 0.42;
    // Sweep smoothly from -barFraction to 1.0 across the track
    const double travel = 1.0 + barFraction;
    final double startFraction = -barFraction + travel * Curves.easeInOut.transform(progress);

    return Container(
      width: double.infinity,
      height: 16,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: DaylightColors.lockedSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DaylightColors.surfaceLip, width: 1.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          final rawLeft = startFraction * trackWidth;
          final rawRight = (startFraction + barFraction) * trackWidth;
          final clampedLeft = rawLeft.clamp(0.0, trackWidth);
          final clampedRight = rawRight.clamp(0.0, trackWidth);
          final pillWidth = (clampedRight - clampedLeft).clamp(0.0, trackWidth);

          return Stack(
            children: [
              if (pillWidth > 0)
                Positioned(
                  left: clampedLeft,
                  top: 0,
                  bottom: 0,
                  width: pillWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          DaylightColors.frontierAmber,
                          DaylightColors.starGold,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: DaylightColors.frontierAmber.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Friendly Empty State View when no records exist yet.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateView({
    super.key,
    this.icon = Icons.inbox_rounded,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: DaylightColors.surfaceWhite,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: DaylightColors.surfaceLip, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: DaylightColors.inkPrimary.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DaylightColors.frontierFill,
                  shape: BoxShape.circle,
                  border: Border.all(color: DaylightColors.frontierAmber),
                ),
                child: Icon(
                  icon,
                  size: 44,
                  color: DaylightColors.frontierAmberLip,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: DaylightTypography.rounded(
                  color: DaylightColors.inkPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: DaylightTypography.rounded(
                  color: DaylightColors.inkSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ).copyWith(height: 1.4),
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 22),
                TactileKeycap(
                  onTap: onAction,
                  surfaceColor: DaylightColors.frontierFill,
                  lipColor: DaylightColors.frontierAmberLip,
                  borderColor: DaylightColors.frontierAmber,
                  borderRadius: 14,
                  lipHeight: 3,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 11,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        color: DaylightColors.frontierAmberLip,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        actionLabel!,
                        style: DaylightTypography.rounded(
                          color: DaylightColors.frontierAmberLip,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Network / Server Error State View with functional Retry button.
class ErrorStateView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  const ErrorStateView({
    super.key,
    this.title = 'Connection Error',
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: DaylightColors.surfaceWhite,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: DaylightColors.brandRed.withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: DaylightColors.inkPrimary.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DaylightColors.brandRed.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 44,
                  color: DaylightColors.brandRed,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: DaylightTypography.rounded(
                  color: DaylightColors.inkPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: DaylightTypography.rounded(
                  color: DaylightColors.inkSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ).copyWith(height: 1.4),
              ),
              const SizedBox(height: 22),
              TactileKeycap(
                onTap: onRetry,
                surfaceColor: DaylightColors.brandRed,
                lipColor: DaylightColors.brandRedLip,
                borderRadius: 14,
                lipHeight: 3.5,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      retryLabel,
                      style: DaylightTypography.rounded(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
