import 'package:flutter/material.dart';

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
            Color(0xFF1F2329),
            Color(0xFF2E343D),
            Color(0xFF1F2329),
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
        border: Border.all(color: Colors.white10),
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
            color: const Color(0xFF1E2127),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 46, color: Colors.amberAccent),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    side: const BorderSide(color: Colors.amberAccent),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
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
            color: const Color(0xFF211C1E),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.redAccent.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 44,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  retryLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
