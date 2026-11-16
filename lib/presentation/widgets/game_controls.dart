import 'package:flutter/material.dart';
import '../theme/daylight_theme.dart';
import 'tactile_widgets.dart';

class GameControls extends StatelessWidget {
  final bool canUndo;
  final bool canReset;
  final bool hintEnabled;
  final bool hasActiveHint;
  final bool isComputingHint;
  final int? remainingHints;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final VoidCallback onHint;

  const GameControls({
    super.key,
    required this.canUndo,
    required this.canReset,
    this.hintEnabled = true,
    this.hasActiveHint = false,
    this.isComputingHint = false,
    this.remainingHints,
    required this.onUndo,
    required this.onReset,
    required this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    final canHint = hintEnabled &&
        !isComputingHint &&
        (remainingHints == null || remainingHints! > 0);
    final hintLabel = isComputingHint
        ? 'Solving...'
        : (remainingHints != null ? 'Hint ($remainingHints)' : 'Hint');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DaylightColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DaylightColors.surfaceLip, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: DaylightColors.inkPrimary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _ControlButton(
              icon: Icons.undo_rounded,
              label: 'Undo',
              enabled: canUndo,
              onTap: onUndo,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ControlButton(
              icon: Icons.refresh_rounded,
              label: 'Reset',
              enabled: canReset,
              onTap: onReset,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ControlButton(
              icon: Icons.lightbulb_rounded,
              label: hintLabel,
              enabled: canHint,
              isHighlighted: hasActiveHint,
              isLoading: isComputingHint,
              accentColor: DaylightColors.frontierAmberLip,
              onTap: onHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool isHighlighted;
  final bool isLoading;
  final Color? accentColor;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.enabled,
    this.isHighlighted = false,
    this.isLoading = false,
    this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = accentColor ?? DaylightColors.inkPrimary;
    final surface = isHighlighted
        ? DaylightColors.frontierFill
        : (enabled ? DaylightColors.canvasBg : DaylightColors.lockedSurface);
    final lip = isHighlighted
        ? DaylightColors.frontierAmberLip
        : (enabled ? DaylightColors.surfaceLip : DaylightColors.lockedLip);

    return Opacity(
      opacity: enabled ? 1.0 : 0.48,
      child: TactileKeycap(
        enabled: enabled,
        onTap: enabled ? onTap : null,
        surfaceColor: surface,
        lipColor: lip,
        borderColor:
            isHighlighted ? DaylightColors.frontierAmber : DaylightColors.surfaceLip,
        borderWidth: isHighlighted ? 1.8 : 1.0,
        borderRadius: 14,
        lipHeight: 3.0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 24,
                height: 24,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: activeColor,
                  ),
                ),
              )
            else
              Icon(icon, color: activeColor, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DaylightTypography.rounded(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: activeColor,
                tabular: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
