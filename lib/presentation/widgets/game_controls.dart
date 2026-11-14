import 'package:flutter/material.dart';

class GameControls extends StatelessWidget {
  final bool canUndo;
  final bool canReset;
  final bool hasActiveHint;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final VoidCallback onHint;

  const GameControls({
    super.key,
    required this.canUndo,
    required this.canReset,
    this.hasActiveHint = false,
    required this.onUndo,
    required this.onReset,
    required this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2024),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: Icons.undo_rounded,
            label: 'Undo',
            enabled: canUndo,
            onTap: onUndo,
          ),
          _ControlButton(
            icon: Icons.refresh_rounded,
            label: 'Reset',
            enabled: canReset,
            onTap: onReset,
          ),
          _ControlButton(
            icon: Icons.lightbulb_rounded,
            label: 'Hint',
            enabled: true,
            isHighlighted: hasActiveHint,
            accentColor: Colors.amberAccent,
            onTap: onHint,
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
  final Color? accentColor;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.enabled,
    this.isHighlighted = false,
    this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = accentColor ?? Colors.white;
    return Opacity(
      opacity: enabled ? 1.0 : 0.38,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: isHighlighted
                ? Colors.amber.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isHighlighted ? Colors.amberAccent : Colors.white12,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: activeColor, size: 26),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
