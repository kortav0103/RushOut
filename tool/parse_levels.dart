import 'dart:convert';
import 'dart:io';
import 'package:rush_out/core/utils/level_parser.dart';
import 'package:rush_out/domain/entities/level.dart';

/// Standalone CLI script to parse `assets/levels/rush1000.txt`,
/// filter out lines containing `'x'` (fixed walls), run
/// `LevelOrderingPipeline.orderLevels` once at build time, and write
/// 4,050 pre-ordered campaign levels to `assets/levels/campaign_ordered.txt`
/// using format: `<id> <difficulty> <optimal_moves> <36_char_board> <cluster_size>`.
void main(List<String> args) {
  final inputPath = args.isNotEmpty ? args[0] : 'assets/levels/rush1000.txt';
  final outputPath =
      args.length >= 2 ? args[1] : 'assets/levels/campaign_ordered.txt';
  final file = File(inputPath);

  if (!file.existsSync()) {
    stderr.writeln('Error: File not found at $inputPath');
    exit(1);
  }

  final rawContent = file.readAsStringSync();
  final levels = LevelParser.parseCampaignLevels(rawContent);

  final easyCount =
      levels.where((l) => l.difficulty == Difficulty.easy).length;
  final mediumCount =
      levels.where((l) => l.difficulty == Difficulty.medium).length;
  final hardCount =
      levels.where((l) => l.difficulty == Difficulty.hard).length;

  stdout.writeln('=== RUSHOUT LEVEL PARSER SUMMARY ===');
  stdout.writeln('Source file : $inputPath');
  stdout.writeln('Total levels: ${levels.length}');
  stdout.writeln('  - Easy   (5-10 moves) : $easyCount levels');
  stdout.writeln('  - Medium (11-18 moves): $mediumCount levels');
  stdout.writeln('  - Hard   (19-25 moves): $hardCount levels');
  stdout.writeln('------------------------------------');

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);

  if (outputPath.endsWith('.json')) {
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
    outputFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(jsonList),
    );
  } else {
    final buffer = StringBuffer();
    for (final level in levels) {
      buffer.writeln(
        '${level.id} ${level.difficulty.name} ${level.optimalMoves} '
        '${level.boardString} ${level.clusterSize}',
      );
    }
    outputFile.writeAsStringSync(buffer.toString());
  }

  stdout.writeln(
    'Exported ${levels.length} pre-ordered levels to ${outputFile.path}',
  );
}
