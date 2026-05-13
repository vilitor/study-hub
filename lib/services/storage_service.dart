import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_hub/config/app_constants.dart';
import 'package:study_hub/models/app_settings.dart';
import 'package:study_hub/models/certificate.dart';
import 'package:study_hub/models/cloud_sync.dart';
import 'package:study_hub/models/local_study_field.dart';
import 'package:study_hub/models/study_goal.dart';
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
  static const String _keyStudyGoals = 'persisted_study_goals';
  static const String _keyCertificates = 'persisted_certificates';
  static const String _keySyncQueue = 'cloud_sync_queue';
  static const String _keyCloudSyncState = 'cloud_sync_state';
  static const String _keyNotionSchema = 'notion_cached_schema';
  static const String _keyNotionTimeField = 'notion_mapped_time_field';
  static const String _keyLocalTimeField = 'local_mapped_time_field';
  static const String _keyLocalStudyFields = 'local_study_fields';
  static const String _keyCustomCategories = 'app_custom_categories';
  static const String _keyDeletedDefaultCategories =
      'app_deleted_default_categories';
  static const String _keyNotionAuthenticated = 'app_notion_authenticated';
  static const String _keyNotionDatabaseIdPrefs = 'app_notion_database_id';
  static const String _keyLinkToNotion = 'app_link_categories_notion';
  static const String _keyNotionCategoryField = 'app_notion_category_field';
  static const String _keyGoalTutorialSeen = 'goal_tutorial_seen';
  static const String _keyRegisterFieldSource = 'register_field_source';
  static const String _keyTimerStats = 'timer_stats';

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
      return decodedData
          .map((e) => StudyLog.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Persists the list of [StudyEvent] objects as a JSON string.
  Future<void> saveStudyEvents(List<StudyEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      events.map((e) => e.toMap()).toList(),
    );
    await prefs.setString(_keyStudyEvents, encodedData);
  }

  /// Retrieves the list of persisted [StudyEvent] objects.
  Future<List<StudyEvent>> getStudyEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_keyStudyEvents);
    if (encodedData == null) return [];

    try {
      final List<dynamic> decodedData = jsonDecode(encodedData);
      return decodedData
          .map((e) => StudyEvent.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveStudyGoals(List<StudyGoal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyStudyGoals,
      jsonEncode(goals.map((goal) => goal.toMap()).toList()),
    );
  }

  Future<List<StudyGoal>> getStudyGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedData = prefs.getString(_keyStudyGoals);
    if (encodedData == null || encodedData.isEmpty) return [];

    try {
      final decodedData = jsonDecode(encodedData) as List<dynamic>;
      return decodedData
          .map((goal) => StudyGoal.fromMap(Map<String, dynamic>.from(goal)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ── Secure Storage: Tokens & Credentials ──

  Future<void> saveCertificates(List<Certificate> certificates) async {
    final prefs = await SharedPreferences.getInstance();
    final encodedData = jsonEncode(
      certificates.map((certificate) => certificate.toMap()).toList(),
    );
    await prefs.setString(_keyCertificates, encodedData);
  }

  Future<List<Certificate>> getCertificates() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedData = prefs.getString(_keyCertificates);
    if (encodedData == null) return [];

    try {
      final decodedData = jsonDecode(encodedData) as List<dynamic>;
      return decodedData
          .map(
            (certificate) => Certificate.fromMap(
              Map<String, dynamic>.from(certificate as Map),
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Encrypts and saves the Notion API token.
  Future<void> saveNotionToken(String token) async {
    await _secureStorage.write(
      key: AppConstants.storageKeyNotionToken,
      value: token,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotionAuthenticated, token.isNotEmpty);
  }

  /// Retrieves the encrypted Notion API token.
  Future<String?> getNotionToken() async {
    return await _secureStorage.read(key: AppConstants.storageKeyNotionToken);
  }

  /// Encrypts and saves the Notion Database ID.
  Future<void> saveNotionDatabaseId(String databaseId) async {
    await _secureStorage.write(
      key: AppConstants.storageKeyNotionDatabaseId,
      value: databaseId,
    );
    final prefs = await SharedPreferences.getInstance();
    if (databaseId.isEmpty) {
      await prefs.remove(_keyNotionDatabaseIdPrefs);
    } else {
      await prefs.setString(_keyNotionDatabaseIdPrefs, databaseId);
    }
  }

  /// Retrieves the encrypted Notion Database ID.
  Future<String?> getNotionDatabaseId() async {
    final secureValue = await _secureStorage.read(
      key: AppConstants.storageKeyNotionDatabaseId,
    );
    if (secureValue != null && secureValue.isNotEmpty) {
      return secureValue;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNotionDatabaseIdPrefs);
  }

  Future<bool> getNotionAuthenticatedFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotionAuthenticated) ?? false;
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
    return await _secureStorage.read(key: AppConstants.storageKeyGoogleEmail);
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
    return await _secureStorage.read(key: AppConstants.storageKeyGoogleName);
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
    return await _secureStorage.read(key: AppConstants.storageKeyGooglePhoto);
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

  Future<void> clearNotionSchema() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyNotionSchema);
  }

  /// Retrieves the cached Notion database schema.
  Future<String?> getNotionSchema() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNotionSchema);
  }

  /// Saves the mapping for the study time field.
  Future<void> saveNotionTimeField(String fieldName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNotionTimeField, fieldName);
  }

  /// Retrieves the mapping for the study time field.
  Future<String?> getNotionTimeField() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNotionTimeField);
  }

  Future<void> saveLocalTimeField(String fieldName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocalTimeField, fieldName);
  }

  Future<String?> getLocalTimeField() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocalTimeField);
  }

  Future<void> saveRegisterFieldSource(RegisterFieldSource source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRegisterFieldSource, source.name);
  }

  Future<RegisterFieldSource?> getRegisterFieldSource() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyRegisterFieldSource);
    if (value == null || value.isEmpty) return null;
    return RegisterFieldSource.values.firstWhere(
      (source) => source.name == value,
      orElse: () => RegisterFieldSource.local,
    );
  }

  Future<void> saveLocalStudyFields(List<LocalStudyField> fields) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyLocalStudyFields,
      jsonEncode(fields.map((field) => field.toMap()).toList()),
    );
  }

  Future<List<LocalStudyField>> getLocalStudyFields() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedData = prefs.getString(_keyLocalStudyFields);
    if (encodedData == null || encodedData.isEmpty) return [];

    try {
      final decodedData = jsonDecode(encodedData) as List<dynamic>;
      return decodedData
          .map(
            (field) => LocalStudyField.fromMap(
              Map<String, dynamic>.from(field as Map),
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Updates the application theme mode preference.
  Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefKeyThemeMode, mode);
  }

  /// Retrieves the application theme mode preference.
  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefKeyThemeMode) ?? 'light';
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

  Future<bool> hasSeenGoalTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyGoalTutorialSeen) ?? false;
  }

  Future<void> setGoalTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGoalTutorialSeen, true);
  }

  // ── Category Persistence ──

  Future<void> saveCustomCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyCustomCategories, categories);
  }

  Future<List<String>> getCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyCustomCategories) ?? [];
  }

  Future<void> saveDeletedDefaultCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyDeletedDefaultCategories, categories);
  }

  Future<List<String>> getDeletedDefaultCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyDeletedDefaultCategories) ?? [];
  }

  Future<void> saveLinkCategoriesToNotion(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLinkToNotion, value);
  }

  Future<bool> getLinkCategoriesToNotion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLinkToNotion) ?? false;
  }

  Future<void> saveNotionCategoryField(String fieldName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNotionCategoryField, fieldName);
  }

  Future<String?> getNotionCategoryField() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNotionCategoryField);
  }

  Future<void> clearNotionCategoryField() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyNotionCategoryField);
  }

  // ── Cloud Sync Queue ──

  Future<List<SyncQueueItem>> getSyncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedData = prefs.getString(_keySyncQueue);
    if (encodedData == null || encodedData.isEmpty) return [];

    try {
      final decodedData = jsonDecode(encodedData) as List<dynamic>;
      return decodedData
          .map((item) => SyncQueueItem.fromMap(Map<String, dynamic>.from(item)))
          .where(
            (item) =>
                item.idempotencyKey.isNotEmpty &&
                item.collection.isNotEmpty &&
                item.documentId.isNotEmpty,
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveSyncQueue(List<SyncQueueItem> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keySyncQueue,
      jsonEncode(queue.map((item) => item.toMap()).toList()),
    );
  }

  Future<void> enqueueSync(SyncQueueItem item) async {
    final queue = await getSyncQueue();
    queue.removeWhere((queued) => queued.idempotencyKey == item.idempotencyKey);
    queue.add(item);
    await saveSyncQueue(queue);
  }

  Future<void> removeQueuedSync(String idempotencyKey) async {
    final queue = await getSyncQueue();
    queue.removeWhere((item) => item.idempotencyKey == idempotencyKey);
    await saveSyncQueue(queue);
  }

  Future<void> replaceQueuedSync(SyncQueueItem item) async {
    final queue = await getSyncQueue();
    final index = queue.indexWhere(
      (queued) => queued.idempotencyKey == item.idempotencyKey,
    );
    if (index == -1) {
      queue.add(item);
    } else {
      queue[index] = item;
    }
    await saveSyncQueue(queue);
  }

  Future<CloudSyncState> getCloudSyncState() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_keyCloudSyncState);
    if (encoded == null || encoded.isEmpty) return const CloudSyncState();

    try {
      return CloudSyncState.fromMap(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
    } catch (_) {
      return const CloudSyncState();
    }
  }

  Future<void> saveCloudSyncState(CloudSyncState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCloudSyncState, jsonEncode(state.toMap()));
  }

  Future<Map<String, dynamic>> getCloudSettingsSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final source = await getRegisterFieldSource();
    return {
      'themeMode': await getThemeMode(),
      'defaultReminderMinutes': await getDefaultReminder(),
      'notionDatabaseId': await getNotionDatabaseId(),
      'notionTimeField': await getNotionTimeField(),
      'localTimeField': await getLocalTimeField(),
      'customCategories': await getCustomCategories(),
      'deletedDefaultCategories': await getDeletedDefaultCategories(),
      'linkCategoriesToNotion': await getLinkCategoriesToNotion(),
      'notionCategoryField': await getNotionCategoryField(),
      'registerFieldSource': source?.name ?? RegisterFieldSource.local.name,
      'goalTutorialSeen': prefs.getBool(_keyGoalTutorialSeen) ?? false,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> applyCloudSettingsSnapshot(Map<String, dynamic> map) async {
    final themeMode = map['themeMode']?.toString();
    if (themeMode == 'light' || themeMode == 'dark') {
      await saveThemeMode(themeMode!);
    }

    final reminder = (map['defaultReminderMinutes'] as num?)?.toInt();
    if (reminder != null) await saveDefaultReminder(reminder);

    final notionDatabaseId = map['notionDatabaseId']?.toString();
    if (notionDatabaseId != null) {
      await saveNotionDatabaseId(notionDatabaseId);
    }

    final notionTimeField = map['notionTimeField']?.toString();
    if (notionTimeField != null) await saveNotionTimeField(notionTimeField);

    final localTimeField = map['localTimeField']?.toString();
    if (localTimeField != null) await saveLocalTimeField(localTimeField);

    await saveCustomCategories(
      List<String>.from(map['customCategories'] as List? ?? const []),
    );
    await saveDeletedDefaultCategories(
      List<String>.from(map['deletedDefaultCategories'] as List? ?? const []),
    );
    await saveLinkCategoriesToNotion(
      map['linkCategoriesToNotion'] as bool? ?? false,
    );

    final notionCategoryField = map['notionCategoryField']?.toString();
    if (notionCategoryField == null || notionCategoryField.isEmpty) {
      await clearNotionCategoryField();
    } else {
      await saveNotionCategoryField(notionCategoryField);
    }

    final sourceName = map['registerFieldSource']?.toString();
    final source = RegisterFieldSource.values.firstWhere(
      (source) => source.name == sourceName,
      orElse: () => RegisterFieldSource.local,
    );
    await saveRegisterFieldSource(source);

    if (map['goalTutorialSeen'] is bool) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        _keyGoalTutorialSeen,
        map['goalTutorialSeen'] as bool,
      );
    }
  }

  Future<Map<String, dynamic>> getLocalConfigSnapshot() async {
    return {
      'studySchema': (await getLocalStudyFields())
          .map((field) => field.toMap())
          .toList(),
      'categories': {
        'custom': await getCustomCategories(),
        'deletedDefault': await getDeletedDefaultCategories(),
        'linkToNotion': await getLinkCategoriesToNotion(),
        'notionCategoryField': await getNotionCategoryField(),
      },
      'timerStats': await getTimerStatsSnapshot(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> applyLocalConfigSnapshot(Map<String, dynamic> map) async {
    final schema = map['studySchema'];
    if (schema is List) {
      await saveLocalStudyFields(
        schema
            .map(
              (field) => LocalStudyField.fromMap(
                Map<String, dynamic>.from(field as Map),
              ),
            )
            .toList(),
      );
    }

    final categories = map['categories'];
    if (categories is Map) {
      final categoryMap = Map<String, dynamic>.from(categories);
      await saveCustomCategories(
        List<String>.from(categoryMap['custom'] as List? ?? const []),
      );
      await saveDeletedDefaultCategories(
        List<String>.from(categoryMap['deletedDefault'] as List? ?? const []),
      );
      await saveLinkCategoriesToNotion(
        categoryMap['linkToNotion'] as bool? ?? false,
      );
      final notionCategoryField = categoryMap['notionCategoryField']
          ?.toString();
      if (notionCategoryField == null || notionCategoryField.isEmpty) {
        await clearNotionCategoryField();
      } else {
        await saveNotionCategoryField(notionCategoryField);
      }
    }

    final timerStats = map['timerStats'];
    if (timerStats is Map) {
      await saveTimerStatsSnapshot(Map<String, dynamic>.from(timerStats));
    }
  }

  Future<Map<String, dynamic>> getTimerStatsSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_keyTimerStats);
    if (encoded == null || encoded.isEmpty) return const {};
    try {
      return Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    } catch (_) {
      return const {};
    }
  }

  Future<void> saveTimerStatsSnapshot(Map<String, dynamic> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTimerStats, jsonEncode(map));
  }
}
