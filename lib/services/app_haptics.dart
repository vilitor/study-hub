import 'package:flutter/services.dart';

class AppHaptics {
  const AppHaptics._();

  static final Map<String, DateTime> _lastImpactAt = {};

  static Future<void> success() => _safeImpact(
    'success',
    HapticFeedback.lightImpact,
    minInterval: const Duration(milliseconds: 180),
  );

  static Future<void> selection() => _safeImpact(
    'selection',
    HapticFeedback.selectionClick,
    minInterval: const Duration(milliseconds: 70),
  );

  static Future<void> warning() => _safeImpact(
    'warning',
    HapticFeedback.mediumImpact,
    minInterval: const Duration(milliseconds: 220),
  );

  static Future<void> _safeImpact(
    String key,
    Future<void> Function() feedback, {
    required Duration minInterval,
  }) async {
    try {
      final now = DateTime.now();
      final last = _lastImpactAt[key];
      if (last != null && now.difference(last) < minInterval) return;
      _lastImpactAt[key] = now;
      await feedback();
    } catch (_) {
      // Some platforms/devices do not expose haptics. Interaction should remain stable.
    }
  }
}
