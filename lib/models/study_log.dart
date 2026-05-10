import 'package:uuid/uuid.dart';
import 'package:study_hub/models/cloud_sync.dart';
import 'package:study_hub/models/notion_schema.dart';

enum StudyLogSource { local, notion }

class StudyLogNote {
  final String subject;
  final String contentName;
  final String summary;

  const StudyLogNote({
    required this.subject,
    required this.contentName,
    required this.summary,
  });

  bool get isEmpty =>
      subject.trim().isEmpty &&
      contentName.trim().isEmpty &&
      summary.trim().isEmpty;

  bool get isNotEmpty => !isEmpty;

  Map<String, dynamic> toMap() {
    return {'subject': subject, 'contentName': contentName, 'summary': summary};
  }

  factory StudyLogNote.fromMap(Map<String, dynamic> map) {
    return StudyLogNote(
      subject: map['subject']?.toString() ?? '',
      contentName: map['contentName']?.toString() ?? '',
      summary: map['summary']?.toString() ?? '',
    );
  }
}

/// Uma entrada de log dinâmica, suportando mapeamento N-para-N de campos
class StudyLog {
  final String id;
  // Guarda temporariamente os valores antes de subir para nuvem (Chave = Nome da Propriedade, Valor = dynamic)
  final Map<String, dynamic> rawValues;
  final bool syncedWithNotion;
  final String? notionPageId; // Notion page ID for deletion sync
  final NotionDatabaseSchema schema;
  final DateTime date;
  final StudyLogNote? localNote;
  final StudyLogSource source;
  final String? studyTimeField;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final CloudSyncStatus syncStatus;
  final String? remoteId;
  final DateTime? lastSyncedAt;

