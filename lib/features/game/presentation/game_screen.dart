import 'package:flutter/material.dart';

/// Tab 3: Xiangqi (Cờ Tướng) game lobby shell with 3 required AI difficulty levels.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  String _difficulty = 'Medium';
  String _playerSide = 'Red (First)';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xiangqi (Cờ Tướng)')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select AI Difficulty',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: ['Easy', 'Medium', 'Hard'].map((level) {
                return ChoiceChip(
                  label: Text(level),
                  selected: _difficulty == level,
                  onSelected: (_) => setState(() => _difficulty = level),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Choose Side',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: ['Red (First)', 'Black (Second)'].map((side) {
                return ChoiceChip(
                  label: Text(side),
                  selected: _playerSide == side,
                  onSelected: (_) => setState(() => _playerSide = side),
                );
              }).toList(),
            ),
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Xiangqi board ($_difficulty · $_playerSide) activates in Milestone 5.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start New Match'),
            ),
          ],
        ),
      ),
    );
  }
}
