import 'package:flutter/material.dart';
import 'package:study_hub/screens/home/home_screen.dart';
import 'package:study_hub/screens/achievements/achievements_screen.dart';
import 'package:study_hub/screens/create_event/create_event_screen.dart';
import 'package:study_hub/screens/study_log/study_log_screen.dart';
import 'package:study_hub/screens/settings/settings_screen.dart';
import 'package:study_hub/screens/history/registration_history_screen.dart';

/// Rotas de navegação do app
/// Cada tela tem um nome (string) que usamos para navegar
class AppRoutes {
  static const String home = '/';
  static const String createEvent = '/create-event';
  static const String studyLog = '/study-log';
  static const String settings = '/settings';
  static const String history = '/history';
  static const String achievements = '/achievements';

  /// Mapa de todas as rotas do app
  static Map<String, WidgetBuilder> get routes => {
    home: (context) => const HomeScreen(),
    createEvent: (context) => const CreateEventScreen(),
    studyLog: (context) => const StudyLogScreen(),
    settings: (context) => const SettingsScreen(),
    history: (context) => const RegistrationHistoryScreen(),
    achievements: (context) => const AchievementsScreen(),
  };
}
