/// Modelo: Configurações do App
/// Armazena o estado das conexões e preferências do usuário
enum RegisterFieldSource { local, notion }

class AppSettings {
  final bool isGoogleConnected;
  final bool isNotionAuthenticated;
  final bool isNotionConnected;
  final String? notionDatabaseId;
  final String? googleEmail;
  final String? userName;
  final String? userPhotoUrl;
  final String themeMode; // "light", "dark", "system"
  final int defaultReminderMinutes;
  final String? notionTimeField; // Mapping for study time field
  final String? localTimeField;
  final List<String> customCategories;
  final List<String> deletedDefaultCategories;
  final bool linkCategoriesToNotion;
  final String? notionCategoryField;
  final RegisterFieldSource registerFieldSource;
  final bool onboardingCompleted;
  final int onboardingVersion;
  final bool profilePersonalizationCompleted;
  final bool starterSubjectsSeeded;
  final bool legacyMigrationCompleted;
  final bool contextualGuideCompleted;
  final String? selectedStudyProfileId;
  final String? selectedStudyProfileLabel;
  final String? selectedStudyFocusId;
  final String? selectedStudyFocusLabel;
  final bool lumaPersonalizationEnabled;

  const AppSettings({
    this.isGoogleConnected = false,
    this.isNotionAuthenticated = false,
    this.isNotionConnected = false,
    this.notionDatabaseId,
    this.googleEmail,
    this.userName,
    this.userPhotoUrl,
    this.themeMode = 'light',
    this.defaultReminderMinutes = 15,
    this.notionTimeField,
    this.localTimeField,
    this.customCategories = const [],
    this.deletedDefaultCategories = const [],
    this.linkCategoriesToNotion = false,
    this.notionCategoryField,
    this.registerFieldSource = RegisterFieldSource.local,
    this.onboardingCompleted = false,
    this.onboardingVersion = 0,
    this.profilePersonalizationCompleted = false,
    this.starterSubjectsSeeded = false,
    this.legacyMigrationCompleted = false,
    this.contextualGuideCompleted = false,
    this.selectedStudyProfileId,
    this.selectedStudyProfileLabel,
    this.selectedStudyFocusId,
    this.selectedStudyFocusLabel,
    this.lumaPersonalizationEnabled = true,
  });

