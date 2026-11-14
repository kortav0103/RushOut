import 'package:flutter/services.dart';

class HapticService {
  const HapticService();

  Future<void> lightImpact() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {
      // Ignore on unsupported platforms or unit tests
    }
  }

  Future<void> mediumImpact() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }
}
