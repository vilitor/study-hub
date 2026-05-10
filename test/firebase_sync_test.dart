import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_hub/config/app_constants.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/auth_session.dart';
import 'package:study_hub/models/cloud_sync.dart';
import 'package:study_hub/models/notion_schema.dart';
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/models/study_goal.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/providers/auth_session_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/screens/settings/settings_screen.dart';
import 'package:study_hub/services/auth_service.dart';
import 'package:study_hub/services/storage_service.dart';
import 'package:study_hub/services/sync_merge_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() {
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

  test('Google Calendar scopes are preserved for shared sign-in', () {
    expect(
      AuthService.calendarScopes,
      contains('https://www.googleapis.com/auth/calendar'),
    );
    expect(
      AuthService.calendarScopes,
      contains('https://www.googleapis.com/auth/calendar.events'),
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
}