  Map<String, dynamic> toCloudMap() {
    return {
      'notionDatabaseId': notionDatabaseId,
      'themeMode': themeMode,
      'defaultReminderMinutes': defaultReminderMinutes,
      'notionTimeField': notionTimeField,
      'localTimeField': localTimeField,
      'customCategories': customCategories,
      'deletedDefaultCategories': deletedDefaultCategories,
      'linkCategoriesToNotion': linkCategoriesToNotion,
      'notionCategoryField': notionCategoryField,
      'registerFieldSource': registerFieldSource.name,
      'onboardingCompleted': onboardingCompleted,
      'onboardingVersion': onboardingVersion,
      'profilePersonalizationCompleted': profilePersonalizationCompleted,
      'starterSubjectsSeeded': starterSubjectsSeeded,
      'legacyMigrationCompleted': legacyMigrationCompleted,
      'contextualGuideCompleted': contextualGuideCompleted,
      'selectedStudyProfileId': selectedStudyProfileId,
      'selectedStudyProfileLabel': selectedStudyProfileLabel,
      'selectedStudyFocusId': selectedStudyFocusId,
      'selectedStudyFocusLabel': selectedStudyFocusLabel,
      'lumaPersonalizationEnabled': lumaPersonalizationEnabled,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory AppSettings.fromCloudMap(Map<String, dynamic> map) {
    return AppSettings(
      notionDatabaseId: map['notionDatabaseId']?.toString(),
      themeMode: map['themeMode']?.toString() ?? 'light',
      defaultReminderMinutes:
          (map['defaultReminderMinutes'] as num?)?.toInt() ?? 15,
      notionTimeField: map['notionTimeField']?.toString(),
      localTimeField: map['localTimeField']?.toString(),
      customCategories: List<String>.from(
        map['customCategories'] as List? ?? const [],
      ),
      deletedDefaultCategories: List<String>.from(
        map['deletedDefaultCategories'] as List? ?? const [],
      ),
      linkCategoriesToNotion: map['linkCategoriesToNotion'] as bool? ?? false,
      notionCategoryField: map['notionCategoryField']?.toString(),
      registerFieldSource: RegisterFieldSource.values.firstWhere(
        (source) => source.name == map['registerFieldSource'],
        orElse: () => RegisterFieldSource.local,
      ),
      onboardingCompleted: map['onboardingCompleted'] as bool? ?? false,
      onboardingVersion: (map['onboardingVersion'] as num?)?.toInt() ?? 0,
      profilePersonalizationCompleted:
          map['profilePersonalizationCompleted'] as bool? ?? false,
      starterSubjectsSeeded: map['starterSubjectsSeeded'] as bool? ?? false,
      legacyMigrationCompleted:
          map['legacyMigrationCompleted'] as bool? ?? false,
      contextualGuideCompleted:
          map['contextualGuideCompleted'] as bool? ?? false,
      selectedStudyProfileId: map['selectedStudyProfileId']?.toString(),
      selectedStudyProfileLabel: map['selectedStudyProfileLabel']?.toString(),
      selectedStudyFocusId: map['selectedStudyFocusId']?.toString(),
      selectedStudyFocusLabel: map['selectedStudyFocusLabel']?.toString(),
      lumaPersonalizationEnabled:
          map['lumaPersonalizationEnabled'] as bool? ?? true,
    );
  }

  /// Cria uma cópia com campos alterados
  AppSettings copyWith({
    bool? isGoogleConnected,
    bool? isNotionAuthenticated,
    bool? isNotionConnected,
    String? notionDatabaseId,
    String? googleEmail,
    String? userName,
    String? userPhotoUrl,
    String? themeMode,
    int? defaultReminderMinutes,
    String? notionTimeField,
    String? localTimeField,
    List<String>? customCategories,
    List<String>? deletedDefaultCategories,
    bool? linkCategoriesToNotion,
    String? notionCategoryField,
    RegisterFieldSource? registerFieldSource,
    bool? onboardingCompleted,
    int? onboardingVersion,
    bool? profilePersonalizationCompleted,
    bool? starterSubjectsSeeded,
    bool? legacyMigrationCompleted,
    bool? contextualGuideCompleted,
    String? selectedStudyProfileId,
    String? selectedStudyProfileLabel,
    String? selectedStudyFocusId,
    String? selectedStudyFocusLabel,
    bool? lumaPersonalizationEnabled,
    bool clearNotionDatabaseId = false,
    bool clearNotionCategoryField = false,
    bool clearGoogleProfile = false,
    bool clearGoogleName = false,
    bool clearGooglePhotoUrl = false,
    bool clearStudyFocus = false,
  }) {
    return AppSettings(
      isGoogleConnected: isGoogleConnected ?? this.isGoogleConnected,
      isNotionAuthenticated:
          isNotionAuthenticated ?? this.isNotionAuthenticated,
      isNotionConnected: isNotionConnected ?? this.isNotionConnected,
      notionDatabaseId: clearNotionDatabaseId
          ? null
          : notionDatabaseId ?? this.notionDatabaseId,
      googleEmail: clearGoogleProfile ? null : googleEmail ?? this.googleEmail,
      userName: clearGoogleProfile || clearGoogleName
          ? null
          : userName ?? this.userName,
      userPhotoUrl: clearGoogleProfile
          ? null
          : clearGooglePhotoUrl
          ? null
          : userPhotoUrl ?? this.userPhotoUrl,
      themeMode: themeMode ?? this.themeMode,
      defaultReminderMinutes:
          defaultReminderMinutes ?? this.defaultReminderMinutes,
      notionTimeField: notionTimeField ?? this.notionTimeField,
      localTimeField: localTimeField ?? this.localTimeField,
      customCategories: customCategories ?? this.customCategories,
      deletedDefaultCategories:
          deletedDefaultCategories ?? this.deletedDefaultCategories,
      linkCategoriesToNotion:
          linkCategoriesToNotion ?? this.linkCategoriesToNotion,
      notionCategoryField: clearNotionCategoryField
          ? null
          : notionCategoryField ?? this.notionCategoryField,
      registerFieldSource: registerFieldSource ?? this.registerFieldSource,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingVersion: onboardingVersion ?? this.onboardingVersion,
      profilePersonalizationCompleted:
          profilePersonalizationCompleted ??
          this.profilePersonalizationCompleted,
      starterSubjectsSeeded:
          starterSubjectsSeeded ?? this.starterSubjectsSeeded,
      legacyMigrationCompleted:
          legacyMigrationCompleted ?? this.legacyMigrationCompleted,
      contextualGuideCompleted:
          contextualGuideCompleted ?? this.contextualGuideCompleted,
      selectedStudyProfileId:
          selectedStudyProfileId ?? this.selectedStudyProfileId,
      selectedStudyProfileLabel:
          selectedStudyProfileLabel ?? this.selectedStudyProfileLabel,
      selectedStudyFocusId: clearStudyFocus
          ? null
          : selectedStudyFocusId ?? this.selectedStudyFocusId,
      selectedStudyFocusLabel: clearStudyFocus
          ? null
          : selectedStudyFocusLabel ?? this.selectedStudyFocusLabel,
      lumaPersonalizationEnabled:
          lumaPersonalizationEnabled ?? this.lumaPersonalizationEnabled,
    );
  }
}
