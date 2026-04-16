import 'package:flutter/material.dart';
import 'package:study_hub/models/app_settings.dart';
import 'package:study_hub/services/storage_service.dart';
import 'package:study_hub/repositories/auth_repository.dart';

/// Provider that manages global application settings and integration states.
/// It interacts with the [AuthRepository] for Google OAuth and [StorageService] for local persistence.
class SettingsProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final AuthRepository _authRepository = AuthRepository();

  AppSettings _settings = const AppSettings();
  bool _isLoading = false;

  // ── Getters ──

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isGoogleConnected => _settings.isGoogleConnected;
  bool get isNotionConnected => _settings.isNotionConnected;

  // ── Initialization ──

  /// Finalizes the initial load of all stored preferences and integration flags.
  Future<void> loadSettings() async {
    _setLoading(true);

    try {
      final googleEmail = await _storage.getGoogleEmail();
      final notionToken = await _storage.getNotionToken();
      final notionDbId = await _storage.getNotionDatabaseId();
      final themeMode = await _storage.getThemeMode();
      final defaultReminder = await _storage.getDefaultReminder();

      _settings = AppSettings(
        isGoogleConnected: googleEmail != null && googleEmail.isNotEmpty,
        isNotionConnected: notionToken != null && notionToken.isNotEmpty,
        notionDatabaseId: notionDbId,
        googleEmail: googleEmail,
        themeMode: themeMode,
        defaultReminderMinutes: defaultReminder,
      );
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ── Notion Configuration ──

  /// Persists Notion integration credentials and updates global state.
  Future<void> saveNotionCredentials(String token, String databaseId) async {
    await _storage.saveNotionToken(token);
    await _storage.saveNotionDatabaseId(databaseId);

    _settings = _settings.copyWith(
      isNotionConnected: true,
      notionDatabaseId: databaseId,
    );
    notifyListeners();
  }

  /// Removes Notion credentials from local storage.
  Future<void> disconnectNotion() async {
    await _storage.saveNotionToken('');
    await _storage.saveNotionDatabaseId('');

    _settings = _settings.copyWith(
      isNotionConnected: false,
      notionDatabaseId: null,
    );
    notifyListeners();
  }

  // ── Google Authentication ──

  /// Triggers the Google OAuth sign-in flow and updates state upon success.
  Future<void> connectGoogle() async {
    _setLoading(true);
    
    try {
      final account = await _authRepository.login();
      if (account != null) {
        await setGoogleConnected(account.email);
      }
    } catch (e) {
      debugPrint('Connection error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Manually synchronizes the local Google connection state.
  Future<void> setGoogleConnected(String email) async {
    await _storage.saveGoogleEmail(email);

    _settings = _settings.copyWith(
      isGoogleConnected: true,
      googleEmail: email,
    );
    notifyListeners();
  }

  /// Signs out from Google and clears local authentication session.
  Future<void> disconnectGoogle() async {
    _setLoading(true);
    
    try {
      await _authRepository.logout();
      await _storage.saveGoogleEmail('');

      _settings = _settings.copyWith(
        isGoogleConnected: false,
        googleEmail: null,
      );
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ── Preferences Management ──

  /// Updates the default time (minutes) for calendar event reminders.
  Future<void> setDefaultReminder(int minutes) async {
    await _storage.saveDefaultReminder(minutes);
    _settings = _settings.copyWith(defaultReminderMinutes: minutes);
    notifyListeners();
  }

  // ── Helpers ──

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
