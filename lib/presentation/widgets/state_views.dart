import 'package:flutter/material.dart';
import '../theme/daylight_theme.dart';
import 'tactile_widgets.dart';

/// Animated Shimmer placeholder widget for Loading states (Board mode or List mode).
class ShimmerLoadingView extends StatefulWidget {
  final bool isBoardLayout;
  final int itemCount;
  final String? label;

  const ShimmerLoadingView({
    super.key,
    this.isBoardLayout = false,
    this.itemCount = 6,
    this.label,
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
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final gradient = LinearGradient(
          begin: Alignment(-1.0 + 2.0 * t, -0.3),
          end: Alignment(0.0 + 2.0 * t, 0.3),
          colors: const [
            DaylightColors.surfaceWhite,
            DaylightColors.lockedSurface,
            DaylightColors.surfaceWhite,
          ],
        );

        if (widget.isBoardLayout) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _ShimmerBox(height: 52, radius: 16, gradient: gradient),
                const SizedBox(height: 24),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: _ShimmerBox(
                          height: double.infinity,
                          radius: 20,
                          gradient: gradient,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _ShimmerBox(height: 68, radius: 20, gradient: gradient),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: widget.itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _ShimmerBox(
              height: 68,
              radius: 16,
              gradient: gradient,
            );
          },
        );
      },
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double height;
  final double radius;
  final Gradient gradient;

  const _ShimmerBox({
    required this.height,
    required this.radius,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: DaylightColors.surfaceLip),
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
