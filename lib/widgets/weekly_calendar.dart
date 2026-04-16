import 'package:flutter/material.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/utils/date_helpers.dart';

/// Calendário semanal deslizável — inspirado na referência visual
/// Permite arrastar para os lados para mudar de semana
class WeeklyCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const WeeklyCalendar({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<WeeklyCalendar> createState() => _WeeklyCalendarState();
}

class _WeeklyCalendarState extends State<WeeklyCalendar> {
  late PageController _pageController;
  final int _initialPage = 5000; // Índice arbitrário alto para scroll "infinito"
  late DateTime _baseDate;

  @override
  void initState() {
    super.initState();
    _baseDate = DateTime.now();
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(WeeklyCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se a data selecionada mudou externamente (ex: seletor manual), pulamos para a página correta
    if (!DateHelpers.isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _jumpToDate(widget.selectedDate);
    }
  }

  void _jumpToDate(DateTime date) {
    final int targetPage = _calculatePageForDate(date);
    if (_pageController.hasClients && _pageController.page?.round() != targetPage) {
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  int _calculatePageForDate(DateTime date) {
    // Calcula a diferença de semanas entre a data base e a data alvo
    final startOfBaseWeek = _getStartOfWeek(_baseDate);
    final startOfTargetWeek = _getStartOfWeek(date);
    final difference = startOfTargetWeek.difference(startOfBaseWeek).inDays;
    return _initialPage + (difference / 7).round();
  }

  DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: PageView.builder(
        controller: _pageController,
        itemBuilder: (context, index) {
          // Calcula os dias dessa página (semana)
          final weekOffset = index - _initialPage;
          final weekStartDate = _getStartOfWeek(_baseDate).add(Duration(days: weekOffset * 7));
          final weekDays = List.generate(7, (i) => weekStartDate.add(Duration(days: i)));

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekDays.map((day) {
                final isSelected = DateHelpers.isSameDay(day, widget.selectedDate);
                final isToday = DateHelpers.isToday(day);

                return GestureDetector(
                  onTap: () => widget.onDateSelected(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.coral : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateHelpers.getWeekdayLetter(day),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? AppColors.coral
                                    : AppColors.textHint,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          day.day.toString(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected || isToday
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? AppColors.coral
                                    : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
