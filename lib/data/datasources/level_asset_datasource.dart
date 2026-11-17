import 'dart:isolate';
import 'package:flutter/services.dart' show rootBundle;
import '../../core/constants/app_constants.dart';
import '../../core/utils/level_parser.dart';
import '../../domain/entities/level.dart';

class LevelAssetDataSource {
  List<Level>? _cachedLevels;
  Future<List<Level>>? _inFlightLoad;

  Future<List<Level>> loadBaseCampaignLevels() {
    final cached = _cachedLevels;
    if (cached != null) {
      return Future.value(cached);
    }

    final inFlight = _inFlightLoad;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _loadAndCache();
    _inFlightLoad = future;
    return future.whenComplete(() {
      if (identical(_inFlightLoad, future)) {
        _inFlightLoad = null;
      }
    });
  }

  Future<List<Level>> _loadAndCache() async {
    final rawText = await rootBundle.loadString(AppConstants.levelsFilePath);
    final levels = await Isolate.run(
      () => LevelParser.parsePreOrderedCampaignLevels(rawText),
    );
    _cachedLevels = levels;
    return levels;
  }
}
