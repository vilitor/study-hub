import 'package:study_hub/models/notion_schema.dart';
import 'package:study_hub/models/local_study_field.dart';

class LocalStudyFields {
  static const title = 'Titulo';
  static const subject = 'Assunto';
  static const category = 'Categoria';
  static const studyTime = 'Tempo de estudo';
  static const date = 'Data';
  static const notes = 'Notas';
}

class LocalStudySchemaService {
  const LocalStudySchemaService._();

  static const defaultStudyTimeField = LocalStudyFields.studyTime;
  static const fallbackCategoryOptions = [
    'Geral',
    'Flutter',
    'Matematica',
    'Leitura',
  ];

  static List<LocalStudyField> defaultFields({
    List<String> categories = const [],
    bool useFallbackCategories = true,
  }) {
    final categoryOptions = categories.isEmpty
        ? (useFallbackCategories ? fallbackCategoryOptions : const <String>[])
        : categories;
    return [
      LocalStudyField(
        id: 'local_title',
        label: LocalStudyFields.title,
        type: LocalStudyFieldType.text,
        isRequired: true,
        isDefault: true,
      ),
      LocalStudyField(
        id: 'local_subject',
        label: LocalStudyFields.subject,
        type: LocalStudyFieldType.text,
        isDefault: true,
      ),
      LocalStudyField(
        id: 'local_category',
        label: LocalStudyFields.category,
        type: LocalStudyFieldType.select,
        options: categoryOptions,
        isDefault: true,
      ),
      LocalStudyField(
        id: 'local_study_time',
        label: LocalStudyFields.studyTime,
        type: LocalStudyFieldType.number,
        isDefault: true,
      ),
      LocalStudyField(
        id: 'local_date',
        label: LocalStudyFields.date,
        type: LocalStudyFieldType.date,
        isDefault: true,
      ),
      LocalStudyField(
        id: 'local_notes',
        label: LocalStudyFields.notes,
        type: LocalStudyFieldType.longText,
        isDefault: true,
      ),
    ];
  }

  static NotionDatabaseSchema defaultSchema({
    List<String> categories = const [],
    bool useFallbackCategories = true,
  }) {
    return schemaFromFields(
      defaultFields(
        categories: categories,
        useFallbackCategories: useFallbackCategories,
      ),
    );
  }

  static NotionDatabaseSchema schemaFromFields(List<LocalStudyField> fields) {
    return NotionDatabaseSchema(
      properties: {
        for (final field in fields.where((field) => !field.isArchived))
          field.label: NotionProperty(
            id: field.id,
            name: field.label,
            type: field.id == 'local_title' ? 'title' : field.type.notionType,
            options: field.options,
          ),
      },
    );
  }

  static Map<String, dynamic> mapToNotionRawValues({
    required Map<String, dynamic> localValues,
    required NotionDatabaseSchema notionSchema,
    required String? notionTimeField,
  }) {
    final mapped = <String, dynamic>{};
    final title = _string(localValues[LocalStudyFields.title]).isNotEmpty
        ? _string(localValues[LocalStudyFields.title])
        : _firstString(localValues);
    final subject = _string(localValues[LocalStudyFields.subject]);
    final category = _string(localValues[LocalStudyFields.category]);
    final notes = _string(localValues[LocalStudyFields.notes]).isNotEmpty
        ? _string(localValues[LocalStudyFields.notes])
        : _lastString(localValues);
    final minutes =
        localValues[LocalStudyFields.studyTime] ?? _firstNumber(localValues);
    var firstNumberUsed = false;
    var firstRichTextUsed = false;

    for (final entry in notionSchema.properties.entries) {
      final field = entry.value.name;
      final normalized = _normalize(field);
      switch (entry.value.type) {
        case 'title':
          mapped[field] = title.isNotEmpty ? title : subject;
          break;
        case 'rich_text':
          if (_containsAny(normalized, const ['nota', 'note', 'resumo'])) {
            mapped[field] = notes;
          } else if (!firstRichTextUsed) {
            mapped[field] = subject.isNotEmpty ? subject : notes;
            firstRichTextUsed = true;
          }
          break;
        case 'number':
          if (field == notionTimeField || !firstNumberUsed) {
            mapped[field] = minutes;
            firstNumberUsed = true;
          }
          break;
        case 'select':
          if (_containsAny(normalized, const ['categoria', 'category'])) {
            mapped[field] = category;
          } else if (_containsAny(normalized, const ['assunto', 'materia'])) {
            mapped[field] = subject;
          }
          break;
        case 'multi_select':
          if (_containsAny(normalized, const ['categoria', 'tag'])) {
            mapped[field] = category.isEmpty ? <String>[] : <String>[category];
          }
          break;
        case 'date':
          mapped[field] = DateTime.now();
          break;
      }
    }

    return mapped..removeWhere((_, value) => _isEmptyValue(value));
  }

  static bool _isEmptyValue(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable) return value.isEmpty;
    return false;
  }

  static bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static String _firstString(Map<String, dynamic> values) {
    for (final value in values.values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static String _lastString(Map<String, dynamic> values) {
    for (final value in values.values.toList().reversed) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static num _firstNumber(Map<String, dynamic> values) {
    for (final value in values.values) {
      if (value is num) return value;
    }
    return 0;
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
  }
}
