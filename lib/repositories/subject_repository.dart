import 'package:study_hub/config/app_constants.dart';
import 'package:study_hub/models/app_settings.dart';
import 'package:study_hub/models/notion_schema.dart';

class SubjectRepository {
  const SubjectRepository();

  List<String> getSubjects({
    required AppSettings settings,
    required NotionDatabaseSchema? schema,
  }) {
    final notionSubjects = _subjectsFromConfiguredNotionField(
      settings: settings,
      schema: schema,
    );

    if (notionSubjects.isNotEmpty) {
      return notionSubjects;
    }

    final defaultSubjects = AppConstants.defaultSubjects.where(
      (subject) => !settings.deletedDefaultCategories.contains(subject),
    );

    return {...defaultSubjects, ...settings.customCategories}.toList()..sort();
  }

  bool isUsingNotionSubjects({
    required AppSettings settings,
    required NotionDatabaseSchema? schema,
  }) {
    return _subjectsFromConfiguredNotionField(
      settings: settings,
      schema: schema,
    ).isNotEmpty;
  }

  List<String> getSelectableSubjectFields(NotionDatabaseSchema? schema) {
    if (schema == null) return const [];
    return schema.properties.entries
        .where(
          (entry) =>
              entry.value.type == 'select' ||
              entry.value.type == 'multi_select',
        )
        .map((entry) => entry.value.name)
        .toList();
  }

  List<String> _subjectsFromConfiguredNotionField({
    required AppSettings settings,
    required NotionDatabaseSchema? schema,
  }) {
    if (!settings.isNotionConnected ||
        settings.notionDatabaseId == null ||
        settings.notionDatabaseId!.isEmpty ||
        !settings.linkCategoriesToNotion ||
        settings.notionCategoryField == null ||
        schema == null) {
      return const [];
    }

    final property = schema.properties[settings.notionCategoryField];
    final options = property?.options ?? const <String>[];
    return options.toSet().toList()..sort();
  }
}
