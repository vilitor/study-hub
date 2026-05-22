import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_hub/config/app_constants.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/auth_session.dart';
import 'package:study_hub/models/certificate.dart';
import 'package:study_hub/models/cloud_sync.dart';
import 'package:study_hub/models/notion_schema.dart';
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/models/study_goal.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/providers/auth_session_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/screens/splash/startup_gate.dart';
import 'package:study_hub/screens/settings/settings_screen.dart';
import 'package:study_hub/services/auth_service.dart';
import 'package:study_hub/services/cloud_sync_service.dart';
import 'package:study_hub/services/google_calendar_service.dart';
import 'package:study_hub/services/storage_service.dart';
import 'package:study_hub/services/sync_merge_resolver.dart';
import 'package:study_hub/repositories/study_repository.dart';
import 'package:study_hub/repositories/auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() async {
    await StorageService().useGuestNamespace();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  test('sync queue replaces duplicate idempotency keys', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();

    await storage.enqueueSync(
      SyncQueueItem(
        idempotencyKey: 'records/1/upsert',
        collection: 'records',
        documentId: '1',
        operation: SyncQueueOperation.upsert,
        payload: const {'value': 1},
      ),
    );
    await storage.enqueueSync(
      SyncQueueItem(
        idempotencyKey: 'records/1/upsert',
        collection: 'records',
        documentId: '1',
        operation: SyncQueueOperation.upsert,
        payload: const {'value': 2},
      ),
    );

    final queue = await storage.getSyncQueue();
    expect(queue, hasLength(1));
    expect(queue.single.payload['value'], 2);
  });

  test('namespace migration recovers from corrupted secure storage', () async {
    SharedPreferences.setMockInitialValues({});
    final deletedKeys = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          switch (call.method) {
            case 'read':
              throw PlatformException(
                code: 'Exception encountered',
                message: 'read',
                details:
                    'javax.crypto.BadPaddingException: error:1e000065:Cipher functions:OPENSSL_internal:BAD_DECRYPT',
              );
            case 'delete':
              deletedKeys.add(call.arguments['key'] as String);
              return null;
            case 'write':
              return null;
          }
          return null;
        });

    final storage = StorageService();

    await storage.useUidNamespace('firebase-user', migrateLegacyUnscoped: true);

    expect(storage.activeNamespace, 'uid:firebase-user');
    expect(deletedKeys, isNotEmpty);
  });

  test('sync queue marks retry with bounded backoff metadata', () {
    final item = SyncQueueItem(
      idempotencyKey: 'records/1/upsert',
      collection: 'records',
      documentId: '1',
      operation: SyncQueueOperation.upsert,
      payload: const {},
    );

    final failed = item.markFailure(Exception('offline'));

    expect(failed.attemptCount, 1);
    expect(failed.lastError, contains('offline'));
    expect(failed.nextRetryAt, isNotNull);
    expect(failed.canRetry, isFalse);
  });

  test('cloud sync state persists last sync metadata', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final state = CloudSyncState(
      phase: CloudSyncPhase.offline,
      pendingCount: 2,
      lastSyncedAt: DateTime(2026, 5, 11, 10, 30),
      lastRestoreAt: DateTime(2026, 5, 11, 10, 31),
      lastAttemptAt: DateTime(2026, 5, 11, 10, 32),
      lastError: 'Offline mode active',
    );

    await storage.saveCloudSyncState(state);
    final restored = await storage.getCloudSyncState();

    expect(restored.phase, CloudSyncPhase.offline);
    expect(restored.pendingCount, 2);
    expect(restored.lastSyncedAt, DateTime(2026, 5, 11, 10, 30));
    expect(restored.lastRestoreAt, DateTime(2026, 5, 11, 10, 31));
    expect(restored.lastAttemptAt, DateTime(2026, 5, 11, 10, 32));
    expect(restored.lastError, 'Offline mode active');
  });

  test('stale syncing cloud state is normalized on load', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.saveCloudSyncState(
      CloudSyncState(
        phase: CloudSyncPhase.syncing,
        lastAttemptAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    );

    await CloudSyncService.instance.loadState();

    expect(CloudSyncService.instance.state.phase, CloudSyncPhase.timeout);
    expect(CloudSyncService.instance.state.lastError, contains('interrompida'));
  });

  test('reset run context clears visible syncing state', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.saveCloudSyncState(
      CloudSyncState(
        phase: CloudSyncPhase.syncing,
        lastAttemptAt: DateTime.now(),
      ),
    );
    await CloudSyncService.instance.loadState();

    CloudSyncService.instance.resetRunContext();
    await Future<void>.delayed(Duration.zero);

    expect(CloudSyncService.instance.state.isSyncing, isFalse);
  });

  test('newest merge policy keeps the latest updatedAt value', () {
    final local = StudyGoal(
      id: 'goal-1',
      type: GoalType.weekly,
      targetMinutes: 60,
      languages: const ['Dart'],
      periodStart: DateTime(2026, 5, 3),
      updatedAt: DateTime(2026, 5, 7, 10),
    );
    final remote = local.copyWith(
      targetMinutes: 90,
      updatedAt: DateTime(2026, 5, 7, 11),
    );

    final chosen = SyncMergeResolver.newest(
      local: local,
      remote: remote,
      localUpdatedAt: local.updatedAt,
      remoteUpdatedAt: remote.updatedAt,
    );

    expect(chosen.targetMinutes, 90);
  });

  test('delete tombstone policy wins over older local update', () {
    final remoteWins = SyncMergeResolver.remoteWins(
      localUpdatedAt: DateTime(2026, 5, 11, 9),
      remoteUpdatedAt: DateTime(2026, 5, 11, 8),
      remoteDeletedAt: DateTime(2026, 5, 11, 10),
    );

    expect(remoteWins, isTrue);
  });

  test(
    'cloud settings snapshot excludes private integration secrets',
    () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.prefKeyThemeMode: 'dark',
      });
      final storage = StorageService();
      await storage.saveDefaultReminder(30);
      await storage.saveCustomCategories(['Flutter']);

      final snapshot = await storage.getCloudSettingsSnapshot();

      expect(snapshot['themeMode'], 'dark');
      expect(snapshot['defaultReminderMinutes'], 30);
      expect(snapshot['customCategories'], ['Flutter']);
      expect(snapshot.containsKey(AppConstants.storageKeyNotionToken), isFalse);
      expect(snapshot.containsKey('notion_token'), isFalse);
    },
  );

  test('certificate attachment cloud metadata round-trips', () {
    final uploadedAt = DateTime(2026, 5, 11, 12);
    final attachment = CertificateAttachment(
      originalName: 'cert.pdf',
      localPath: '/local/cert.pdf',
      mimeType: 'application/pdf',
      fileType: CertificateFileType.pdf,
      fileSizeBytes: 42,
      remotePath: 'users/u1/certificates/c1/attachments/a1/cert.pdf',
      remoteUploadedAt: uploadedAt,
    );

    final restored = CertificateAttachment.fromMap(attachment.toMap());

    expect(restored.remotePath, attachment.remotePath);
    expect(restored.remoteUploadedAt, uploadedAt);
  });

  test(
    'certificate Firestore payload is metadata-only while Storage is off',
    () {
      final certificate = Certificate(
        id: 'cert-1',
        title: 'Flutter course',
        provider: 'Provider',
        attachments: [
          CertificateAttachment(
            originalName: 'cert.pdf',
            localPath: '/private/device/path/cert.pdf',
            mimeType: 'application/pdf',
            fileType: CertificateFileType.pdf,
            fileSizeBytes: 42,
            remotePath: 'users/u1/certificates/cert-1/attachments/a1/cert.pdf',
            remoteUploadedAt: DateTime(2026, 5, 11, 12),
          ),
        ],
      );

      final payload = CloudSyncService.certificateMetadataOnlyPayload(
        certificate.toMap(),
      );

      expect(payload['attachmentSync'], 'localOnly');
      expect(payload['attachments'], isEmpty);
      expect(payload.toString(), isNot(contains('/private/device/path')));
      expect(payload.toString(), isNot(contains('users/u1/certificates')));
    },
  );

  test('failed queue item does not remove independent queued items', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final first = SyncQueueItem(
      idempotencyKey: 'studyLogs/1',
      collection: CloudCollections.studyLogs,
      documentId: '1',
      operation: SyncQueueOperation.upsert,
      payload: const {'value': 1},
    );
    final second = SyncQueueItem(
      idempotencyKey: 'goals/2',
      collection: CloudCollections.goals,
      documentId: '2',
      operation: SyncQueueOperation.upsert,
      payload: const {'value': 2},
    );

    await storage.enqueueSync(first);
    await storage.enqueueSync(second);
    await storage.replaceQueuedSync(first.markFailure(Exception('timeout')));

    final queue = await storage.getSyncQueue();
    expect(queue, hasLength(2));
    expect(queue.first.canRetry, isFalse);
    expect(queue.last.idempotencyKey, 'goals/2');
    expect(queue.last.canRetry, isTrue);
  });

  test(
    'Google Calendar creation is triggered after local event save',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      final calendar = _FakeCalendarService(
        result: const CalendarCreateResult.success('google-1'),
      );
      final repository = StudyRepository(
        storageService: storage,
        googleCalendarService: calendar,
      );
      final event = _event();

      final googleId = await repository.scheduleEvent(event);
      final stored = await storage.getStudyEvents();

      expect(calendar.createRequests, 1);
      expect(googleId, 'google-1');
      expect(stored.single.calendarEventId, 'google-1');
      expect(stored.single.syncedWithCalendar, isTrue);
    },
  );

  test('Calendar failure keeps local event pending for retry', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final calendar = _FakeCalendarService(
      result: const CalendarCreateResult.failure('token invalid'),
    );
    final repository = StudyRepository(
      storageService: storage,
      googleCalendarService: calendar,
    );
    final event = _event();

    final googleId = await repository.scheduleEvent(event);
    final stored = await storage.getStudyEvents();

    expect(calendar.createRequests, 1);
    expect(googleId, isNull);
    expect(repository.lastCalendarError, 'token invalid');
    expect(stored.single.syncedWithCalendar, isFalse);
    expect(stored.single.calendarEventId, isNull);
    expect(stored.single.syncStatus, CloudSyncStatus.pendingSync);
  });

  test('Calendar API disabled error is converted to actionable copy', () {
    final message = GoogleCalendarService.friendlyCalendarError(
      'DetailedApiRequestError(status: 403, message: Google Calendar API has not been used in project 539437186516 before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/calendar-json.googleapis.com/overview?project=539437186516 then retry.)',
    );

    expect(message, contains('API Google Calendar está desativada'));
    expect(message, contains('calendar-json.googleapis.com'));
  });

  test('timeout and error sync states are not active syncing states', () {
    const syncing = CloudSyncState(phase: CloudSyncPhase.syncing);

    final timeout = syncing.copyWith(
      phase: CloudSyncPhase.timeout,
      lastError: 'studyLogs restore timeout',
    );
    final recovered = timeout.copyWith(
      phase: CloudSyncPhase.pending,
      pendingCount: 1,
      clearError: true,
    );

    expect(timeout.isSyncing, isFalse);
    expect(timeout.lastError, contains('timeout'));
    expect(recovered.isSyncing, isFalse);
    expect(recovered.lastError, isNull);
    expect(recovered.pendingCount, 1);
  });

  test('release auth uses explicit web OAuth server client id', () {
    expect(AppConstants.googleWebClientId, isNotEmpty);
    expect(
      AppConstants.googleWebClientId,
      endsWith('.apps.googleusercontent.com'),
    );
    expect(AuthService.serverClientId, AppConstants.googleWebClientId);
    expect(AuthService.hasConfiguredServerClientId, isTrue);
  });

  test('auth diagnostics classify missing Google tokens separately', () {
    final missingIdToken = AuthService.diagnosticForMissingTokens(
      hasIdToken: false,
      hasAccessToken: true,
    );
    final missingAccessToken = AuthService.diagnosticForMissingTokens(
      hasIdToken: true,
      hasAccessToken: false,
    );

    expect(missingIdToken.reason, AuthFailureReason.missingGoogleIdToken);
    expect(missingIdToken.manualAction, contains('serverClientId'));
    expect(
      missingAccessToken.reason,
      AuthFailureReason.missingGoogleAccessToken,
    );
  });

  test(
    'auth diagnostics classify release OAuth and Play Services failures',
    () {
      final oauthMismatch = AuthService.diagnosticForAuthError(
        PlatformException(
          code: 'sign_in_failed',
          message: 'com.google.android.gms.common.api.ApiException: 10',
        ),
      );
      final playServices = AuthService.diagnosticForAuthError(
        PlatformException(
          code: 'sign_in_failed',
          message: 'com.google.android.gms.common.api.ApiException: 12500',
        ),
      );

      expect(oauthMismatch.reason, AuthFailureReason.missingOAuthClient);
      expect(playServices.reason, AuthFailureReason.playServicesUnavailable);
    },
  );

  test('Google Calendar sign-in uses the narrow event scope only', () {
    expect(
      AuthService.calendarScopes,
      contains('https://www.googleapis.com/auth/calendar.events'),
    );
    expect(
      AuthService.calendarScopes,
      isNot(contains('https://www.googleapis.com/auth/calendar')),
    );
  });

  test('legacy study payloads default to local-only sync metadata', () {
    final schema = NotionDatabaseSchema(
      properties: {
        'Name': NotionProperty(id: 'name', name: 'Name', type: 'title'),
      },
    );
    final log = StudyLog.fromMap({
      'id': 'legacy-log',
      'rawValues': {'Name': 'Legacy'},
      'schema': schema.toJson(),
      'date': DateTime(2026, 5, 7).toIso8601String(),
    });
    final event = StudyEvent.fromMap({
      'id': 'legacy-event',
      'subject': 'Dart',
      'title': 'Study',
      'date': DateTime(2026, 5, 7).toIso8601String(),
      'startTimeHour': 9,
      'startTimeMinute': 0,
      'endTimeHour': 10,
      'endTimeMinute': 0,
    });

    expect(log.syncStatus, CloudSyncStatus.localOnly);
    expect(event.syncStatus, CloudSyncStatus.localOnly);
    expect(log.updatedAt, DateTime(2026, 5, 7));
  });

  test(
    'auth session supports guest mode without Firebase initialization',
    () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AuthSessionProvider();
      await provider.loadSession();

      await provider.continueAsGuest();

      expect(provider.status, AuthSessionStatus.guest);
      expect(provider.hasEntryChoice, isTrue);
      expect(provider.uid, isNull);
    },
  );

  test('guest entry clears loading and activates guest namespace', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = AuthSessionProvider(autoLoad: false);

    await provider.continueAsGuest();

    expect(provider.isLoading, isFalse);
    expect(provider.status, AuthSessionStatus.guest);
    expect(StorageService().activeNamespace, StorageService.guestNamespace);
  });

  test('Google login timeout does not leave auth stuck loading', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = AuthSessionProvider(
      authRepository: _HangingAuthRepository(),
      sessionTimeout: const Duration(milliseconds: 10),
      autoLoad: false,
    );

    final success = await provider.signInWithGoogle();

    expect(success, isFalse);
    expect(provider.isLoading, isFalse);
    expect(provider.status, AuthSessionStatus.authError);
  });

  testWidgets('fresh startup shows dedicated login screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.loadSettings();
    final auth = AuthSessionProvider();
    await auth.loadSession();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: StartupGate(destination: Text('Main app')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('StudyHub'), findsOneWidget);
    expect(find.byKey(const ValueKey('login-google-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-guest-button')), findsOneWidget);
    expect(find.text('Main app'), findsNothing);
  });

  testWidgets('guest startup enters app without cloud sync gate', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'auth_entry_choice': 'guest'});
    final settings = SettingsProvider();
    await settings.loadSettings();
    final auth = AuthSessionProvider();
    await auth.loadSession();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: StartupGate(destination: Text('Main app')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Main app'), findsOneWidget);
    expect(find.byKey(const ValueKey('login-google-button')), findsNothing);
  });

  testWidgets('settings shows Firebase Google entry state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.loadSettings();
    final auth = AuthSessionProvider();
    await auth.loadSession();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Google Calendar'), findsOneWidget);
    expect(
      find.text('Entrar para backup Firebase e sincronizar Calendar.'),
      findsOneWidget,
    );
  });

  testWidgets('settings shows offline sync metadata', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.saveCloudSyncState(
      const CloudSyncState(
        phase: CloudSyncPhase.offline,
        pendingCount: 3,
        lastError: 'Offline mode active',
      ),
    );
    await CloudSyncService.instance.loadState();

    final settings = SettingsProvider();
    await settings.loadSettings();
    await settings.setGoogleConnected('user@example.com', 'User', '');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: CloudSyncService.instance,
        child: ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Backup na nuvem'), findsOneWidget);
    expect(find.textContaining('Modo offline ativo'), findsOneWidget);
  });
}

class _FakeCalendarService extends GoogleCalendarService {
  final CalendarCreateResult result;
  int createRequests = 0;

  _FakeCalendarService({required this.result});

  @override
  Future<CalendarCreateResult> createEventWithResult(StudyEvent event) async {
    createRequests++;
    return result;
  }
}

class _HangingAuthRepository extends AuthRepository {
  @override
  Future<GoogleFirebaseSignInResult> login() {
    return Future<GoogleFirebaseSignInResult>.delayed(
      const Duration(minutes: 5),
      () => GoogleFirebaseSignInResult.failure(
        const AuthDiagnostic(
          reason: AuthFailureReason.unknown,
          message: 'late failure',
        ),
      ),
    );
  }
}

StudyEvent _event() {
  return StudyEvent(
    subject: 'Medicina',
    title: 'Revisar anatomia',
    date: DateTime(2026, 5, 20),
    startTime: const TimeOfDay(hour: 9, minute: 0),
    endTime: const TimeOfDay(hour: 10, minute: 0),
  );
}
