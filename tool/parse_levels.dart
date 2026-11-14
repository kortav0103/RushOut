import 'dart:convert';
import 'dart:io';
import 'package:rush_out/core/utils/level_parser.dart';
import 'package:rush_out/domain/entities/level.dart';

/// Standalone CLI script to parse `assets/levels/rush1000.txt`,
/// filter out lines containing `'x'` (fixed walls), and output 30 standard
/// campaign levels (10 Easy [5-10], 10 Medium [11-18], 10 Hard [19-25]).
void main(List<String> args) {
  final inputPath = args.isNotEmpty ? args[0] : 'assets/levels/rush1000.txt';
  final file = File(inputPath);

  if (!file.existsSync()) {
    stderr.writeln('Error: File not found at $inputPath');
    exit(1);
  }

  final rawContent = file.readAsStringSync();
  final levels = LevelParser.parseCampaignLevels(rawContent);

  final easy = levels.where((l) => l.difficulty == Difficulty.easy).toList();
  final medium =
      levels.where((l) => l.difficulty == Difficulty.medium).toList();
  final hard = levels.where((l) => l.difficulty == Difficulty.hard).toList();

  stdout.writeln('=== RUSHOUT LEVEL PARSER SUMMARY ===');
  stdout.writeln('Source file : $inputPath');
  stdout.writeln('Total levels: ${levels.length}');
  stdout.writeln('  - Easy   (5-10 moves) : ${easy.length} levels');
  stdout.writeln('  - Medium (11-18 moves): ${medium.length} levels');
  stdout.writeln('  - Hard   (19-25 moves): ${hard.length} levels');
  stdout.writeln('------------------------------------');

  for (final level in levels) {
    final vehicles = LevelParser.parseBoardString(level.boardString);
    stdout.writeln(
      'Level #${level.id.toString().padLeft(2, '0')} '
      '[${level.difficulty.label.padRight(6)}] | '
      'Optimal Moves: ${level.optimalMoves.toString().padLeft(2, '0')} | '
      'Vehicles: ${vehicles.length.toString().padLeft(2, '0')} | '
      'Board: ${level.boardString}',
    );
  }

  if (args.length >= 2) {
    final outputJsonFile = File(args[1]);
    final jsonList = levels
        .map(
          (l) => {
            'id': l.id,
            'difficulty': l.difficulty.name,
            'optimalMoves': l.optimalMoves,
            'boardString': l.boardString,
            'clusterSize': l.clusterSize,
          },
        )
        .toList();
    outputJsonFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(jsonList),
    );
    stdout.writeln('Exported 30 parsed levels to ${outputJsonFile.path}');
  }
}
