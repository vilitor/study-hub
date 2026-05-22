import 'package:study_hub/models/study_log.dart';

class AiTextUtils {
  static const Set<String> stopWords = {
    'a',
    'an',
    'and',
    'as',
    'about',
    'de',
    'da',
    'do',
    'das',
    'dos',
    'e',
    'em',
    'for',
    'how',
    'i',
    'me',
    'my',
    'o',
    'os',
    'para',
    'por',
    'que',
    'the',
    'to',
    'um',
    'uma',
    'what',
    'with',
  };

  static String normalize(String value) {
    const accents = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'ê': 'e',
      'è': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'õ': 'o',
      'ô': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    final lower = value.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(accents[char] ?? char);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9:/\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> tokens(String value) {
    return normalize(value)
        .split(' ')
        .where((token) => token.length > 2 && !stopWords.contains(token))
        .toList();
  }

  static String subjectForLog(StudyLog log) {
    if (log.localNote != null && log.localNote!.subject.trim().isNotEmpty) {
      return log.localNote!.subject.trim();
    }
    final directSubject =
        log.rawValues['Assunto'] ?? log.rawValues['Categoria'];
    if (directSubject != null && directSubject.toString().trim().isNotEmpty) {
      return directSubject.toString().trim();
    }
    for (final entry in log.schema.properties.entries) {
      final prop = entry.value;
      final raw = log.rawValues[prop.name];
      if (prop.type == 'select' &&
          raw != null &&
          raw.toString().trim().isNotEmpty) {
        return raw.toString().trim();
      }
      if (prop.type == 'multi_select' && raw is List && raw.isNotEmpty) {
        return raw.first.toString();
      }
    }
    for (final entry in log.schema.properties.entries) {
      final prop = entry.value;
      final raw = log.rawValues[prop.name];
      if (prop.type == 'title' && raw != null && raw.toString().isNotEmpty) {
        return raw.toString();
      }
    }
    return 'Geral';
  }

  static String titleForLog(StudyLog log) {
    if (log.localNote != null && log.localNote!.contentName.trim().isNotEmpty) {
      return log.localNote!.contentName.trim();
    }
    for (final entry in log.schema.properties.entries) {
      final prop = entry.value;
      final raw = log.rawValues[prop.name];
      if (prop.type == 'title' && raw != null && raw.toString().isNotEmpty) {
        return raw.toString();
      }
    }
    return subjectForLog(log);
  }

  static String noteTextForLog(StudyLog log) {
    final note = log.localNote;
    if (note != null && note.summary.trim().isNotEmpty) {
      return note.summary.trim();
    }
    final values = <String>[];
    for (final entry in log.schema.properties.entries) {
      final prop = entry.value;
      if (prop.type != 'rich_text' && prop.type != 'title') continue;
      final raw = log.rawValues[prop.name];
      if (raw != null && raw.toString().trim().isNotEmpty) {
        values.add(raw.toString().trim());
      }
    }
    return values.join('\n');
  }

  static bool looseContains(String haystack, String needle) {
    final normalizedHaystack = normalize(haystack);
    final normalizedNeedle = normalize(needle);
    if (normalizedNeedle.isEmpty) return true;
    return normalizedHaystack.contains(normalizedNeedle);
  }
}
