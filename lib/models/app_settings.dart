/// Modelo: Configurações do App
/// Armazena o estado das conexões e preferências do usuário
class AppSettings {
  final bool isGoogleConnected;
  final bool isNotionConnected;
  final String? notionDatabaseId;
  final String? googleEmail;
  final String? userName;
  final String? userPhotoUrl;
  final String themeMode; // "light", "dark", "system"
  final int defaultReminderMinutes;

  const AppSettings({
    this.isGoogleConnected = false,
    this.isNotionConnected = false,
    this.notionDatabaseId,
    this.googleEmail,
    this.userName,
    this.userPhotoUrl,
    this.themeMode = 'system',
    this.defaultReminderMinutes = 15,
  });

  /// Cria uma cópia com campos alterados
  AppSettings copyWith({
    bool? isGoogleConnected,
    bool? isNotionConnected,
    String? notionDatabaseId,
    String? googleEmail,
    String? userName,
    String? userPhotoUrl,
    String? themeMode,
    int? defaultReminderMinutes,
  }) {
    return AppSettings(
      isGoogleConnected: isGoogleConnected ?? this.isGoogleConnected,
      isNotionConnected: isNotionConnected ?? this.isNotionConnected,
      notionDatabaseId: notionDatabaseId ?? this.notionDatabaseId,
      googleEmail: googleEmail ?? this.googleEmail,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      themeMode: themeMode ?? this.themeMode,
      defaultReminderMinutes:
          defaultReminderMinutes ?? this.defaultReminderMinutes,
    );
  }
}
