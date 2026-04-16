import 'package:intl/intl.dart';

/// Funções auxiliares para formatação e cálculo de datas
class DateHelpers {
  /// Formata data como "15 de abril de 2026"
  static String formatFullDate(DateTime date) {
    return DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR').format(date);
  }

  /// Formata data como "15/04/2026"
  static String formatShortDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Formata data como "15 abr"
  static String formatCompactDate(DateTime date) {
    return DateFormat('d MMM', 'pt_BR').format(date);
  }

  /// Formata hora como "09:30"
  static String formatTime(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Retorna saudação com base na hora do dia
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  /// Retorna o dia da semana abreviado (ex: "Seg", "Ter")
  static String getWeekdayShort(DateTime date) {
    const weekdays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return weekdays[date.weekday % 7];
  }

  /// Retorna a letra do dia da semana (S, M, T, W, T, F, S) — para o calendário
  static String getWeekdayLetter(DateTime date) {
    const letters = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    return letters[date.weekday % 7];
  }

  /// Verifica se duas datas são o mesmo dia
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Retorna os dias da semana atual (Dom → Sáb)
  static List<DateTime> getCurrentWeekDays(DateTime referenceDate) {
    // Encontrar o domingo da semana
    final sunday = referenceDate.subtract(
      Duration(days: referenceDate.weekday % 7),
    );
    return List.generate(7, (i) => sunday.add(Duration(days: i)));
  }

  /// Verifica se a data é hoje
  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  /// Formata duração em minutos para texto legível
  static String formatDuration(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}min';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${mins}min';
    }
  }
}
