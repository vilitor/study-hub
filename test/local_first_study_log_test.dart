import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/app_settings.dart';
import 'package:study_hub/models/local_study_field.dart';
import 'package:study_hub/models/notion_schema.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/providers/auth_session_provider.dart';
import 'package:study_hub/providers/certificate_provider.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/providers/local_study_schema_provider.dart';
import 'package:study_hub/providers/navigation_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/providers/study_timer_provider.dart';
import 'package:study_hub/screens/home/home_screen.dart';
import 'package:study_hub/screens/home/create_goal_sheet.dart';
import 'package:study_hub/screens/settings/settings_screen.dart';
import 'package:study_hub/screens/study_log/study_log_screen.dart';
import 'package:study_hub/services/local_study_schema_service.dart';
import 'package:study_hub/services/storage_service.dart';
import 'package:study_hub/widgets/dynamic_form_builder.dart';
import 'package:study_hub/widgets/notion_connection_sheet.dart';

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

  test('Local schema provider initializes default fields', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = LocalStudySchemaProvider();
    await provider.loadFields();

    expect(provider.activeFields, isNotEmpty);
    expect(
      provider.activeFields.any(
        (field) => field.label == LocalStudyFields.title,
      ),
      isTrue,
    );
    expect(
      provider.activeFields.any(
        (field) => field.label == LocalStudyFields.studyTime,
      ),
      isTrue,
    );
  });

  test('Local schema provider adds edits and archives fields safely', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = LocalStudySchemaProvider();
    await provider.loadFields();

    final field = LocalStudyField(
      label: 'Dificuldade',
      type: LocalStudyFieldType.select,
      options: const ['Baixa', 'Media', 'Alta'],
    );

    expect(await provider.addField(field), isTrue);
    final added = provider.activeFields.firstWhere(
      (item) => item.label == 'Dificuldade',
    );
    expect(await provider.updateField(added.copyWith(label: 'Nivel')), isTrue);
    expect(provider.activeFields.any((item) => item.label == 'Nivel'), isTrue);
    expect(
      await provider.archiveField(
        id: added.id,
        protectedTimeField: LocalStudyFields.studyTime,
      ),
      isTrue,
    );
    expect(provider.activeFields.any((item) => item.id == added.id), isFalse);
  });

  test('Local schema provider protects selected study time field', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = LocalStudySchemaProvider();
    await provider.loadFields();
    final time = provider.activeFields.firstWhere(
      (field) => field.label == LocalStudyFields.studyTime,
    );

    expect(
      await provider.archiveField(
        id: time.id,
        protectedTimeField: LocalStudyFields.studyTime,
      ),
      isFalse,
    );
    expect(provider.activeFields.any((field) => field.id == time.id), isTrue);
  });

  test('Local schema creates a valid local study log', () {
    final schema = LocalStudySchemaService.defaultSchema(
      categories: const ['Flutter'],
    );
    final log = StudyLog(
      rawValues: const {
        LocalStudyFields.title: 'Local first',
        LocalStudyFields.subject: 'Flutter',
        LocalStudyFields.category: 'Flutter',
        LocalStudyFields.studyTime: 35,
        LocalStudyFields.notes: 'Resumo',
      },
      schema: schema,
      studyTimeField: LocalStudyFields.studyTime,
    );

    expect(log.source, StudyLogSource.local);
    expect(log.syncedWithNotion, isFalse);
    expect(log.studyTimeMinutes, 35);
  });

  test('StudyLog.fromMap remains compatible with legacy payloads', () {
    final legacySchema = NotionDatabaseSchema(
      properties: {
        'Name': NotionProperty(id: 'name', name: 'Name', type: 'title'),
        'Minutes': NotionProperty(
          id: 'minutes',
          name: 'Minutes',
          type: 'number',
        ),
      },
    );

    final restored = StudyLog.fromMap({
      'id': 'legacy-log',
      'rawValues': {'Name': 'Legacy', 'Minutes': 20},
      'syncedWithNotion': true,
      'schema': legacySchema.toJson(),
      'date': DateTime(2026, 5, 7).toIso8601String(),
    });

    expect(restored.source, StudyLogSource.notion);
    expect(restored.studyTimeField, isNull);
    expect(restored.studyTimeMinutes, 20);
  });

  test('StudyLog rawValues are JSON-safe for local date fields', () {
    final schema = LocalStudySchemaService.defaultSchema();
    final log = StudyLog(
      rawValues: {
        LocalStudyFields.title: 'Com data',
        LocalStudyFields.studyTime: 25,
        LocalStudyFields.date: DateTime(2026, 5, 7),
      },
      schema: schema,
      studyTimeField: LocalStudyFields.studyTime,
    );

    final restored = StudyLog.fromMap(log.toMap());

    expect(
      restored.rawValues[LocalStudyFields.date],
      '2026-05-07T00:00:00.000',
    );
    expect(restored.studyTimeMinutes, 25);
  });

  test('Local to Notion mapping preserves core values', () {
    final notionSchema = NotionDatabaseSchema(
      properties: {
        'Titulo': NotionProperty(id: 'title', name: 'Titulo', type: 'title'),
        'Tempo': NotionProperty(id: 'time', name: 'Tempo', type: 'number'),
        'Notas': NotionProperty(id: 'notes', name: 'Notas', type: 'rich_text'),
      },
    );

    final mapped = LocalStudySchemaService.mapToNotionRawValues(
      localValues: const {
        LocalStudyFields.title: 'Aula 1',
        LocalStudyFields.studyTime: 42,
        LocalStudyFields.notes: 'Notas locais',
      },
      notionSchema: notionSchema,
      notionTimeField: 'Tempo',
    );

    expect(mapped['Titulo'], 'Aula 1');
    expect(mapped['Tempo'], 42);
    expect(mapped['Notas'], 'Notas locais');
  });

  test('Settings persists and loads register field source', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService().saveRegisterFieldSource(RegisterFieldSource.notion);
    final settings = SettingsProvider();

    await settings.loadSettings();

    expect(settings.settings.registerFieldSource, RegisterFieldSource.notion);
  });

  test(
    'First connected Notion session defaults register source to notion',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await settings.saveNotionCredentials('secret-token', 'database-id');

      expect(settings.settings.registerFieldSource, RegisterFieldSource.notion);
    },
  );

  testWidgets('Register screen renders local form without Notion', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocalStudySchemaProvider()),
          ChangeNotifierProvider(create: (_) => StudyLogProvider()),
          ChangeNotifierProvider(create: (_) => StudyTimerProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          routes: {'/history': (_) => const Scaffold(body: Text('History'))},
          home: const StudyLogScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tabela local'), findsOneWidget);
    expect(find.text('Local Table'), findsOneWidget);
    expect(find.text('Notion Sync'), findsOneWidget);
    expect(find.text('Titulo'), findsOneWidget);
    expect(find.text('Tempo de estudo'), findsOneWidget);
    expect(find.text('Salvar registro'), findsOneWidget);
  });

  testWidgets('Register local save shows success and updates logs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final logs = StudyLogProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocalStudySchemaProvider()),
          ChangeNotifierProvider.value(value: logs),
          ChangeNotifierProvider(create: (_) => StudyTimerProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          routes: {'/history': (_) => const Scaffold(body: Text('History'))},
          home: const StudyLogScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Aula local');
    await tester.ensureVisible(find.text('Salvar registro'));
    await tester.tap(find.text('Salvar registro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Registro concluido'), findsOneWidget);
    expect(logs.logs, hasLength(1));
  });

  testWidgets('Register shows Notion fields when notion source is active', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.saveNotionToken('secret-token');
    await storage.saveNotionDatabaseId('db-123');
    await storage.saveNotionSchema(
      '{"properties":{"Titulo":{"id":"title","type":"title"},"Tempo":{"id":"time","type":"number"},"Notas":{"id":"notes","type":"rich_text"}}}',
    );
    await storage.saveRegisterFieldSource(RegisterFieldSource.notion);
    final settings = SettingsProvider();
    final logs = StudyLogProvider();
    await settings.loadSettings();
    await logs.loadSchemaFromCache();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocalStudySchemaProvider()),
          ChangeNotifierProvider.value(value: logs),
          ChangeNotifierProvider(create: (_) => StudyTimerProvider()),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          routes: {'/history': (_) => const Scaffold(body: Text('History'))},
          home: const StudyLogScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Campos do Notion'), findsOneWidget);
    expect(find.byType(DynamicFormBuilder), findsNWidgets(3));
    expect(find.byTooltip('Notas de estudo'), findsOneWidget);
  });

  testWidgets('Register stores notes while using Notion Sync source', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.saveNotionToken('secret-token');
    await storage.saveNotionDatabaseId('db-123');
    await storage.saveNotionSchema(
      '{"properties":{"Titulo":{"id":"title","type":"title"},"Tempo":{"id":"time","type":"number"}}}',
    );
    await storage.saveRegisterFieldSource(RegisterFieldSource.notion);
    final settings = SettingsProvider();
    final logs = StudyLogProvider();
    await settings.loadSettings();
    await logs.loadSchemaFromCache();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocalStudySchemaProvider()),
          ChangeNotifierProvider.value(value: logs),
          ChangeNotifierProvider(create: (_) => StudyTimerProvider()),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          routes: {'/history': (_) => const Scaffold(body: Text('History'))},
          home: const StudyLogScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await StorageService().saveNotionToken('');

    await tester.tap(find.byTooltip('Notas de estudo'));
    await tester.pumpAndSettle();
    expect(find.text('Notas de estudo'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, 'Resumo Notion');
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Salvar registro'));
    await tester.tap(find.text('Salvar registro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(logs.logs, hasLength(1));
    expect(logs.logs.single.source, StudyLogSource.notion);
    expect(logs.logs.single.localNote?.summary, 'Resumo Notion');
  });

  testWidgets('Notion select field updates selected value immediately', (
    tester,
  ) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return DynamicFormBuilder(
                property: NotionProperty(
                  id: 'notion-status',
                  name: 'Status',
                  type: 'select',
                  options: const ['Planejado', 'Concluido'],
                ),
                initialValue: selected,
                onChanged: (value) => setState(() => selected = value),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluido').last);
    await tester.pumpAndSettle();

    expect(selected, 'Concluido');
    expect(find.text('Concluido'), findsOneWidget);
  });

  testWidgets('Notion multi-select field updates selected count immediately', (
    tester,
  ) async {
    List<String> selected = const [];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return DynamicFormBuilder(
                property: NotionProperty(
                  id: 'notion-tags',
                  name: 'Tags',
                  type: 'multi_select',
                  options: const ['Flutter', 'Android'],
                ),
                initialValue: selected,
                onChanged: (value) =>
                    setState(() => selected = List<String>.from(value)),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('0 selecionado(s)'), findsOneWidget);

    await tester.tap(find.text('Flutter'));
    await tester.pumpAndSettle();

    expect(selected, const ['Flutter']);
    expect(find.text('1 selecionado(s)'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('Register source switch keeps local and Notion drafts separate', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.saveNotionToken('secret-token');
    await storage.saveNotionDatabaseId('db-123');
    await storage.saveNotionSchema(
      '{"properties":{"Titulo":{"id":"title","type":"title"},"Categoria":{"id":"notion-category","type":"select","select":{"options":[{"name":"Notion"}]}},"Tempo":{"id":"time","type":"number"}}}',
    );
    await storage.saveRegisterFieldSource(RegisterFieldSource.local);
    final settings = SettingsProvider();
    final logs = StudyLogProvider();
    await settings.loadSettings();
    await logs.loadSchemaFromCache();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocalStudySchemaProvider()),
          ChangeNotifierProvider.value(value: logs),
          ChangeNotifierProvider(create: (_) => StudyTimerProvider()),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          routes: {'/history': (_) => const Scaffold(body: Text('History'))},
          home: const StudyLogScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final localCategoryField = find.byKey(
      const ValueKey('local-select-local_category'),
    );
    await tester.ensureVisible(localCategoryField);
    await tester.pumpAndSettle();
    await tester.tap(localCategoryField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter').last);
    await tester.pumpAndSettle();
    expect(find.text('Flutter'), findsWidgets);

    await tester.ensureVisible(find.text('Notion Sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notion Sync'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Campos do Notion'), findsOneWidget);
    expect(find.text('Flutter'), findsNothing);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notion').last);
    await tester.pump();

    expect(find.text('Notion'), findsWidgets);

    await tester.ensureVisible(find.text('Local Table'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Local Table'));
    await tester.pump();

    expect(find.text('Tabela local'), findsOneWidget);
    expect(find.text('Flutter'), findsWidgets);
  });

  testWidgets('Notion sheet opens empty credential fields when disconnected', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => StudyLogProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: NotionConnectionSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Token de integração'), findsOneWidget);
    expect(find.text('Database ID'), findsOneWidget);
    expect(find.text('Salvar e sincronizar tabela'), findsOneWidget);
    expect(find.text('Testar conexão'), findsOneWidget);
    expect(
      find.textContaining('Não foi possível carregar credenciais salvas'),
      findsNothing,
    );
    expect(
      find.textContaining('Informe o token da integração'),
      findsOneWidget,
    );
  });

  testWidgets('Home achievements empty state hides progress bar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => NavigationProvider()),
          ChangeNotifierProvider(create: (_) => StudyEventProvider()),
          ChangeNotifierProvider(create: (_) => CertificateProvider()),
          ChangeNotifierProvider(create: (_) => StudyLogProvider()),
          ChangeNotifierProvider(create: (_) => GoalProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          routes: {
            '/achievements': (_) => const Scaffold(body: Text('Achievements')),
          },
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Complete seu primeiro registro e comece a construir sua jornada.',
      ),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('link(s) confiaveis'), findsNothing);
  });

  testWidgets('Home avatar prefers reactive auth photo over stored settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.syncGoogleProfileFromAuth(
      email: 'old@example.com',
      name: 'Old User',
      photoUrl: 'https://example.com/old-avatar.png',
    );
    final auth = AuthSessionProvider(autoLoad: false)
      ..debugSetSignedInProfile(
        uid: 'uid-1',
        email: 'new@example.com',
        displayName: 'New User',
        photoUrl: 'https://example.com/new-avatar.png',
      );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => NavigationProvider()),
          ChangeNotifierProvider(create: (_) => StudyEventProvider()),
          ChangeNotifierProvider(create: (_) => CertificateProvider()),
          ChangeNotifierProvider(create: (_) => StudyLogProvider()),
          ChangeNotifierProvider(create: (_) => GoalProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          routes: {
            '/achievements': (_) => const Scaffold(body: Text('Achievements')),
          },
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('New'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('home-avatar-image-https://example.com/new-avatar.png'),
      ),
      findsOneWidget,
    );
    expect(find.text('Old'), findsNothing);
  });

  testWidgets('Home avatar falls back after auth sign-out', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.syncGoogleProfileFromAuth(
      email: 'old@example.com',
      name: 'Old User',
      photoUrl: 'https://example.com/old-avatar.png',
    );
    final auth = AuthSessionProvider(autoLoad: false)..debugSetSignedOut();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => NavigationProvider()),
          ChangeNotifierProvider(create: (_) => StudyEventProvider()),
          ChangeNotifierProvider(create: (_) => CertificateProvider()),
          ChangeNotifierProvider(create: (_) => StudyLogProvider()),
          ChangeNotifierProvider(create: (_) => GoalProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          routes: {
            '/achievements': (_) => const Scaffold(body: Text('Achievements')),
          },
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Estudante'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('home-avatar-image-https://example.com/old-avatar.png'),
      ),
      findsNothing,
    );
  });

  testWidgets('New goal sheet shows tutorial once and persists completion', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => GoalProvider()),
          ChangeNotifierProvider(create: (_) => StudyLogProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: CreateGoalSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Como as matérias da meta funcionam'), findsOneWidget);
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();

    expect(find.text('Como as matérias da meta funcionam'), findsNothing);
    expect(await StorageService().hasSeenGoalTutorial(), isTrue);
  });

  testWidgets(
    'Settings shows integration buttons instead of inline Notion fields',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => LocalStudySchemaProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            routes: {'/history': (_) => const Scaffold(body: Text('History'))},
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Google Calendar'), findsOneWidget);
      expect(find.text('Notion'), findsOneWidget);
      expect(find.text('Tabela local'), findsOneWidget);
      expect(find.byType(SvgPicture), findsNWidgets(2));
      expect(find.text('Token de integração'), findsNothing);
      expect(find.text('Database ID'), findsNothing);
      expect(find.text('Histórico de registros'), findsOneWidget);
    },
  );
}
