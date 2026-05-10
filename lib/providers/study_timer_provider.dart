import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider that manages a single study timer session.
/// Persists start timestamp for crash recovery.
class StudyTimerProvider extends ChangeNotifier {
  // ── State ──
  Timer? _ticker;
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  Duration _pausedElapsed = Duration.zero; // Accumulated before last pause
  bool _isRunning = false;
  bool _isPaused = false;
  int _lastSessionMinutes = 0;

  // ── Persistence Keys ──
  static const String _keyStartTime = 'timer_start_time';
  static const String _keyPausedElapsed = 'timer_paused_elapsed_ms';
  static const String _keyIsRunning = 'timer_is_running';
  static const String _keyIsPaused = 'timer_is_paused';

  // ── Getters ──
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  bool get isActive => _isRunning || _isPaused;
  Duration get elapsed => _elapsed;
  int get lastSessionMinutes => _lastSessionMinutes;

  /// Returns rounded minutes (>=30s rounds up, <30s rounds down, min 1m).
  int get roundedMinutes {
    if (_elapsed.inSeconds == 0) return 0;

    final minutes = _elapsed.inMinutes;
    final remainingSeconds = _elapsed.inSeconds % 60;

    int result = remainingSeconds >= 30 ? minutes + 1 : minutes;

    // Ensure at least 1 minute if timer was actually used
    if (result == 0 && _elapsed.inSeconds > 0) result = 1;

    return result;
  }

  /// Returns elapsed minutes as an integer (for Notion field population).
  int get elapsedMinutes => _elapsed.inMinutes;

  /// Returns formatted time string "HH:MM:SS".
  String get formattedTime {
    final hours = _elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  // ── Lifecycle ──

  StudyTimerProvider() {
    _recover();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ── Actions ──

  /// Starts a new timer session. Guards against duplicates.
  void start() {
    if (_isRunning) return; // Prevent duplicate sessions

    _startTime = DateTime.now();
    _pausedElapsed = Duration.zero;
    _elapsed = Duration.zero;
    _isRunning = true;
    _isPaused = false;

    _startTicker();
    _persist();
    notifyListeners();
  }

  /// Pauses the running timer, preserving elapsed time.
  void pause() {
    if (!_isRunning || _isPaused) return;

    _ticker?.cancel();
    _pausedElapsed = _elapsed;
    _isPaused = true;

    _persist();
    notifyListeners();
  }

  /// Resumes a paused timer.
  void resume() {
    if (!_isPaused) return;

    _startTime = DateTime.now();
    _isPaused = false;

    _startTicker();
    _persist();
    notifyListeners();
  }

  /// Stops the timer and returns the total elapsed minutes.
  /// Clears all state and persistence.
  int stop() {
    _ticker?.cancel();

    final totalMinutes = roundedMinutes;

    _startTime = null;
    _elapsed = Duration.zero;
    _pausedElapsed = Duration.zero;
    _isRunning = false;
    _isPaused = false;
    _lastSessionMinutes = totalMinutes;

    _clearPersistence();
    notifyListeners();

    return totalMinutes;
  }

  /// Captures current elapsed minutes without stopping the timer.
  void recordSession() {
    _lastSessionMinutes = roundedMinutes;
    notifyListeners();
  }

  /// Discards the timer session without returning a value.
  void discard() {
    stop();
    _lastSessionMinutes = 0;
  }

  /// Clears the last session minutes after it has been consumed.
  void clearLastSession() {
    _lastSessionMinutes = 0;
    notifyListeners();
  }

  // ── Internal Ticker ──

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startTime != null) {
        _elapsed = _pausedElapsed + DateTime.now().difference(_startTime!);
        notifyListeners();
      }
    });
  }

  // ── Persistence (Crash Recovery) ──

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsRunning, _isRunning);
    await prefs.setBool(_keyIsPaused, _isPaused);
    await prefs.setInt(_keyPausedElapsed, _pausedElapsed.inMilliseconds);
    if (_startTime != null) {
      await prefs.setString(_keyStartTime, _startTime!.toIso8601String());
    }
  }

  Future<void> _clearPersistence() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsRunning);
    await prefs.remove(_keyIsPaused);
    await prefs.remove(_keyPausedElapsed);
    await prefs.remove(_keyStartTime);
  }

  /// Recovers an in-progress timer session after app restart.
  Future<void> _recover() async {
    final prefs = await SharedPreferences.getInstance();
    final wasRunning = prefs.getBool(_keyIsRunning) ?? false;
    if (!wasRunning) return;

    final wasPaused = prefs.getBool(_keyIsPaused) ?? false;
    final pausedMs = prefs.getInt(_keyPausedElapsed) ?? 0;
    final startTimeStr = prefs.getString(_keyStartTime);

    _pausedElapsed = Duration(milliseconds: pausedMs);
    _isRunning = true;
    _isPaused = wasPaused;

    if (startTimeStr != null) {
      _startTime = DateTime.parse(startTimeStr);
    }

    if (wasPaused) {
      // Was paused — just restore elapsed without ticking
      _elapsed = _pausedElapsed;
    } else if (_startTime != null) {
      // Was running — calculate how much time passed while app was closed
      _elapsed = _pausedElapsed + DateTime.now().difference(_startTime!);
      _startTicker();
    }

    notifyListeners();
  }
}
