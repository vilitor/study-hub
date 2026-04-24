import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/config/app_routes.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/study_timer_provider.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/screens/home/home_screen.dart';
import 'package:study_hub/screens/create_event/create_event_screen.dart';
import 'package:study_hub/screens/study_log/study_log_screen.dart';
import 'package:study_hub/screens/settings/settings_screen.dart';
import 'package:study_hub/screens/history/registration_history_screen.dart';
import 'package:study_hub/widgets/floating_nav_bar.dart';
import 'package:study_hub/widgets/floating_timer_bar.dart';

/// Ponto de entrada do app StudyHub
void main() async {
  // Garante que o Flutter está inicializado antes de rodar código assíncrono
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa dados de localização (para datas em português)
  await initializeDateFormatting('pt_BR', null);

  // Define a barra de status como transparente
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const StudyHubApp());
}

/// Widget raiz do app
class StudyHubApp extends StatelessWidget {
  const StudyHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider: registra todos os providers de uma vez
    // Os widgets filhos podem acessar esses providers com context.read ou Consumer
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StudyEventProvider()),
        ChangeNotifierProvider(create: (_) => StudyLogProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..loadSettings()),
        ChangeNotifierProvider(create: (_) => StudyTimerProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
      ],
      child: MaterialApp(
        title: 'StudyHub',
        debugShowCheckedModeBanner: false,

        // Tema visual do app
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: context.watch<SettingsProvider>().themeMode == 'dark'
            ? ThemeMode.dark
            : context.watch<SettingsProvider>().themeMode == 'light'
                ? ThemeMode.light
                : ThemeMode.system,

        // Tela inicial com navegação por abas
        home: const MainNavigationScreen(),

        // Rotas nomeadas para navegação entre telas
        routes: {
          AppRoutes.createEvent: (context) => const CreateEventScreen(),
          AppRoutes.studyLog: (context) => const StudyLogScreen(),
          AppRoutes.settings: (context) => const SettingsScreen(),
          AppRoutes.history: (context) => const RegistrationHistoryScreen(),
        },
      ),
    );
  }
}

/// Tela principal com Bottom Navigation Bar
/// Gerencia a navegação entre Home, Agenda (criar evento), Registro e Configurações
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Telas que aparecem no body conforme a aba selecionada
  final List<Widget> _screens = const [
    HomeScreen(),
    CreateEventScreen(),
    StudyLogScreen(),
    SettingsScreen(),
  ];

  final List<NavItem> _navItems = [
    NavItem(icon: Icons.home_rounded, label: 'Home'),
    NavItem(icon: Icons.calendar_month_rounded, label: 'Agenda'),
    NavItem(icon: Icons.edit_note_rounded, label: 'Registro'),
    NavItem(icon: Icons.settings_rounded, label: 'Config'),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
            // Floating timer bar — appears above nav when timer is active
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingTimerBar(),
            ),
          ],
        ),

        // Barra de Navegação Flutuante Premium
        bottomNavigationBar: FloatingNavBar(
          currentIndex: _currentIndex,
          items: _navItems,
          onTap: (index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }
}
