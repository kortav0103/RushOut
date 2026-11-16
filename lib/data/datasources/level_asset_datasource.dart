import 'dart:isolate';
import 'package:flutter/services.dart' show rootBundle;
import '../../core/constants/app_constants.dart';
import '../../core/utils/level_parser.dart';
import '../../domain/entities/level.dart';

class LevelAssetDataSource {
  List<Level>? _cachedLevels;

  Future<List<Level>> loadBaseCampaignLevels() async {
    if (_cachedLevels != null) {
      return _cachedLevels!;
    }
    final rawText = await rootBundle.loadString(AppConstants.levelsFilePath);
    _cachedLevels = await Isolate.run(
      () => LevelParser.parseCampaignLevels(rawText),
    );
    return _cachedLevels!;
  }
}
