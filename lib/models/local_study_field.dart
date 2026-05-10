import 'package:uuid/uuid.dart';

enum LocalStudyFieldType { text, longText, number, select, multiSelect, date }

class LocalStudyField {
  final String id;
  final String label;
  final LocalStudyFieldType type;
  final List<String> options;
  final bool isRequired;
  final bool isDefault;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  LocalStudyField({
    String? id,
    required this.label,
    required this.type,
    this.options = const [],
    this.isRequired = false,
    this.isDefault = false,
    this.isArchived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  LocalStudyField copyWith({
    String? label,
    LocalStudyFieldType? type,
    List<String>? options,
    bool? isRequired,
    bool? isDefault,
    bool? isArchived,
    DateTime? updatedAt,
  }) {
    return LocalStudyField(
      id: id,
      label: label ?? this.label,
      type: type ?? this.type,
      options: options ?? this.options,
      isRequired: isRequired ?? this.isRequired,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'type': type.name,
      'options': options,
      'isRequired': isRequired,
      'isDefault': isDefault,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LocalStudyField.fromMap(Map<String, dynamic> map) {
    return LocalStudyField(
      id: map['id']?.toString(),
      label: map['label']?.toString() ?? '',
      type: LocalStudyFieldType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => LocalStudyFieldType.text,
      ),
      options: List<String>.from(map['options'] as List? ?? const []),
      isRequired: map['isRequired'] as bool? ?? false,
      isDefault: map['isDefault'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

extension LocalStudyFieldTypeUi on LocalStudyFieldType {
  String get label {
    return switch (this) {
      LocalStudyFieldType.text => 'Texto curto',
      LocalStudyFieldType.longText => 'Texto longo',
      LocalStudyFieldType.number => 'Numero',
      LocalStudyFieldType.select => 'Selecao',
      LocalStudyFieldType.multiSelect => 'Multipla selecao',
      LocalStudyFieldType.date => 'Data',
    };
  }

  String get notionType {
    return switch (this) {
      LocalStudyFieldType.text => 'rich_text',
      LocalStudyFieldType.longText => 'rich_text',
      LocalStudyFieldType.number => 'number',
      LocalStudyFieldType.select => 'select',
      LocalStudyFieldType.multiSelect => 'multi_select',
      LocalStudyFieldType.date => 'date',
    };
  }
}
