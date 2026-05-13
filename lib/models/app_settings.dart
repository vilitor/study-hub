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
    bool clearNotionDatabaseId = false,
    bool clearNotionCategoryField = false,
  }) {
    return AppSettings(
      isGoogleConnected: isGoogleConnected ?? this.isGoogleConnected,
      isNotionAuthenticated:
          isNotionAuthenticated ?? this.isNotionAuthenticated,
      isNotionConnected: isNotionConnected ?? this.isNotionConnected,
      notionDatabaseId: clearNotionDatabaseId
          ? null
          : notionDatabaseId ?? this.notionDatabaseId,
      googleEmail: googleEmail ?? this.googleEmail,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
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
    );
  }
}
