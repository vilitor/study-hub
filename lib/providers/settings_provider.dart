import 'package:flutter/material.dart';
import 'package:study_hub/models/app_settings.dart';
import 'package:study_hub/services/storage_service.dart';
import 'package:study_hub/repositories/auth_repository.dart';
import 'package:study_hub/services/local_study_schema_service.dart';

/// Provider that manages global application settings and integration states.
/// It interacts with the [AuthRepository] for Google OAuth and [StorageService] for local persistence.
class SettingsProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final AuthRepository _authRepository = AuthRepository();

  AppSettings _settings = const AppSettings();
  bool _isLoading = true;

  // ── Getters ──

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isGoogleConnected => _settings.isGoogleConnected;
  bool get isNotionAuthenticated => _settings.isNotionAuthenticated;
  bool get isNotionConnected => _settings.isNotionConnected;
  bool get hasSelectedNotionDatabase =>
      _settings.notionDatabaseId != null &&
      _settings.notionDatabaseId!.isNotEmpty;
  String get themeMode => _settings.themeMode;

  // ── Initialization ──

  /// Finalizes the initial load of all stored preferences and integration flags.
  Future<void> loadSettings() async {
    _setLoading(true);

    try {
      final googleEmail = await _storage.getGoogleEmail();
      final googleName = await _storage.getGoogleName();
      final googlePhoto = await _storage.getGooglePhotoUrl();
      final notionToken = await _storage.getNotionToken();
      final notionAuthFlag = await _storage.getNotionAuthenticatedFlag();
      final notionDbId = await _storage.getNotionDatabaseId();
      var themeMode = await _storage.getThemeMode();
      if (themeMode != 'light' && themeMode != 'dark') {
        themeMode = 'light';
        await _storage.saveThemeMode(themeMode);
      }
      final defaultReminder = await _storage.getDefaultReminder();
      final timeField = await _storage.getNotionTimeField();
      final localTimeField =
          await _storage.getLocalTimeField() ??
          LocalStudySchemaService.defaultStudyTimeField;
      final storedRegisterFieldSource = await _storage.getRegisterFieldSource();

      final isNotionAuthenticated =
          (notionToken != null && notionToken.isNotEmpty) || notionAuthFlag;
      final hasNotionDatabase = notionDbId != null && notionDbId.isNotEmpty;
      final registerFieldSource =
          storedRegisterFieldSource ??
          (isNotionAuthenticated && hasNotionDatabase
              ? RegisterFieldSource.notion
              : RegisterFieldSource.local);
      if (storedRegisterFieldSource == null) {
        await _storage.saveRegisterFieldSource(registerFieldSource);
      }
      _settings = AppSettings(
        isGoogleConnected: googleEmail != null && googleEmail.isNotEmpty,
        isNotionAuthenticated: isNotionAuthenticated,
        isNotionConnected: isNotionAuthenticated && hasNotionDatabase,
        notionDatabaseId: notionDbId,
        googleEmail: googleEmail,
        userName: googleName,
        userPhotoUrl: googlePhoto,
        themeMode: themeMode,
        defaultReminderMinutes: defaultReminder,
        notionTimeField: timeField,
        localTimeField: localTimeField,
        customCategories: await _storage.getCustomCategories(),
        deletedDefaultCategories: await _storage.getDeletedDefaultCategories(),
        linkCategoriesToNotion: await _storage.getLinkCategoriesToNotion(),
        notionCategoryField: await _storage.getNotionCategoryField(),
        registerFieldSource: registerFieldSource,
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
    final previousDatabaseId = _settings.notionDatabaseId;
    final previousSource = await _storage.getRegisterFieldSource();
    await _storage.saveNotionToken(token);
    await _storage.saveNotionDatabaseId(databaseId);
    if (previousSource == null) {
      await _storage.saveRegisterFieldSource(RegisterFieldSource.notion);
    }
    if (previousDatabaseId != databaseId) {
      await _storage.clearNotionSchema();
      await _storage.clearNotionCategoryField();
    }

    _settings = _settings.copyWith(
      isNotionConnected: true,
      isNotionAuthenticated: true,
      notionDatabaseId: databaseId,
      clearNotionCategoryField: previousDatabaseId != databaseId,
      registerFieldSource: previousSource ?? RegisterFieldSource.notion,
    );
    notifyListeners();
  }

  Future<String> getEditableNotionToken() async {
    return await _storage.getNotionToken() ?? '';
  }

  Future<String> getEditableNotionDatabaseId() async {
    return await _storage.getNotionDatabaseId() ?? '';
  }

  /// Removes Notion credentials from local storage.
  Future<void> disconnectNotion() async {
    await _storage.saveNotionToken('');
    await _storage.saveNotionDatabaseId('');
    await _storage.clearNotionSchema();
    await _storage.clearNotionCategoryField();
    await _storage.saveLinkCategoriesToNotion(false);

    _settings = _settings.copyWith(
      isNotionConnected: false,
      isNotionAuthenticated: false,
      linkCategoriesToNotion: false,
      clearNotionDatabaseId: true,
      clearNotionCategoryField: true,
    );
    notifyListeners();
  }

  // ── Google Authentication ──

  /// Triggers the Google OAuth sign-in flow and updates state upon success.
  Future<void> connectGoogle() async {
    _setLoading(true);

    try {
      final account = await _authRepository.login();
      if (account.isSuccess && account.googleAccount != null) {
        final googleAccount = account.googleAccount!;
        await setGoogleConnected(
          googleAccount.email,
          googleAccount.displayName ?? '',
          googleAccount.photoUrl ?? '',
        );
      } else if (account.diagnostic != null) {
        throw Exception(account.diagnostic!.message);
      }
    } catch (e) {
      debugPrint('Connection error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Manually synchronizes the local Google connection state.
  Future<void> setGoogleConnected(
    String email,
    String name,
    String photoUrl,
  ) async {
    await _storage.saveGoogleEmail(email);
    await _storage.saveGoogleName(name);
    await _storage.saveGooglePhotoUrl(photoUrl);

    _settings = _settings.copyWith(
      isGoogleConnected: true,
      googleEmail: email,
      userName: name,
      userPhotoUrl: photoUrl,
    );
    notifyListeners();
  }

  /// Signs out from Google and clears local authentication session.
  Future<void> disconnectGoogle() async {
    _setLoading(true);

    try {
      await _authRepository.logout();
      await _storage.saveGoogleEmail('');
      await _storage.saveGoogleName('');
      await _storage.saveGooglePhotoUrl('');

      _settings = _settings.copyWith(
        isGoogleConnected: false,
        googleEmail: null,
        userName: null,
        userPhotoUrl: null,
      );
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ── Preferences Management ──

  Future<void> setDefaultReminder(int minutes) async {
    await _storage.saveDefaultReminder(minutes);
    _settings = _settings.copyWith(defaultReminderMinutes: minutes);
    notifyListeners();
  }

  /// Updates the theme mode (light, dark).
  Future<void> setThemeMode(String mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    notifyListeners();
    await _storage.saveThemeMode(mode);
  }

  /// Saves the mapping for the study time field.
  Future<void> setNotionTimeField(String fieldName) async {
    await _storage.saveNotionTimeField(fieldName);
    _settings = _settings.copyWith(notionTimeField: fieldName);
    notifyListeners();
  }

  Future<void> setLocalTimeField(String fieldName) async {
    await _storage.saveLocalTimeField(fieldName);
    _settings = _settings.copyWith(localTimeField: fieldName);
    notifyListeners();
  }

  Future<void> setRegisterFieldSource(RegisterFieldSource source) async {
    await _storage.saveRegisterFieldSource(source);
    _settings = _settings.copyWith(registerFieldSource: source);
    notifyListeners();
  }

  // ── Category Management ──

  Future<void> setCustomCategories(List<String> categories) async {
    await _storage.saveCustomCategories(categories);
    _settings = _settings.copyWith(customCategories: categories);
    notifyListeners();
  }

  Future<void> addCustomCategory(String category) async {
    final newList = List<String>.from(_settings.customCategories);
    if (!newList.contains(category)) {
      newList.add(category);
      await setCustomCategories(newList);
    }
  }

  Future<void> removeCustomCategory(String category) async {
    final newList = List<String>.from(_settings.customCategories);
    newList.remove(category);
    await setCustomCategories(newList);
  }

  Future<void> removeLocalCategory(String category) async {
    if (_settings.linkCategoriesToNotion) {
      return;
    }

    if (_settings.customCategories.contains(category)) {
      await removeCustomCategory(category);
      return;
    }

    if (!_settings.deletedDefaultCategories.contains(category)) {
      final deletedDefaults = List<String>.from(
        _settings.deletedDefaultCategories,
      )..add(category);
      await _storage.saveDeletedDefaultCategories(deletedDefaults);
      _settings = _settings.copyWith(deletedDefaultCategories: deletedDefaults);
      notifyListeners();
    }
  }

  Future<void> setLinkCategoriesToNotion(bool value) async {
    await _storage.saveLinkCategoriesToNotion(value);
    _settings = _settings.copyWith(linkCategoriesToNotion: value);
    notifyListeners();
  }

  Future<void> setNotionCategoryField(String fieldName) async {
    await _storage.saveNotionCategoryField(fieldName);
    _settings = _settings.copyWith(notionCategoryField: fieldName);
    notifyListeners();
  }

  // ── Helpers ──

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