  StudyLog({
    String? id,
    required this.rawValues,
    required this.schema,
    this.syncedWithNotion = false,
    this.notionPageId,
    DateTime? date,
    this.localNote,
    this.source = StudyLogSource.local,
    this.studyTimeField,
    DateTime? updatedAt,
    this.deletedAt,
    this.syncStatus = CloudSyncStatus.localOnly,
    this.remoteId,
    this.lastSyncedAt,
  }) : id = id ?? const Uuid().v4(),
       date = date ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  StudyLog copyWith({
    Map<String, dynamic>? rawValues,
    bool? syncedWithNotion,
    String? notionPageId,
    NotionDatabaseSchema? schema,
    DateTime? date,
    StudyLogNote? localNote,
    StudyLogSource? source,
    String? studyTimeField,
    bool clearStudyTimeField = false,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    CloudSyncStatus? syncStatus,
    String? remoteId,
    bool clearRemoteId = false,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
  }) {
    return StudyLog(
      id: id,
      rawValues: rawValues ?? this.rawValues,
      syncedWithNotion: syncedWithNotion ?? this.syncedWithNotion,
      notionPageId: notionPageId ?? this.notionPageId,
      schema: schema ?? this.schema,
      date: date ?? this.date,
      localNote: localNote ?? this.localNote,
      source: source ?? this.source,
      studyTimeField: clearStudyTimeField
          ? null
          : studyTimeField ?? this.studyTimeField,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      remoteId: clearRemoteId ? null : remoteId ?? this.remoteId,
      lastSyncedAt: clearLastSyncedAt
          ? null
          : lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  int get studyTimeMinutes {
    final configuredField = studyTimeField;
    if (configuredField != null && configuredField.isNotEmpty) {
      final value = rawValues[configuredField];
      final parsed = _intValue(value);
      if (parsed > 0) return parsed;
    }

    int total = 0;
    schema.properties.forEach((propName, notionProp) {
      if (notionProp.type == 'number') {
        total += _intValue(rawValues[propName]);
      }
    });
    return total;
  }

  /// Constrói inteligentemente o JSON estrito que a API do Notion espera iterando o Cache visual
  Map<String, dynamic> toNotionPayload(String databaseId) {
    final propertiesPayload = <String, dynamic>{};

    // Para cada coluna (property) no schema, puxamos o valor digitado pelo User (rawValues) e formatamos.
    schema.properties.forEach((propName, notionProp) {
      final value = rawValues[propName];

      switch (notionProp.type) {
        case 'title':
          propertiesPayload[propName] = {
            "title": [
              {
                "text": {"content": value?.toString() ?? ''},
              },
            ],
          };
          break;

        case 'rich_text':
          propertiesPayload[propName] = {
            "rich_text": [
              {
                "text": {"content": value?.toString() ?? ''},
              },
            ],
          };
          break;

        case 'number':
          final parsedNum = value is int
              ? value
              : int.tryParse(value?.toString() ?? '0') ?? 0;
          propertiesPayload[propName] = {"number": parsedNum};
          break;

        case 'select':
          if (value != null && value.toString().isNotEmpty) {
            propertiesPayload[propName] = {
              "select": {"name": value.toString()},
            };
          }
          break;

        case 'multi_select':
          final selections = (value as List<String>?) ?? [];
          propertiesPayload[propName] = {
            "multi_select": selections.map((e) => {"name": e}).toList(),
          };
          break;

        case 'date':
          final date = _dateValue(value) ?? DateTime.now();
          final dateString =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          propertiesPayload[propName] = {
            "date": {"start": dateString},
          };
          break;
      }
    });

    return {
      "parent": {"database_id": databaseId},
      "properties": propertiesPayload,
    };
  }

  /// Converte para Map (para persistência local)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rawValues': rawValues.map(
        (key, value) => MapEntry(key, _jsonSafeValue(value)),
      ),
      'syncedWithNotion': syncedWithNotion,
      'notionPageId': notionPageId,
      'schema': schema.toJson(),
      'date': date.toIso8601String(),
      'localNote': localNote?.toMap(),
      'source': source.name,
      'studyTimeField': studyTimeField,
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'syncStatus': syncStatus.name,
      'remoteId': remoteId,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    };
  }

  /// Cria a partir de um Map
  factory StudyLog.fromMap(Map<String, dynamic> map) {
    final parsedDate = DateTime.parse(map['date'] as String);
    return StudyLog(
      id: map['id'] as String,
      rawValues: Map<String, dynamic>.from(map['rawValues'] as Map),
      syncedWithNotion: map['syncedWithNotion'] as bool? ?? false,
      notionPageId: map['notionPageId'] as String?,
      schema: NotionDatabaseSchema.fromJson(
        map['schema'] as Map<String, dynamic>,
      ),
      date: parsedDate,
      localNote: map['localNote'] is Map
          ? StudyLogNote.fromMap(
              Map<String, dynamic>.from(map['localNote'] as Map),
            )
          : null,
      source: StudyLogSource.values.firstWhere(
        (source) => source.name == map['source'],
        orElse: () => (map['syncedWithNotion'] as bool? ?? false)
            ? StudyLogSource.notion
            : StudyLogSource.local,
      ),
      studyTimeField: map['studyTimeField']?.toString(),
      updatedAt:
          DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? parsedDate,
      deletedAt: DateTime.tryParse(map['deletedAt']?.toString() ?? ''),
      syncStatus: CloudSyncStatus.values.firstWhere(
        (status) => status.name == map['syncStatus'],
        orElse: () => CloudSyncStatus.localOnly,
      ),
      remoteId: map['remoteId']?.toString(),
      lastSyncedAt: DateTime.tryParse(map['lastSyncedAt']?.toString() ?? ''),
    );
  }

  static int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  static DateTime? _dateValue(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  static dynamic _jsonSafeValue(dynamic value) {
    if (value is DateTime) return value.toIso8601String();
    if (value is List) return value.map(_jsonSafeValue).toList();
    if (value is Map) {
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _jsonSafeValue(nestedValue)),
      );
    }
    return value;
  }
}
