import 'package:study_hub/services/storage_service.dart';

class OnboardingMigrationSnapshot {
  final bool hasLogs;
  final bool hasGoals;
  final bool hasEvents;
  final bool hasPersistedLocalSchema;
  final bool hasCustomCategories;
  final bool hasDeletedDefaultCategories;
  final bool hasNotionLinkedCategories;
  final bool hasNotionConfig;

  const OnboardingMigrationSnapshot({
    required this.hasLogs,
    required this.hasGoals,
    required this.hasEvents,
    required this.hasPersistedLocalSchema,
    required this.hasCustomCategories,
    required this.hasDeletedDefaultCategories,
    required this.hasNotionLinkedCategories,
    required this.hasNotionConfig,
  });

  bool get isLegacy =>
      hasLogs ||
      hasGoals ||
      hasEvents ||
      hasPersistedLocalSchema ||
      hasCustomCategories ||
      hasDeletedDefaultCategories ||
      hasNotionLinkedCategories ||
      hasNotionConfig;
}

class OnboardingMigrationService {
  final StorageService _storage;

  OnboardingMigrationService({StorageService? storage})
    : _storage = storage ?? StorageService();

  Future<OnboardingMigrationSnapshot> inspect() async {
    final notionToken = await _storage.getNotionToken();
    final notionDatabaseId = await _storage.getNotionDatabaseId();
    final notionSchema = await _storage.getNotionSchema();
    final notionCategoryField = await _storage.getNotionCategoryField();
    final notionAuthenticated = await _storage.getNotionAuthenticatedFlag();
    final linkCategoriesToNotion = await _storage.getLinkCategoriesToNotion();

    return OnboardingMigrationSnapshot(
      hasLogs: (await _storage.getStudyLogs()).isNotEmpty,
      hasGoals: (await _storage.getStudyGoals()).isNotEmpty,
      hasEvents: (await _storage.getStudyEvents()).isNotEmpty,
      hasPersistedLocalSchema: await _storage.hasPersistedLocalStudyFields(),
      hasCustomCategories: (await _storage.getCustomCategories()).isNotEmpty,
      hasDeletedDefaultCategories:
          (await _storage.getDeletedDefaultCategories()).isNotEmpty,
      hasNotionLinkedCategories:
          linkCategoriesToNotion ||
          (notionCategoryField != null && notionCategoryField.isNotEmpty),
      hasNotionConfig:
          notionAuthenticated ||
          (notionToken != null && notionToken.isNotEmpty) ||
          (notionDatabaseId != null && notionDatabaseId.isNotEmpty) ||
          (notionSchema != null && notionSchema.isNotEmpty),
    );
  }
}
