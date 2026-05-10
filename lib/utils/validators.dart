/// Validações de formulários
/// Retorna null se o campo é válido, ou uma mensagem de erro
class Validators {
  /// Campo obrigatório
  static String? required(String? value, [String fieldName = 'Este campo']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName é obrigatório';
    }
    return null;
  }

  /// Tamanho mínimo
  static String? minLength(
    String? value,
    int min, [
    String fieldName = 'Este campo',
  ]) {
    if (value == null || value.trim().length < min) {
      return '$fieldName deve ter pelo menos $min caracteres';
    }
    return null;
  }

  /// Valida que hora fim é depois da hora início
  static String? timeRange(
    int startHour,
    int startMin,
    int endHour,
    int endMin,
  ) {
    final start = startHour * 60 + startMin;
    final end = endHour * 60 + endMin;
    if (end <= start) {
      return 'A hora de fim deve ser depois da hora de início';
    }
    return null;
  }

  /// Valida token do Notion (deve começar com ntn_ ou secret_)
  static String? notionToken(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Token é obrigatório';
    }
    if (!value.startsWith('ntn_') && !value.startsWith('secret_')) {
      return 'Token deve começar com "ntn_" ou "secret_"';
    }
    return null;
  }

  /// Valida ID do database do Notion (32 caracteres hex)
  static String? notionDatabaseId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Database ID é obrigatório';
    }
    // Remove hífens, o ID pode ter 32 chars hex com ou sem hífens
    final cleaned = value.replaceAll('-', '');
    if (cleaned.length != 32) {
      return 'Database ID deve ter 32 caracteres';
    }
    return null;
  }
}
