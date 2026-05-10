/// Representa o Schema completo de um Database do Notion
class NotionDatabaseSchema {
  final Map<String, NotionProperty> properties;

  NotionDatabaseSchema({required this.properties});

  factory NotionDatabaseSchema.fromJson(Map<String, dynamic> json) {
    final Map<String, NotionProperty> props = {};

    if (json.containsKey('properties')) {
      final propertiesJson = json['properties'] as Map<String, dynamic>;
      propertiesJson.forEach((key, value) {
        props[key] = NotionProperty.fromJson(
          key,
          value as Map<String, dynamic>,
        );
      });
    }

    return NotionDatabaseSchema(properties: props);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> propsJson = {};
    properties.forEach((key, value) {
      propsJson[key] = value.toJson();
    });
    return {'properties': propsJson};
  }
}

/// Representa uma coluna (propriedade) do banco de dados
class NotionProperty {
  final String id;
  final String name;
  final String
  type; // ex: 'title', 'rich_text', 'select', 'multi_select', 'number', 'date'
  final List<String> options; // opções para 'select' e 'multi_select'

  NotionProperty({
    required this.id,
    required this.name,
    required this.type,
    this.options = const [],
  });

  factory NotionProperty.fromJson(String name, Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'unknown';
    List<String> parsedOptions = [];

    // Extrai as opções validas se for um select ou multi_select
    if (type == 'select' && json.containsKey('select')) {
      final selectObj = json['select'] as Map<String, dynamic>;
      if (selectObj.containsKey('options')) {
        final optionsList = selectObj['options'] as List<dynamic>?;
        parsedOptions =
            optionsList?.map((e) => e['name'] as String).toList() ?? [];
      }
    } else if (type == 'multi_select' && json.containsKey('multi_select')) {
      final selectObj = json['multi_select'] as Map<String, dynamic>;
      if (selectObj.containsKey('options')) {
        final optionsList = selectObj['options'] as List<dynamic>?;
        parsedOptions =
            optionsList?.map((e) => e['name'] as String).toList() ?? [];
      }
    }

    return NotionProperty(
      id: json['id'] as String? ?? '',
      name: name,
      type: type,
      options: parsedOptions,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {'id': id, 'type': type};

    if (type == 'select') {
      data['select'] = {
        'options': options.map((e) => {'name': e}).toList(),
      };
    } else if (type == 'multi_select') {
      data['multi_select'] = {
        'options': options.map((e) => {'name': e}).toList(),
      };
    }

    return data;
  }
}
