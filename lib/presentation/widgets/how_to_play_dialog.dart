import 'package:flutter/material.dart';

class HowToPlayDialog extends StatelessWidget {
  const HowToPlayDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const HowToPlayDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1F2227),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white12),
      ),
      title: const Row(
        children: [
          Icon(Icons.help_outline_rounded, color: Colors.amberAccent, size: 28),
          SizedBox(width: 10),
          Text(
            'How to Play RushOut',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RuleItem(
              icon: Icons.directions_car_filled_rounded,
              color: Colors.redAccent,
              title: 'Escape the Parking Lot',
              description:
                  'Slide obstructing cars and trucks so the red sports car (↔) can exit through the hazard gate on the right side of Row 3.',
            ),
            SizedBox(height: 14),
            _RuleItem(
              icon: Icons.open_with_rounded,
              color: Colors.cyanAccent,
              title: 'Fixed Movement Axes',
              description:
                  'Vehicles marked with ↔ only slide horizontally (left/right). Vehicles marked with ↕ only slide vertically (up/down).',
            ),
            SizedBox(height: 14),
            _RuleItem(
              icon: Icons.star_rounded,
              color: Colors.amberAccent,
              title: 'Earn 3 Stars',
              description:
                  '• 3 Stars: Moves ≤ Optimal Moves\n'
                  '• 2 Stars: Moves ≤ Optimal + 3\n'
                  '• 1 Star: Moves > Optimal + 3',
            ),
            SizedBox(height: 14),
            _RuleItem(
              icon: Icons.lightbulb_outline_rounded,
              color: Colors.greenAccent,
              title: 'Smart BFS Hint & Undo',
              description:
                  'Stuck in traffic? Tap Hint to compute the shortest path from your current board state and highlight the exact next move!',
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got It!'),
        ),
      ],
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
            color: color.withValues(alpha: 0.15),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
