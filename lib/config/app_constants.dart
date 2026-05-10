/// Global App Constants
/// Centralizes URLs, field names, and static configurations
class AppConstants {
  // ── App Information ──
  static const String appName = 'StudyHub';
  static const String appVersion = '1.0.0';

  // ── Notion API ──
  static const String notionBaseUrl = 'https://api.notion.com/v1';
  static const String notionPagesEndpoint = '$notionBaseUrl/pages';
  static const String notionDatabaseQueryEndpoint = '$notionBaseUrl/databases';
  static const String notionApiVersion = '2022-06-28';

  // Notion Database Field Names (must match exactly in Notion)
  static const String notionFieldSubject = 'Linguagem';
  static const String notionFieldStudyTime = 'Tempo de Estudo';
  static const String notionFieldDescription = 'Descrição';
  static const String notionFieldLearning = 'O que Aprendi';
  static const String notionFieldPriority = 'Prioridade de Revisão';
  static const String notionFieldStatus = 'Status';
  static const String notionFieldDate = 'Data';
  static const String notionFieldNotes = 'Observações';

  // ── Google Calendar ──
  static const String calendarId = 'primary'; // User's primary calendar
  static const String googleWebClientId =
      '539437186516-7a8kisrn4laf16d676uvalvgh0hdlp2o.apps.googleusercontent.com';

  // ── Secure Storage Keys ──
  static const String storageKeyNotionToken = 'notion_token';
  static const String storageKeyNotionDatabaseId = 'notion_database_id';
  static const String storageKeyGoogleEmail = 'google_email';
  static const String storageKeyGoogleName = 'google_user_name';
  static const String storageKeyGooglePhoto = 'google_user_photo';

  // ── Simple Preference Keys ──
  static const String prefKeyThemeMode = 'theme_mode';
  static const String prefKeyDefaultReminder = 'default_reminder_minutes';
  static const String prefKeyIsFirstLaunch = 'is_first_launch';

  // ── Reminder Options (in minutes) ──
  static const List<int> reminderOptions = [5, 10, 15, 30, 60];

  // ── Review Priority Options ──
  static const List<String> reviewPriorities = ['High', 'Medium', 'Low'];

  // ── Status Options ──
  static const List<String> statusOptions = [
    'Completed',
    'In Progress',
    'Pending',
  ];

  // ── Default Subjects/Languages (User can always type custom ones) ──
  static const List<String> defaultSubjects = [
    'Flutter',
    'Dart',
    'SQL',
    'Python',
    'JavaScript',
    'Java',
    'Kotlin',
    'Git',
    'Outros',
  ];
}
