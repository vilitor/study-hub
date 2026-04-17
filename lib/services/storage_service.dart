import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_hub/config/app_constants.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/models/study_event.dart';

/// Local Storage Service (Singleton)
/// - flutter_secure_storage: For sensitive data (encrypted)
/// - shared_preferences: For non-sensitive app settings
class StorageService {
  StorageService._internal();
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _keyStudyLogs = 'persisted_study_logs';
  static const String _keyStudyEvents = 'persisted_study_events';
  static const String _keyNotionSchema = 'notion_cached_schema';

  // ── Persistence: Logs & Events ──

  /// Persists the list of [StudyLog] objects as a JSON string.
  Future<void> saveStudyLogs(List<StudyLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(logs.map((e) => e.toMap()).toList());
    await prefs.setString(_keyStudyLogs, encodedData);
  }

  /// Retrieves the list of persisted [StudyLog] objects.
  Future<List<StudyLog>> getStudyLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_keyStudyLogs);
    if (encodedData == null) return [];
    
    try {
      final List<dynamic> decodedData = jsonDecode(encodedData);
      return decodedData.map((e) => StudyLog.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Persists the list of [StudyEvent] objects as a JSON string.
  Future<void> saveStudyEvents(List<StudyEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(events.map((e) => e.toMap()).toList());
    await prefs.setString(_keyStudyEvents, encodedData);
  }

  /// Retrieves the list of persisted [StudyEvent] objects.
  Future<List<StudyEvent>> getStudyEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_keyStudyEvents);
    if (encodedData == null) return [];
    
    try {
      final List<dynamic> decodedData = jsonDecode(encodedData);
      return decodedData.map((e) => StudyEvent.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  // ── Secure Storage: Tokens & Credentials ──

  /// Encrypts and saves the Notion API token.
  Future<void> saveNotionToken(String token) async {
    await _secureStorage.write(
      key: AppConstants.storageKeyNotionToken,
      value: token,
    );
  }

  /// Retrieves the encrypted Notion API token.
  Future<String?> getNotionToken() async {
    return await _secureStorage.read(
      key: AppConstants.storageKeyNotionToken,
    );
  }

  /// Encrypts and saves the Notion Database ID.
  Future<void> saveNotionDatabaseId(String databaseId) async {
    await _secureStorage.write(
      key: AppConstants.storageKeyNotionDatabaseId,
      value: databaseId,
    );
  }

  /// Retrieves the encrypted Notion Database ID.
  Future<String?> getNotionDatabaseId() async {
    return await _secureStorage.read(
      key: AppConstants.storageKeyNotionDatabaseId,
    );
  }

  /// Encrypts and saves the user's Google Email.
  Future<void> saveGoogleEmail(String email) async {
    await _secureStorage.write(
      key: AppConstants.storageKeyGoogleEmail,
      value: email,
    );
  }

  /// Retrieves the encrypted Google Email.
  Future<String?> getGoogleEmail() async {
    return await _secureStorage.read(
      key: AppConstants.storageKeyGoogleEmail,
    );
  }

  /// Encrypts and saves the Google User Name.
  Future<void> saveGoogleName(String name) async {
    await _secureStorage.write(
      key: AppConstants.storageKeyGoogleName,
      value: name,
    );
  }

  /// Retrieves the encrypted Google User Name.
  Future<String?> getGoogleName() async {
    return await _secureStorage.read(
      key: AppConstants.storageKeyGoogleName,
    );
  }

  /// Encrypts and saves the Google Photo URL.
  Future<void> saveGooglePhotoUrl(String url) async {
    await _secureStorage.write(
      key: AppConstants.storageKeyGooglePhoto,
      value: url,
    );
  }

  /// Retrieves the encrypted Google Photo URL.
  Future<String?> getGooglePhotoUrl() async {
    return await _secureStorage.read(
      key: AppConstants.storageKeyGooglePhoto,
    );
  }

  /// Clears all entries in Secure Storage (used for full sign-out).
  Future<void> clearSecureStorage() async {
    await _secureStorage.deleteAll();
  }

  // ── Cache & Preferences ──

  /// Caches the Notion database schema JSON string.
  Future<void> saveNotionSchema(String schemaJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNotionSchema, schemaJson);
  }

  /// Retrieves the cached Notion database schema.
  Future<String?> getNotionSchema() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNotionSchema);
  }

  /// Updates the application theme mode preference.
  Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefKeyThemeMode, mode);
  }

  /// Retrieves the application theme mode preference.
  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefKeyThemeMode) ?? 'system';
  }

  /// Updates the default reminder offset (minutes).
  Future<void> saveDefaultReminder(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.prefKeyDefaultReminder, minutes);
  }

  /// Retrieves the default reminder offset (minutes).
  Future<int> getDefaultReminder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.prefKeyDefaultReminder) ?? 15;
  }

  /// Checks if this is the first time the application is being launched.
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.prefKeyIsFirstLaunch) ?? true;
  }

  /// Disables the "first launch" flag.
  Future<void> setFirstLaunchDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefKeyIsFirstLaunch, false);
  }
}
