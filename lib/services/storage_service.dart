import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_hub/config/app_constants.dart';
import 'package:study_hub/models/app_settings.dart';
import 'package:study_hub/models/certificate.dart';
import 'package:study_hub/models/cloud_sync.dart';
import 'package:study_hub/models/local_study_field.dart';
import 'package:study_hub/models/onboarding_state.dart';
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

  static const String guestNamespace = 'guest';
  static const String _legacyUnscopedMigrationClaimed =
      'legacy_unscoped_account_migrated';
  static const String _namespaceMigrationPrefix = 'account_namespace_migrated_';
  static const String _namespacePrefix = 'account';
  String _activeNamespace = guestNamespace;

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
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyOnboardingVersion = 'onboarding_version';
  static const String _keyOnboardingCompletedAt = 'onboarding_completed_at';
  static const String _keyProfilePersonalizationCompleted =
      'profile_personalization_completed';
  static const String _keyProfilePersonalizationCompletedAt =
      'profile_personalization_completed_at';
  static const String _keyStarterSubjectsSeeded = 'starter_subjects_seeded';
  static const String _keyStarterSubjectsSeededAt =
      'starter_subjects_seeded_at';
  static const String _keyLegacyMigrationCompleted =
      'legacy_migration_completed';
  static const String _keyLegacyMigrationCompletedAt =
      'legacy_migration_completed_at';
  static const String _keyContextualGuideCompleted =
      'contextual_guide_completed';
  static const String _keySelectedStudyProfileId = 'selected_study_profile_id';
  static const String _keySelectedStudyProfileLabel =
      'selected_study_profile_label';
  static const String _keySelectedStudyFocusId = 'selected_study_focus_id';
  static const String _keySelectedStudyFocusLabel =
      'selected_study_focus_label';
  static const String _keyThemeModeUpdatedAt = 'theme_mode_updated_at';
  static const String _keyLumaPersonalizationEnabled =
      'luma_personalization_enabled';

  static const List<String> _accountPreferenceKeys = [
    _keyStudyLogs,
    _keyStudyEvents,
    _keyStudyGoals,
    _keyCertificates,
    _keySyncQueue,
    _keyCloudSyncState,
    _keyNotionSchema,
    _keyNotionTimeField,
    _keyLocalTimeField,
    _keyLocalStudyFields,
    _keyCustomCategories,
    _keyDeletedDefaultCategories,
    _keyNotionAuthenticated,
    _keyNotionDatabaseIdPrefs,
    _keyLinkToNotion,
    _keyNotionCategoryField,
    _keyGoalTutorialSeen,
    _keyRegisterFieldSource,
    _keyTimerStats,
    _keyOnboardingCompleted,
    _keyOnboardingVersion,
    _keyOnboardingCompletedAt,
    _keyProfilePersonalizationCompleted,
    _keyProfilePersonalizationCompletedAt,
    _keyStarterSubjectsSeeded,
    _keyStarterSubjectsSeededAt,
    _keyLegacyMigrationCompleted,
    _keyLegacyMigrationCompletedAt,
    _keyContextualGuideCompleted,
    _keySelectedStudyProfileId,
    _keySelectedStudyProfileLabel,
    _keySelectedStudyFocusId,
    _keySelectedStudyFocusLabel,
    _keyLumaPersonalizationEnabled,
    AppConstants.prefKeyDefaultReminder,
  ];

  static const List<String> _accountSecureKeys = [
    AppConstants.storageKeyNotionToken,
    AppConstants.storageKeyNotionDatabaseId,
    AppConstants.storageKeyGoogleEmail,
    AppConstants.storageKeyGoogleName,
    AppConstants.storageKeyGooglePhoto,
  ];

  String get activeNamespace => _activeNamespace;

  Future<void> setActiveAccountNamespace(
    String namespace, {
    bool migrateLegacyUnscoped = false,
  }) async {
    final normalized = _normalizeNamespace(namespace);
    if (_activeNamespace != normalized) {
      debugPrint(
        '[STORAGE] account namespace active ${_safeNamespace(normalized)}',
      );
      _activeNamespace = normalized;
    }
    if (migrateLegacyUnscoped) {
      await migrateLegacyUnscopedDataIfNeeded();
    }
  }

  Future<void> useGuestNamespace({bool migrateLegacyUnscoped = false}) {
    return setActiveAccountNamespace(
      guestNamespace,
      migrateLegacyUnscoped: migrateLegacyUnscoped,
    );
  }

  Future<void> useUidNamespace(
    String uid, {
    bool migrateLegacyUnscoped = false,
  }) {
    return setActiveAccountNamespace(
      'uid:$uid',
      migrateLegacyUnscoped: migrateLegacyUnscoped,
    );
  }

  Future<void> migrateLegacyUnscopedDataIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final markerKey = '$_namespaceMigrationPrefix$_activeNamespace';
    if ((prefs.getBool(markerKey) ?? false) ||
        (prefs.getBool(_legacyUnscopedMigrationClaimed) ?? false)) {
      return;
    }

    var migrated = 0;
    for (final key in _accountPreferenceKeys) {
      final scoped = _scopedPreferenceKey(key);
      if (prefs.containsKey(scoped) || !prefs.containsKey(key)) continue;
      final value = prefs.get(key);
      if (value is String) {
        await prefs.setString(scoped, value);
      } else if (value is bool) {
        await prefs.setBool(scoped, value);
      } else if (value is int) {
        await prefs.setInt(scoped, value);
      } else if (value is double) {
        await prefs.setDouble(scoped, value);
      } else if (value is List<String>) {
        await prefs.setStringList(scoped, value);
      }
      migrated++;
    }

    for (final key in _accountSecureKeys) {
      final scoped = _scopedSecureKey(key);
      final existing = await _readSecureValue(scoped);
      final legacy = await _readSecureValue(key);
      if ((existing == null || existing.isEmpty) &&
          legacy != null &&
          legacy.isNotEmpty) {
        await _writeSecureValue(scoped, legacy);
        migrated++;
      }
    }

    await prefs.setBool(markerKey, true);
    await prefs.setBool(_legacyUnscopedMigrationClaimed, true);
    debugPrint(
      '[STORAGE] legacy unscoped migration namespace=${_safeNamespace(_activeNamespace)} items=$migrated',
    );
  }

  String _normalizeNamespace(String namespace) {
    final trimmed = namespace.trim();
    if (trimmed.isEmpty) return guestNamespace;
    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9:_-]'), '_');
  }

  String _scopedPreferenceKey(String key) =>
      '$_namespacePrefix.$_activeNamespace.$key';

  String _scopedSecureKey(String key) =>
      '$_namespacePrefix.$_activeNamespace.$key';

  String _safeNamespace(String namespace) {
    if (namespace == guestNamespace) return guestNamespace;
    final parts = namespace.split(':');
    if (parts.length < 2) return 'account';
    final id = parts.sublist(1).join(':');
    final suffix = id.length <= 4 ? '****' : id.substring(id.length - 4);
    return '${parts.first}:***$suffix';
  }

  // ── Persistence: Logs & Events ──

  /// Persists the list of [StudyLog] objects as a JSON string.
  Future<void> saveStudyLogs(List<StudyLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(logs.map((e) => e.toMap()).toList());
    await prefs.setString(_scopedPreferenceKey(_keyStudyLogs), encodedData);
  }

  /// Retrieves the list of persisted [StudyLog] objects.
  Future<List<StudyLog>> getStudyLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(
      _scopedPreferenceKey(_keyStudyLogs),
    );
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
    await prefs.setString(_scopedPreferenceKey(_keyStudyEvents), encodedData);
  }

  /// Retrieves the list of persisted [StudyEvent] objects.
  Future<List<StudyEvent>> getStudyEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(
      _scopedPreferenceKey(_keyStudyEvents),
    );
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
      _scopedPreferenceKey(_keyStudyGoals),
      jsonEncode(goals.map((goal) => goal.toMap()).toList()),
    );
  }

  Future<List<StudyGoal>> getStudyGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedData = prefs.getString(_scopedPreferenceKey(_keyStudyGoals));
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
    await prefs.setString(_scopedPreferenceKey(_keyCertificates), encodedData);
  }

  Future<List<Certificate>> getCertificates() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedData = prefs.getString(_scopedPreferenceKey(_keyCertificates));
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
    await _writeSecureValue(
      _scopedSecureKey(AppConstants.storageKeyNotionToken),
      token,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _scopedPreferenceKey(_keyNotionAuthenticated),
      token.isNotEmpty,
    );
  }

  /// Retrieves the encrypted Notion API token.
  Future<String?> getNotionToken() async {
    return await _readSecureValue(
      _scopedSecureKey(AppConstants.storageKeyNotionToken),
    );
  }

  /// Encrypts and saves the Notion Database ID.
  Future<void> saveNotionDatabaseId(String databaseId) async {
    await _writeSecureValue(
      _scopedSecureKey(AppConstants.storageKeyNotionDatabaseId),
      databaseId,
    );
    final prefs = await SharedPreferences.getInstance();
    if (databaseId.isEmpty) {
      await prefs.remove(_scopedPreferenceKey(_keyNotionDatabaseIdPrefs));
    } else {
      await prefs.setString(
        _scopedPreferenceKey(_keyNotionDatabaseIdPrefs),
        databaseId,
      );
    }
  }

  /// Retrieves the encrypted Notion Database ID.
  Future<String?> getNotionDatabaseId() async {
    final secureValue = await _readSecureValue(
      _scopedSecureKey(AppConstants.storageKeyNotionDatabaseId),
    );
    if (secureValue != null && secureValue.isNotEmpty) {
      return secureValue;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedPreferenceKey(_keyNotionDatabaseIdPrefs));
  }

  Future<bool> getNotionAuthenticatedFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedPreferenceKey(_keyNotionAuthenticated)) ??
        false;
  }

  /// Encrypts and saves the user's Google Email.
  Future<void> saveGoogleEmail(String email) async {
    await _writeSecureValue(
      _scopedSecureKey(AppConstants.storageKeyGoogleEmail),
      email,
    );
  }

  /// Retrieves the encrypted Google Email.
  Future<String?> getGoogleEmail() async {
    return await _readSecureValue(
      _scopedSecureKey(AppConstants.storageKeyGoogleEmail),
    );
  }

  /// Encrypts and saves the Google User Name.
  Future<void> saveGoogleName(String name) async {
    await _writeSecureValue(
      _scopedSecureKey(AppConstants.storageKeyGoogleName),
      name,
    );
  }

  /// Retrieves the encrypted Google User Name.
  Future<String?> getGoogleName() async {
    return await _readSecureValue(
      _scopedSecureKey(AppConstants.storageKeyGoogleName),
    );
  }

  /// Encrypts and saves the Google Photo URL.
  Future<void> saveGooglePhotoUrl(String url) async {
    await _writeSecureValue(
      _scopedSecureKey(AppConstants.storageKeyGooglePhoto),
      url,
    );
  }

  /// Retrieves the encrypted Google Photo URL.
  Future<String?> getGooglePhotoUrl() async {
    return await _readSecureValue(
      _scopedSecureKey(AppConstants.storageKeyGooglePhoto),
    );
  }

  /// Clears all entries in Secure Storage (used for full sign-out).
  Future<void> clearSecureStorage() async {
    for (final key in _accountSecureKeys) {
      await _deleteSecureValue(_scopedSecureKey(key));
    }
  }

  Future<void> clearAppAccountData() async {
    await clearActiveAccountData();
  }

  Future<void> clearActiveAccountData() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _accountPreferenceKeys) {
      await prefs.remove(_scopedPreferenceKey(key));
    }
    await clearSecureStorage();
    debugPrint(
      '[STORAGE] cleared account namespace ${_safeNamespace(_activeNamespace)}',
    );
  }

  // ── Cache & Preferences ──

  /// Caches the Notion database schema JSON string.
  Future<void> saveNotionSchema(String schemaJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedPreferenceKey(_keyNotionSchema), schemaJson);
  }

  Future<void> clearNotionSchema() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedPreferenceKey(_keyNotionSchema));
  }

  /// Retrieves the cached Notion database schema.
  Future<String?> getNotionSchema() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedPreferenceKey(_keyNotionSchema));
  }

  /// Saves the mapping for the study time field.
  Future<void> saveNotionTimeField(String fieldName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedPreferenceKey(_keyNotionTimeField), fieldName);
  }

  /// Retrieves the mapping for the study time field.
  Future<String?> getNotionTimeField() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedPreferenceKey(_keyNotionTimeField));
  }

  Future<void> saveLocalTimeField(String fieldName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedPreferenceKey(_keyLocalTimeField), fieldName);
  }

  Future<String?> getLocalTimeField() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedPreferenceKey(_keyLocalTimeField));
  }

  Future<void> saveRegisterFieldSource(RegisterFieldSource source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedPreferenceKey(_keyRegisterFieldSource),
      source.name,
    );
  }

  Future<RegisterFieldSource?> getRegisterFieldSource() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(
      _scopedPreferenceKey(_keyRegisterFieldSource),
    );
    if (value == null || value.isEmpty) return null;
    return RegisterFieldSource.values.firstWhere(
      (source) => source.name == value,
      orElse: () => RegisterFieldSource.local,
    );
  }

  Future<void> saveLocalStudyFields(List<LocalStudyField> fields) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedPreferenceKey(_keyLocalStudyFields),
      jsonEncode(fields.map((field) => field.toMap()).toList()),
    );
  }

  Future<List<LocalStudyField>> getLocalStudyFields() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedData = prefs.getString(
      _scopedPreferenceKey(_keyLocalStudyFields),
    );
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

  Future<bool> hasPersistedLocalStudyFields() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedData = prefs.getString(
      _scopedPreferenceKey(_keyLocalStudyFields),
    );
    if (encodedData == null || encodedData.isEmpty) return false;
    try {
      final decodedData = jsonDecode(encodedData);
      return decodedData is List && decodedData.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Updates the application theme mode preference.
  Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefKeyThemeMode, mode);
    await prefs.setString(
      _keyThemeModeUpdatedAt,
      DateTime.now().toIso8601String(),
    );
  }

  /// Retrieves the application theme mode preference.
  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefKeyThemeMode) ?? 'light';
  }

  Future<DateTime?> getThemeModeUpdatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return _date(prefs.getString(_keyThemeModeUpdatedAt));
  }

  /// Updates the default reminder offset (minutes).
  Future<void> saveDefaultReminder(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _scopedPreferenceKey(AppConstants.prefKeyDefaultReminder),
      minutes,
    );
  }

  /// Retrieves the default reminder offset (minutes).
  Future<int> getDefaultReminder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(
          _scopedPreferenceKey(AppConstants.prefKeyDefaultReminder),
        ) ??
        15;
  }

  Future<void> saveLumaPersonalizationEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _scopedPreferenceKey(_keyLumaPersonalizationEnabled),
      value,
    );
  }

  Future<bool> getLumaPersonalizationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(
          _scopedPreferenceKey(_keyLumaPersonalizationEnabled),
        ) ??
        true;
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
    return prefs.getBool(_scopedPreferenceKey(_keyGoalTutorialSeen)) ?? false;
  }

  Future<void> setGoalTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedPreferenceKey(_keyGoalTutorialSeen), true);
  }

  Future<OnboardingState> getOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    return OnboardingState(
      onboardingCompleted:
          prefs.getBool(_scopedPreferenceKey(_keyOnboardingCompleted)) ?? false,
      onboardingVersion:
          prefs.getInt(_scopedPreferenceKey(_keyOnboardingVersion)) ?? 0,
      onboardingCompletedAt: _date(
        prefs.getString(_scopedPreferenceKey(_keyOnboardingCompletedAt)),
      ),
      profilePersonalizationCompleted:
          prefs.getBool(
            _scopedPreferenceKey(_keyProfilePersonalizationCompleted),
          ) ??
          false,
      profilePersonalizationCompletedAt: _date(
        prefs.getString(
          _scopedPreferenceKey(_keyProfilePersonalizationCompletedAt),
        ),
      ),
      starterSubjectsSeeded:
          prefs.getBool(_scopedPreferenceKey(_keyStarterSubjectsSeeded)) ??
          false,
      starterSubjectsSeededAt: _date(
        prefs.getString(_scopedPreferenceKey(_keyStarterSubjectsSeededAt)),
      ),
      legacyMigrationCompleted:
          prefs.getBool(_scopedPreferenceKey(_keyLegacyMigrationCompleted)) ??
          false,
      legacyMigrationCompletedAt: _date(
        prefs.getString(_scopedPreferenceKey(_keyLegacyMigrationCompletedAt)),
      ),
      contextualGuideCompleted:
          prefs.getBool(_scopedPreferenceKey(_keyContextualGuideCompleted)) ??
          false,
      selectedStudyProfileId: _nonEmpty(
        prefs.getString(_scopedPreferenceKey(_keySelectedStudyProfileId)),
      ),
      selectedStudyProfileLabel: _nonEmpty(
        prefs.getString(_scopedPreferenceKey(_keySelectedStudyProfileLabel)),
      ),
      selectedStudyFocusId: _nonEmpty(
        prefs.getString(_scopedPreferenceKey(_keySelectedStudyFocusId)),
      ),
      selectedStudyFocusLabel: _nonEmpty(
        prefs.getString(_scopedPreferenceKey(_keySelectedStudyFocusLabel)),
      ),
    );
  }

  Future<void> saveOnboardingState(OnboardingState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _scopedPreferenceKey(_keyOnboardingCompleted),
      state.onboardingCompleted,
    );
    await prefs.setInt(
      _scopedPreferenceKey(_keyOnboardingVersion),
      state.onboardingVersion,
    );
    await _setOptionalString(
      prefs,
      _scopedPreferenceKey(_keyOnboardingCompletedAt),
      state.onboardingCompletedAt?.toIso8601String(),
    );
    await prefs.setBool(
      _scopedPreferenceKey(_keyProfilePersonalizationCompleted),
      state.profilePersonalizationCompleted,
    );
    await _setOptionalString(
      prefs,
      _scopedPreferenceKey(_keyProfilePersonalizationCompletedAt),
      state.profilePersonalizationCompletedAt?.toIso8601String(),
    );
    await prefs.setBool(
      _scopedPreferenceKey(_keyStarterSubjectsSeeded),
      state.starterSubjectsSeeded,
    );
    await _setOptionalString(
      prefs,
      _scopedPreferenceKey(_keyStarterSubjectsSeededAt),
      state.starterSubjectsSeededAt?.toIso8601String(),
    );
    await prefs.setBool(
      _scopedPreferenceKey(_keyLegacyMigrationCompleted),
      state.legacyMigrationCompleted,
    );
    await _setOptionalString(
      prefs,
      _scopedPreferenceKey(_keyLegacyMigrationCompletedAt),
      state.legacyMigrationCompletedAt?.toIso8601String(),
    );
    await prefs.setBool(
      _scopedPreferenceKey(_keyContextualGuideCompleted),
      state.contextualGuideCompleted,
    );
    await _setOptionalString(
      prefs,
      _scopedPreferenceKey(_keySelectedStudyProfileId),
      state.selectedStudyProfileId,
    );
    await _setOptionalString(
      prefs,
      _scopedPreferenceKey(_keySelectedStudyProfileLabel),
      state.selectedStudyProfileLabel,
    );
    await _setOptionalString(
      prefs,
      _scopedPreferenceKey(_keySelectedStudyFocusId),
      state.selectedStudyFocusId,
    );
    await _setOptionalString(
      prefs,
      _scopedPreferenceKey(_keySelectedStudyFocusLabel),
      state.selectedStudyFocusLabel,
    );
  }

  Future<void> markContextualGuideCompleted(bool value) async {
    final state = await getOnboardingState();
    await saveOnboardingState(state.copyWith(contextualGuideCompleted: value));
  }

  // ── Category Persistence ──

  Future<void> saveCustomCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scopedPreferenceKey(_keyCustomCategories),
      categories,
    );
  }

  Future<List<String>> getCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_scopedPreferenceKey(_keyCustomCategories)) ??
        [];
  }

  Future<void> saveDeletedDefaultCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scopedPreferenceKey(_keyDeletedDefaultCategories),
      categories,
    );
  }

  Future<List<String>> getDeletedDefaultCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(
          _scopedPreferenceKey(_keyDeletedDefaultCategories),
        ) ??
        [];
  }

  Future<void> saveLinkCategoriesToNotion(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedPreferenceKey(_keyLinkToNotion), value);
  }

  Future<bool> getLinkCategoriesToNotion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedPreferenceKey(_keyLinkToNotion)) ?? false;
  }

  Future<void> saveNotionCategoryField(String fieldName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedPreferenceKey(_keyNotionCategoryField),
      fieldName,
    );
  }

  Future<String?> getNotionCategoryField() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedPreferenceKey(_keyNotionCategoryField));
  }

  Future<void> clearNotionCategoryField() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedPreferenceKey(_keyNotionCategoryField));
  }

  // ── Cloud Sync Queue ──

  Future<List<SyncQueueItem>> getSyncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedData = prefs.getString(_scopedPreferenceKey(_keySyncQueue));
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
      _scopedPreferenceKey(_keySyncQueue),
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
    final encoded = prefs.getString(_scopedPreferenceKey(_keyCloudSyncState));
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
    await prefs.setString(
      _scopedPreferenceKey(_keyCloudSyncState),
      jsonEncode(state.toMap()),
    );
  }

  Future<Map<String, dynamic>> getCloudSettingsSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final source = await getRegisterFieldSource();
    final onboarding = await getOnboardingState();
    return {
      'themeMode': await getThemeMode(),
      'themeModeUpdatedAt': (await getThemeModeUpdatedAt())?.toIso8601String(),
      'defaultReminderMinutes': await getDefaultReminder(),
      'notionDatabaseId': await getNotionDatabaseId(),
      'notionTimeField': await getNotionTimeField(),
      'localTimeField': await getLocalTimeField(),
      'customCategories': await getCustomCategories(),
      'deletedDefaultCategories': await getDeletedDefaultCategories(),
      'linkCategoriesToNotion': await getLinkCategoriesToNotion(),
      'notionCategoryField': await getNotionCategoryField(),
      'registerFieldSource': source?.name ?? RegisterFieldSource.local.name,
      'lumaPersonalizationEnabled': await getLumaPersonalizationEnabled(),
      'goalTutorialSeen':
          prefs.getBool(_scopedPreferenceKey(_keyGoalTutorialSeen)) ?? false,
      ...onboarding.toMap(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> applyCloudSettingsSnapshot(Map<String, dynamic> map) async {
    final themeMode = map['themeMode']?.toString();
    if (themeMode == 'light' || themeMode == 'dark') {
      final prefs = await SharedPreferences.getInstance();
      final hasLocalTheme = prefs.containsKey(AppConstants.prefKeyThemeMode);
      final localThemeUpdatedAt = await getThemeModeUpdatedAt();
      final remoteThemeUpdatedAt = _date(map['themeModeUpdatedAt']?.toString());
      final shouldApplyTheme =
          !hasLocalTheme ||
          (remoteThemeUpdatedAt != null &&
              (localThemeUpdatedAt == null ||
                  remoteThemeUpdatedAt.isAfter(localThemeUpdatedAt)));
      if (shouldApplyTheme) {
        await saveThemeMode(themeMode!);
        debugPrint('[THEME] restored from cloud $themeMode');
      }
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

    if (map.containsKey('customCategories')) {
      await saveCustomCategories(
        List<String>.from(map['customCategories'] as List? ?? const []),
      );
    }
    if (map.containsKey('deletedDefaultCategories')) {
      await saveDeletedDefaultCategories(
        List<String>.from(map['deletedDefaultCategories'] as List? ?? const []),
      );
    }
    if (map['linkCategoriesToNotion'] is bool) {
      await saveLinkCategoriesToNotion(map['linkCategoriesToNotion'] as bool);
    }

    if (map.containsKey('notionCategoryField')) {
      final notionCategoryField = map['notionCategoryField']?.toString();
      if (notionCategoryField == null || notionCategoryField.isEmpty) {
        await clearNotionCategoryField();
      } else {
        await saveNotionCategoryField(notionCategoryField);
      }
    }

    final sourceName = map['registerFieldSource']?.toString();
    if (sourceName != null && sourceName.isNotEmpty) {
      final source = RegisterFieldSource.values.firstWhere(
        (source) => source.name == sourceName,
        orElse: () => RegisterFieldSource.local,
      );
      await saveRegisterFieldSource(source);
    }

    if (map['goalTutorialSeen'] is bool) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        _scopedPreferenceKey(_keyGoalTutorialSeen),
        map['goalTutorialSeen'] as bool,
      );
    }

    if (map['lumaPersonalizationEnabled'] is bool) {
      await saveLumaPersonalizationEnabled(
        map['lumaPersonalizationEnabled'] as bool,
      );
    }

    final existingOnboarding = await getOnboardingState();
    await saveOnboardingState(
      existingOnboarding.copyWith(
        onboardingCompleted:
            map['onboardingCompleted'] as bool? ??
            existingOnboarding.onboardingCompleted,
        onboardingVersion:
            (map['onboardingVersion'] as num?)?.toInt() ??
            existingOnboarding.onboardingVersion,
        onboardingCompletedAt:
            _date(map['onboardingCompletedAt']?.toString()) ??
            existingOnboarding.onboardingCompletedAt,
        profilePersonalizationCompleted:
            map['profilePersonalizationCompleted'] as bool? ??
            existingOnboarding.profilePersonalizationCompleted,
        profilePersonalizationCompletedAt:
            _date(map['profilePersonalizationCompletedAt']?.toString()) ??
            existingOnboarding.profilePersonalizationCompletedAt,
        starterSubjectsSeeded:
            map['starterSubjectsSeeded'] as bool? ??
            existingOnboarding.starterSubjectsSeeded,
        starterSubjectsSeededAt:
            _date(map['starterSubjectsSeededAt']?.toString()) ??
            existingOnboarding.starterSubjectsSeededAt,
        legacyMigrationCompleted:
            map['legacyMigrationCompleted'] as bool? ??
            existingOnboarding.legacyMigrationCompleted,
        legacyMigrationCompletedAt:
            _date(map['legacyMigrationCompletedAt']?.toString()) ??
            existingOnboarding.legacyMigrationCompletedAt,
        contextualGuideCompleted:
            map['contextualGuideCompleted'] as bool? ??
            existingOnboarding.contextualGuideCompleted,
        selectedStudyProfileId:
            map['selectedStudyProfileId']?.toString() ??
            existingOnboarding.selectedStudyProfileId,
        selectedStudyProfileLabel:
            map['selectedStudyProfileLabel']?.toString() ??
            existingOnboarding.selectedStudyProfileLabel,
        selectedStudyFocusId:
            map['selectedStudyFocusId']?.toString() ??
            existingOnboarding.selectedStudyFocusId,
        selectedStudyFocusLabel:
            map['selectedStudyFocusLabel']?.toString() ??
            existingOnboarding.selectedStudyFocusLabel,
      ),
    );
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
    final encoded = prefs.getString(_scopedPreferenceKey(_keyTimerStats));
    if (encoded == null || encoded.isEmpty) return const {};
    try {
      return Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    } catch (_) {
      return const {};
    }
  }

  Future<void> saveTimerStatsSnapshot(Map<String, dynamic> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedPreferenceKey(_keyTimerStats),
      jsonEncode(map),
    );
  }

  DateTime? _date(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _setOptionalString(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, value);
  }

  Future<String?> _readSecureValue(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } on PlatformException catch (e) {
      if (!_isSecureStorageCorruption(e)) rethrow;
      debugPrint(
        '[STORAGE] recovered corrupted secure storage read for ${_safeStorageKey(key)}',
      );
      await _deleteSecureValue(key);
      return null;
    }
  }

  Future<void> _writeSecureValue(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } on PlatformException catch (e) {
      if (!_isSecureStorageCorruption(e)) rethrow;
      debugPrint(
        '[STORAGE] recovered corrupted secure storage write for ${_safeStorageKey(key)}',
      );
      await _deleteSecureValue(key);
      await _secureStorage.write(key: key, value: value);
    }
  }

  Future<void> _deleteSecureValue(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } on PlatformException catch (e) {
      if (!_isSecureStorageCorruption(e)) rethrow;
      debugPrint(
        '[STORAGE] ignored corrupted secure storage delete for ${_safeStorageKey(key)}',
      );
    }
  }

  bool _isSecureStorageCorruption(PlatformException error) {
    final text = [
      error.code,
      error.message,
      error.details?.toString(),
    ].whereType<String>().join(' ').toLowerCase();
    return text.contains('badpaddingexception') ||
        text.contains('bad_decrypt') ||
        text.contains('aeadbadtagexception') ||
        text.contains('invalidkeyexception') ||
        text.contains('keypermanentlyinvalidatedexception') ||
        text.contains('javax.crypto');
  }

  String _safeStorageKey(String key) {
    final parts = key.split('.');
    if (parts.length >= 4 && parts.first == _namespacePrefix) {
      final namespace = parts[1];
      final account = parts[2];
      final suffix = parts.sublist(3).join('.');
      if (namespace == 'uid') {
        final masked = account.length <= 4
            ? '****'
            : '***${account.substring(account.length - 4)}';
        return '$_namespacePrefix.uid:$masked.$suffix';
      }
    }
    if (key.startsWith('$_namespacePrefix.$guestNamespace.')) {
      return key;
    }
    return key.contains('.') ? key.split('.').last : key;
  }
}
