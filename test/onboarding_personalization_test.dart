import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_hub/config/app_constants.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/app_settings.dart';
import 'package:study_hub/models/auth_session.dart';
import 'package:study_hub/models/cloud_sync.dart';
import 'package:study_hub/models/notion_schema.dart';
import 'package:study_hub/models/onboarding_state.dart';
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/models/study_goal.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/providers/auth_session_provider.dart';
import 'package:study_hub/providers/local_study_schema_provider.dart';
import 'package:study_hub/providers/onboarding_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/repositories/auth_repository.dart';
import 'package:study_hub/repositories/subject_repository.dart';
import 'package:study_hub/screens/splash/startup_gate.dart';
import 'package:study_hub/services/app_account_deletion_service.dart';
import 'package:study_hub/services/local_study_schema_service.dart';
import 'package:study_hub/services/onboarding_migration_service.dart';
import 'package:study_hub/services/starter_subject_seeding_service.dart';
import 'package:study_hub/services/storage_service.dart';
import 'package:study_hub/services/study_profile_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final secureValues = <String, String>{};

  setUp(() async {
    await StorageService().useGuestNamespace();
    secureValues.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          switch (call.method) {
            case 'read':
              return secureValues[call.arguments['key'] as String];
            case 'write':
              secureValues[call.arguments['key'] as String] =
                  call.arguments['value'] as String;
              return null;
            case 'delete':
              secureValues.remove(call.arguments['key'] as String);
              return null;
            case 'deleteAll':
              secureValues.clear();
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  testWidgets('fresh guest startup shows onboarding before main app', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'auth_entry_choice': 'guest'});
    final settings = SettingsProvider();
    await settings.loadSettings();
    final auth = AuthSessionProvider();
    await auth.loadSession();
    final onboarding = OnboardingProvider(autoLoad: false);
    await onboarding.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: onboarding),
          ChangeNotifierProvider(
            create: (_) => LocalStudySchemaProvider(autoLoad: false),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const StartupGate(destination: Text('Main app')),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(
        'Organize estudos, registre progresso, acompanhe metas e mantenha tudo local-first com sincronização quando estiver disponível.',
      ),
      findsOneWidget,
    );
    expect(find.text('Main app'), findsNothing);
  });

  test('fresh Google namespace shows onboarding', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.useUidNamespace('fresh-google-user');
    final onboarding = OnboardingProvider(storage: storage, autoLoad: false);

    await onboarding.load();

    expect(onboarding.shouldShowOnboarding, isTrue);
  });

  testWidgets('returning completed user skips onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({'auth_entry_choice': 'guest'});
    await StorageService().saveOnboardingState(
      const OnboardingState(
        onboardingCompleted: true,
        onboardingVersion: StudyProfileCatalog.currentOnboardingVersion,
      ),
    );
    final settings = SettingsProvider();
    await settings.loadSettings();
    final auth = AuthSessionProvider();
    await auth.loadSession();
    final onboarding = OnboardingProvider(autoLoad: false);
    await onboarding.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: onboarding),
          ChangeNotifierProvider(
            create: (_) => LocalStudySchemaProvider(autoLoad: false),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const StartupGate(destination: Text('Main app')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Main app'), findsOneWidget);
  });

  test('legacy detection covers meaningful app state', () async {
    final cases = <String, Future<void> Function(StorageService)>{
      'logs': (storage) async => storage.saveStudyLogs([_log()]),
      'goals': (storage) async => storage.saveStudyGoals([_goal()]),
      'events': (storage) async => storage.saveStudyEvents([_event()]),
      'local schema': (storage) async =>
          storage.saveLocalStudyFields(LocalStudySchemaService.defaultFields()),
      'custom categories': (storage) async =>
          storage.saveCustomCategories(['Python']),
      'deleted defaults': (storage) async =>
          storage.saveDeletedDefaultCategories(['Dart']),
      'Notion-linked categories': (storage) async =>
          storage.saveLinkCategoriesToNotion(true),
      'Notion schema/config': (storage) async =>
          storage.saveNotionSchema('{"properties":{}}'),
    };

    for (final entry in cases.entries) {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await entry.value(storage);

      final snapshot = await OnboardingMigrationService(
        storage: storage,
      ).inspect();

      expect(snapshot.isLegacy, isTrue, reason: entry.key);
    }
  });

  test(
    'local schema provider can be created without auto-writing defaults',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      final provider = LocalStudySchemaProvider(autoLoad: false);

      expect(await storage.hasPersistedLocalStudyFields(), isFalse);
      expect(provider.activeFields, isEmpty);
    },
  );

  test('starter subject seeding is idempotent and marks completion', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.saveCustomCategories(['Python']);
    await storage.saveOnboardingState(
      const OnboardingState(
        profilePersonalizationCompleted: true,
        selectedStudyProfileId: 'technology',
        selectedStudyFocusId: 'software_development',
      ),
    );
    final service = StarterSubjectSeedingService(storage: storage);
    final state = await storage.getOnboardingState();

    final first = await service.seedIfNeeded(state);
    final second = await service.seedIfNeeded(first);
    final subjects = await storage.getCustomCategories();

    expect(first.starterSubjectsSeeded, isTrue);
    expect(second.starterSubjectsSeeded, isTrue);
    expect(subjects.where((subject) => subject == 'Python'), hasLength(1));
    expect(subjects, contains('JavaScript'));
    expect(await storage.hasPersistedLocalStudyFields(), isTrue);
  });

  test('theme mode persists locally across settings reloads', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.loadSettings();

    await settings.setThemeMode('dark');

    final reloaded = SettingsProvider();
    await reloaded.loadSettings();

    expect(reloaded.settings.themeMode, 'dark');
  });

  test('Account A data never appears in Account B namespace', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();

    await storage.useUidNamespace('account-a');
    await storage.saveStudyLogs([_log()]);
    await storage.saveCustomCategories(['Anatomia']);

    await storage.useUidNamespace('account-b');

    expect(await storage.getStudyLogs(), isEmpty);
    expect(await storage.getCustomCategories(), isEmpty);
  });

  test(
    'provider reload clears previous account memory after UID switch',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.useUidNamespace('account-a');
      await storage.saveStudyLogs([_log()]);
      final provider = StudyLogProvider();
      await provider.loadLogs();
      expect(provider.logs, hasLength(1));

      await storage.useUidNamespace('account-b');
      await provider.loadLogs();

      expect(provider.logs, isEmpty);
    },
  );

  test('guest data is isolated from authenticated namespaces', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();

    await storage.useGuestNamespace();
    await storage.saveStudyGoals([_goal()]);

    await storage.useUidNamespace('account-a');
    expect(await storage.getStudyGoals(), isEmpty);

    await storage.useGuestNamespace();
    expect(await storage.getStudyGoals(), hasLength(1));
  });

  test('sync queue is scoped by active namespace', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();

    await storage.useUidNamespace('account-a');
    await storage.enqueueSync(
      SyncQueueItem(
        idempotencyKey: 'studyLogs/a',
        collection: 'studyLogs',
        documentId: 'a',
        operation: SyncQueueOperation.upsert,
        payload: const {'value': 'a'},
      ),
    );

    await storage.useUidNamespace('account-b');
    expect(await storage.getSyncQueue(), isEmpty);
  });

  test(
    'deleted account namespace logs in again as new onboarding user',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.useUidNamespace('deleted-user');
      await storage.saveOnboardingState(
        const OnboardingState(onboardingCompleted: true),
      );
      await storage.clearActiveAccountData();

      final onboarding = OnboardingProvider(storage: storage, autoLoad: false);
      await onboarding.load();

      expect(onboarding.shouldShowOnboarding, isTrue);
    },
  );

  test(
    'pre-onboarding default schema preview does not classify account as legacy',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.useUidNamespace('new-user-after-delete');
      await storage.clearActiveAccountData();

      final schema = LocalStudySchemaProvider(autoLoad: false);
      await schema.loadFields(persistDefaultFields: false);

      final migration = await OnboardingMigrationService(
        storage: storage,
      ).inspect();
      final onboarding = OnboardingProvider(storage: storage, autoLoad: false);
      await onboarding.load();

      expect(migration.hasPersistedLocalSchema, isFalse);
      expect(migration.isLegacy, isFalse);
      expect(onboarding.shouldShowOnboarding, isTrue);
    },
  );

  test(
    'partial cloud settings do not reset local theme or categories',
    () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.prefKeyThemeMode: 'dark',
      });
      final storage = StorageService();
      await storage.saveCustomCategories(['Anatomia']);
      await storage.saveLinkCategoriesToNotion(true);

      await storage.applyCloudSettingsSnapshot({'defaultReminderMinutes': 45});

      expect(await storage.getThemeMode(), 'dark');
      expect(await storage.getCustomCategories(), ['Anatomia']);
      expect(await storage.getLinkCategoriesToNotion(), isTrue);
      expect(await storage.getDefaultReminder(), 45);
    },
  );

  test('stale cloud theme does not override local dark preference', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.saveThemeMode('dark');

    await storage.applyCloudSettingsSnapshot({
      'themeMode': 'light',
      'updatedAt': DateTime.now().toIso8601String(),
    });

    expect(await storage.getThemeMode(), 'dark');
  });

  test(
    'onboarding completion continues when subject seeding times out',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      final provider = OnboardingProvider(
        storage: storage,
        seeding: _HangingSeedingService(storage: storage),
        seedingTimeout: const Duration(milliseconds: 10),
        autoLoad: false,
      );
      final medicine = const StudyProfileCatalog().findProfile('medicine')!;

      await provider.completeOnboarding(profile: medicine);
      final state = await storage.getOnboardingState();

      expect(provider.state.onboardingCompleted, isTrue);
      expect(provider.state.profilePersonalizationCompleted, isTrue);
      expect(provider.state.selectedStudyProfileId, 'medicine');
      expect(provider.state.starterSubjectsSeeded, isFalse);
      expect(provider.lastError, isNotNull);
      expect(state.onboardingCompleted, isTrue);
    },
  );

  test('Portuguese profile labels are used', () {
    const catalog = StudyProfileCatalog();

    expect(catalog.findProfile('technology')!.label, 'Tecnologia / TI');
    expect(catalog.findProfile('medicine')!.label, 'Medicina');
    expect(catalog.findProfile('psychology')!.label, 'Psicologia');
    expect(catalog.findProfile('law')!.label, 'Direito');
    expect(catalog.findProfile('other')!.label, 'Outro');
  });

  test('Technology profile resolves technology starter subjects', () {
    final subjects = const SubjectRepository().getSubjects(
      settings: const AppSettings(
        profilePersonalizationCompleted: true,
        selectedStudyProfileId: 'technology',
        selectedStudyFocusId: 'software_development',
      ),
      schema: null,
    );

    expect(subjects, contains('JavaScript'));
    expect(subjects, contains('APIs'));
  });

  test('Medicine profile resolves medicine starter subjects', () {
    final subjects = const SubjectRepository().getSubjects(
      settings: const AppSettings(
        profilePersonalizationCompleted: true,
        selectedStudyProfileId: 'medicine',
      ),
      schema: null,
    );

    expect(subjects, contains('Anatomia'));
    expect(subjects, contains('Farmacologia'));
    expect(subjects, isNot(contains('JavaScript')));
  });

  test('Psychology profile resolves psychology starter subjects', () {
    final subjects = const SubjectRepository().getSubjects(
      settings: const AppSettings(
        profilePersonalizationCompleted: true,
        selectedStudyProfileId: 'psychology',
      ),
      schema: null,
    );

    expect(subjects, contains('Psicologia Cognitiva'));
    expect(subjects, contains('Psicopatologia'));
    expect(subjects, isNot(contains('Anatomia')));
  });

  test('seeded stale technology subjects are replaced by selected profile', () {
    final subjects = const SubjectRepository().getSubjects(
      settings: const AppSettings(
        profilePersonalizationCompleted: true,
        starterSubjectsSeeded: true,
        selectedStudyProfileId: 'medicine',
        customCategories: ['Lógica', 'Python', 'JavaScript'],
      ),
      schema: null,
    );

    expect(subjects, contains('Anatomia'));
    expect(subjects, contains('Farmacologia'));
    expect(subjects, isNot(contains('JavaScript')));
  });

  test('starter seeding replaces safe stale technology categories', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.saveCustomCategories(['Lógica', 'Python', 'JavaScript']);
    await storage.saveOnboardingState(
      const OnboardingState(
        profilePersonalizationCompleted: true,
        selectedStudyProfileId: 'medicine',
      ),
    );
    final service = StarterSubjectSeedingService(storage: storage);

    final next = await service.seedIfNeeded(await storage.getOnboardingState());
    final subjects = await storage.getCustomCategories();

    expect(next.starterSubjectsSeeded, isTrue);
    expect(subjects, contains('Anatomia'));
    expect(subjects, isNot(contains('JavaScript')));
  });

  test(
    'starter seeding replaces legacy English technology categories',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.saveCustomCategories(['Logic', 'Python', 'JavaScript']);
      await storage.saveOnboardingState(
        const OnboardingState(
          profilePersonalizationCompleted: true,
          selectedStudyProfileId: 'law',
        ),
      );
      final service = StarterSubjectSeedingService(storage: storage);

      await service.seedIfNeeded(await storage.getOnboardingState());
      final subjects = await storage.getCustomCategories();

      expect(subjects, contains('Direito Constitucional'));
      expect(subjects, isNot(contains('JavaScript')));
      expect(subjects, isNot(contains('Logic')));
    },
  );

  test('Other profile keeps subjects empty intentionally', () async {
    final settings = const AppSettings(
      profilePersonalizationCompleted: true,
      selectedStudyProfileId: 'other',
      customCategories: [],
    );

    final subjects = const SubjectRepository().getSubjects(
      settings: settings,
      schema: null,
    );

    expect(subjects, isEmpty);
  });

  test('seeded personalized subjects stay editable after restart', () {
    final subjects = const SubjectRepository().getSubjects(
      settings: const AppSettings(
        profilePersonalizationCompleted: true,
        starterSubjectsSeeded: true,
        selectedStudyProfileId: 'medicine',
        customCategories: ['Anatomia', 'Laboratório Próprio'],
      ),
      schema: null,
    );

    expect(subjects, ['Anatomia', 'Laboratório Próprio']);
    expect(subjects, isNot(contains('Farmacologia')));
  });

  test('Notion-linked subjects keep priority over local profile subjects', () {
    final settings = const AppSettings(
      isNotionConnected: true,
      notionDatabaseId: 'db',
      linkCategoriesToNotion: true,
      notionCategoryField: 'Materia',
      profilePersonalizationCompleted: true,
      customCategories: ['Python'],
    );
    final schema = NotionDatabaseSchema(
      properties: {
        'Materia': NotionProperty(
          id: 'p1',
          name: 'Materia',
          type: 'select',
          options: const ['Notion Subject'],
        ),
      },
    );

    final subjects = const SubjectRepository().getSubjects(
      settings: settings,
      schema: schema,
    );

    expect(subjects, ['Notion Subject']);
  });

  test('legacy users keep backward-compatible default subjects', () {
    final subjects = const SubjectRepository().getSubjects(
      settings: const AppSettings(
        profilePersonalizationCompleted: true,
        legacyMigrationCompleted: true,
        selectedStudyProfileId: 'medicine',
        customCategories: ['Custom Legacy'],
      ),
      schema: null,
    );

    expect(subjects, contains('Dart'));
    expect(subjects, contains('Custom Legacy'));
    expect(subjects, isNot(contains('Anatomia')));
  });

  test(
    'local schema category options update for new personalized users',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.saveLocalStudyFields(
        LocalStudySchemaService.defaultFields(),
      );
      final provider = LocalStudySchemaProvider(autoLoad: false);
      final subjects = const StudyProfileCatalog().starterSubjects(
        profileId: 'medicine',
        focusId: null,
      );

      await provider.loadFields(
        defaultCategories: subjects,
        useFallbackCategories: false,
        refreshDefaultCategoryOptions: true,
      );

      final category = provider.activeFields.firstWhere(
        (field) => field.id == 'local_category',
      );
      expect(category.options, contains('Anatomia'));
      expect(category.options, isNot(contains('Flutter')));
    },
  );

  test(
    'local schema category options preserve user-customized fields',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      final customized = LocalStudySchemaService.defaultFields();
      final categoryIndex = customized.indexWhere(
        (field) => field.id == 'local_category',
      );
      customized[categoryIndex] = customized[categoryIndex].copyWith(
        options: const ['My Custom Subject'],
      );
      await storage.saveLocalStudyFields(customized);
      final provider = LocalStudySchemaProvider(autoLoad: false);
      final subjects = const StudyProfileCatalog().starterSubjects(
        profileId: 'medicine',
        focusId: null,
      );

      await provider.loadFields(
        defaultCategories: subjects,
        useFallbackCategories: false,
        refreshDefaultCategoryOptions: true,
      );

      final category = provider.activeFields.firstWhere(
        (field) => field.id == 'local_category',
      );
      expect(category.options, ['My Custom Subject']);
    },
  );

  test('delete app account clears authenticated local app data', () async {
    SharedPreferences.setMockInitialValues({
      'auth_entry_choice': 'google',
      AppConstants.prefKeyThemeMode: 'dark',
    });
    final storage = StorageService();
    final auth = _FakeAuthRepository();
    await storage.useUidNamespace('test-user');
    await storage.saveStudyLogs([_log()]);
    await storage.saveCustomCategories(['Anatomia']);

    await AppAccountDeletionService(
      storage: storage,
      authRepository: auth,
    ).deleteAppAccount(isGuest: false, uid: 'test-user');

    expect(await storage.getStudyLogs(), isEmpty);
    expect(await storage.getCustomCategories(), isEmpty);
    expect(await storage.getThemeMode(), 'dark');
    expect(auth.disconnectCalls, 1);
    expect(auth.logoutCalls, 0);
  });

  test('delete app account clears guest local data', () async {
    SharedPreferences.setMockInitialValues({'auth_entry_choice': 'guest'});
    final storage = StorageService();
    final auth = _FakeAuthRepository();
    await storage.saveStudyGoals([_goal()]);
    await storage.saveStudyEvents([_event()]);

    await AppAccountDeletionService(
      storage: storage,
      authRepository: auth,
    ).deleteAppAccount(isGuest: true);

    expect(await storage.getStudyGoals(), isEmpty);
    expect(await storage.getStudyEvents(), isEmpty);
    expect(auth.logoutCalls, 1);
    expect(auth.disconnectCalls, 0);
  });

  test(
    'account deletion reset also clears live Google session provider cache',
    () async {
      SharedPreferences.setMockInitialValues({'auth_entry_choice': 'google'});
      final auth = _FakeAuthRepository();
      final provider = AuthSessionProvider(
        authRepository: auth,
        autoLoad: false,
      );

      await provider.resetAfterAccountDeletion();

      expect(auth.disconnectCalls, 1);
      expect(provider.status, AuthSessionStatus.signedOut);
      expect(provider.hasEntryChoice, isFalse);
      expect(StorageService().activeNamespace, StorageService.guestNamespace);
    },
  );

  test(
    'cloud settings snapshot persists onboarding version and profile flag',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.saveOnboardingState(
        const OnboardingState(
          onboardingCompleted: true,
          onboardingVersion: 1,
          profilePersonalizationCompleted: true,
        ),
      );
      final snapshot = await storage.getCloudSettingsSnapshot();

      expect(snapshot['onboardingVersion'], 1);
      expect(snapshot['profilePersonalizationCompleted'], isTrue);
    },
  );

  test(
    'cloud settings snapshot includes selected profile and seeded subjects',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.saveOnboardingState(
        const OnboardingState(
          onboardingCompleted: true,
          onboardingVersion: 1,
          profilePersonalizationCompleted: true,
          starterSubjectsSeeded: true,
          selectedStudyProfileId: 'engineering',
          selectedStudyProfileLabel: 'Engenharia',
        ),
      );
      await storage.saveCustomCategories(['Cálculo', 'Física']);

      final snapshot = await storage.getCloudSettingsSnapshot();

      expect(snapshot['selectedStudyProfileId'], 'engineering');
      expect(snapshot['selectedStudyProfileLabel'], 'Engenharia');
      expect(snapshot['customCategories'], ['Cálculo', 'Física']);
    },
  );
}

StudyLog _log() {
  final schema = LocalStudySchemaService.defaultSchema();
  return StudyLog(
    rawValues: const {
      LocalStudyFields.title: 'Aula',
      LocalStudyFields.studyTime: 20,
    },
    schema: schema,
    studyTimeField: LocalStudyFields.studyTime,
  );
}

StudyGoal _goal() {
  return StudyGoal(
    type: GoalType.weekly,
    targetMinutes: 120,
    languages: const [],
    periodStart: DateTime(2026, 5, 17),
  );
}

StudyEvent _event() {
  return StudyEvent(
    subject: 'Python',
    title: 'Study',
    date: DateTime(2026, 5, 19),
    startTime: const TimeOfDay(hour: 9, minute: 0),
    endTime: const TimeOfDay(hour: 10, minute: 0),
  );
}

class _HangingSeedingService extends StarterSubjectSeedingService {
  _HangingSeedingService({required StorageService storage})
    : super(storage: storage);

  @override
  Future<OnboardingState> seedIfNeeded(OnboardingState state) {
    return Completer<OnboardingState>().future;
  }
}

class _FakeAuthRepository extends AuthRepository {
  int logoutCalls = 0;
  int disconnectCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }
}
