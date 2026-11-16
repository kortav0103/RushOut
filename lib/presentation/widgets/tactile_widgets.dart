import 'package:flutter/material.dart';
import '../theme/daylight_theme.dart';

/// Lightweight background painter that renders a subtle sunlit dot-grid texture.
class DaylightDotGridPainter extends CustomPainter {
  final Color dotColor;
  final double spacing;
  final double radius;

  const DaylightDotGridPainter({
    this.dotColor = DaylightColors.patternDot,
    this.spacing = 22.0,
    this.radius = 1.6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    for (double y = spacing * 0.5; y < size.height; y += spacing) {
      for (double x = spacing * 0.5; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DaylightDotGridPainter oldDelegate) {
    return oldDelegate.dotColor != dotColor ||
        oldDelegate.spacing != spacing ||
        oldDelegate.radius != radius;
  }
}

/// Reusable physical 3D keycap/boardgame button/tile that compresses downward
/// by 2px on pointer down for responsive tactile feedback.
class TactileKeycap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color surfaceColor;
  final Color lipColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final double lipHeight;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? shadows;
  final bool enabled;

  const TactileKeycap({
    super.key,
    required this.child,
    this.onTap,
    this.surfaceColor = DaylightColors.surfaceWhite,
    this.lipColor = DaylightColors.surfaceLip,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius = 16.0,
    this.lipHeight = 3.5,
    this.padding,
    this.shadows,
    this.enabled = true,
  });

  @override
  State<TactileKeycap> createState() => _TactileKeycapState();
}

class _TactileKeycapState extends State<TactileKeycap> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || widget.onTap == null) return;
    if (_isPressed != value) {
      setState(() => _isPressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pressOffset = _isPressed ? 2.0 : 0.0;
    final currentLip = (widget.lipHeight - pressOffset).clamp(0.5, widget.lipHeight);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) {
        _setPressed(false);
        widget.onTap?.call();
      },
      onTapCancel: () => _setPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 65),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(top: pressOffset),
        padding: EdgeInsets.only(bottom: currentLip),
        decoration: BoxDecoration(
          color: widget.lipColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: _isPressed ? null : widget.shadows,
        ),
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.surfaceColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.borderColor != null
                ? Border.all(
                    color: widget.borderColor!,
                    width: widget.borderWidth,
                  )
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
