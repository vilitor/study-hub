import 'package:uuid/uuid.dart';
import 'package:study_hub/models/notion_schema.dart';

/// Uma entrada de log dinâmica, suportando mapeamento N-para-N de campos
class StudyLog {
  final String id;
  // Guarda temporariamente os valores antes de subir para nuvem (Chave = Nome da Propriedade, Valor = dynamic)
  final Map<String, dynamic> rawValues;
  final bool syncedWithNotion;
  final String? notionPageId; // Notion page ID for deletion sync
  final NotionDatabaseSchema schema;
  final DateTime date;

  StudyLog({
    String? id,
    required this.rawValues,
    required this.schema,
    this.syncedWithNotion = false,
    this.notionPageId,
    DateTime? date,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now();

  StudyLog copyWith({
    Map<String, dynamic>? rawValues,
    bool? syncedWithNotion,
    String? notionPageId,
    NotionDatabaseSchema? schema,
    DateTime? date,
  }) {
    return StudyLog(
      id: id,
      rawValues: rawValues ?? this.rawValues,
      syncedWithNotion: syncedWithNotion ?? this.syncedWithNotion,
      notionPageId: notionPageId ?? this.notionPageId,
      schema: schema ?? this.schema,
      date: date ?? this.date,
    );
  }

  int get studyTimeMinutes {
    int total = 0;
    schema.properties.forEach((propName, notionProp) {
        if (notionProp.type == 'number') {
            total += int.tryParse(rawValues[propName]?.toString() ?? '0') ?? 0;
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
                "text": {"content": value?.toString() ?? ''}
              }
            ]
          };
          break;

        case 'rich_text':
          propertiesPayload[propName] = {
            "rich_text": [
              {
                "text": {"content": value?.toString() ?? ''}
              }
            ]
          };
          break;

        case 'number':
          final parsedNum = value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;
          propertiesPayload[propName] = {
            "number": parsedNum
          };
          break;

        case 'select':
          if (value != null && value.toString().isNotEmpty) {
            propertiesPayload[propName] = {
              "select": {"name": value.toString()}
            };
          }
          break;

        case 'multi_select':
          final selections = (value as List<String>?) ?? [];
          propertiesPayload[propName] = {
            "multi_select": selections.map((e) => {"name": e}).toList()
          };
          break;

        case 'date':
          // Automaticamente gera a data de hoje, conforme pedido ("apenas uma data preenchida")
          final now = DateTime.now();
          final dateString = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          propertiesPayload[propName] = {
            "date": {"start": dateString}
          };
          break;
      }
    });

    return {
      "parent": {
        "database_id": databaseId,
      },
      "properties": propertiesPayload,
    };
  }

  /// Converte para Map (para persistência local)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rawValues': rawValues,
      'syncedWithNotion': syncedWithNotion,
      'notionPageId': notionPageId,
      'schema': schema.toJson(),
      'date': date.toIso8601String(),
    };
  }

  /// Cria a partir de um Map
  factory StudyLog.fromMap(Map<String, dynamic> map) {
    return StudyLog(
      id: map['id'] as String,
      rawValues: Map<String, dynamic>.from(map['rawValues'] as Map),
      syncedWithNotion: map['syncedWithNotion'] as bool? ?? false,
      notionPageId: map['notionPageId'] as String?,
      schema: NotionDatabaseSchema.fromJson(map['schema'] as Map<String, dynamic>),
      date: DateTime.parse(map['date'] as String),
    );
  }
}
