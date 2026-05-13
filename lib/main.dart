import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/config/app_routes.dart';
import 'package:study_hub/providers/auth_session_provider.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/providers/certificate_provider.dart';
import 'package:study_hub/providers/local_study_schema_provider.dart';
import 'package:study_hub/providers/navigation_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/study_timer_provider.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/services/cloud_sync_service.dart';
import 'package:study_hub/services/sync_coordinator.dart';
import 'package:study_hub/screens/home/home_screen.dart';
import 'package:study_hub/screens/achievements/achievements_screen.dart';
import 'package:study_hub/screens/create_event/create_event_screen.dart';
import 'package:study_hub/screens/study_log/study_log_screen.dart';
import 'package:study_hub/screens/settings/settings_screen.dart';
import 'package:study_hub/screens/history/registration_history_screen.dart';
import 'package:study_hub/screens/performance/performance_screen.dart';
import 'package:study_hub/screens/splash/startup_gate.dart';
import 'package:study_hub/widgets/floating_nav_bar.dart';
import 'package:study_hub/widgets/floating_timer_bar.dart';

/// Ponto de entrada do app StudyHub
void main() async {
  // Garante que o Flutter está inicializado antes de rodar código assíncrono
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa dados de localização (para datas em português)
  await initializeDateFormatting('pt_BR', null);
  await Firebase.initializeApp();
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

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
        ChangeNotifierProvider(create: (_) => AuthSessionProvider()),
        ChangeNotifierProvider(create: (_) => StudyEventProvider()),
        ChangeNotifierProvider(create: (_) => StudyLogProvider()),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..loadSettings(),
        ),
        ChangeNotifierProvider(create: (_) => StudyTimerProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider(create: (_) => CertificateProvider()),
        ChangeNotifierProvider(create: (_) => LocalStudySchemaProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider.value(value: CloudSyncService.instance),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return SyncCoordinator(
            child: MaterialApp(
              title: 'StudyHub',
              debugShowCheckedModeBanner: false,

              // Tema visual do app
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: settings.themeMode == 'dark'
                  ? ThemeMode.dark
                  : settings.themeMode == 'light'
                  ? ThemeMode.light
                  : ThemeMode.light,

              // Tela inicial com navegação por abas
              home: const StartupGate(destination: MainNavigationScreen()),

              // Rotas nomeadas para navegação entre telas
              routes: {
                AppRoutes.createEvent: (context) => const CreateEventScreen(),
                AppRoutes.studyLog: (context) => const StudyLogScreen(),
                AppRoutes.settings: (context) => const SettingsScreen(),
                AppRoutes.history: (context) =>
                    const RegistrationHistoryScreen(),
                AppRoutes.achievements: (context) => const AchievementsScreen(),
              },
            ),
          );
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
  // Telas que aparecem no body conforme a aba selecionada
  final List<Widget> _screens = const [
    HomeScreen(),
    PerformanceScreen(),
    CreateEventScreen(),
    StudyLogScreen(),
    SettingsScreen(),
  ];

  final List<NavItem> _navItems = [
    NavItem(icon: Icons.home_rounded, label: 'Início'),
    NavItem(icon: Icons.auto_graph_rounded, label: 'Desempenho'),
    NavItem(icon: Icons.calendar_month_rounded, label: 'Agenda'),
    NavItem(icon: Icons.edit_note_rounded, label: 'Registro'),
    NavItem(icon: Icons.settings_rounded, label: 'Configurações'),
  ];

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<NavigationProvider>();
    return PopScope(
      canPop: navigation.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (navigation.currentIndex != 0) {
          context.read<NavigationProvider>().resetToHome();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: context
                  .read<NavigationProvider>()
                  .handleScrollNotification,
              child: IndexedStack(
                index: navigation.currentIndex,
                children: _screens,
              ),
            ),
            // Floating timer bar — appears above nav when timer is active
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingTimerBar(),
            ),

            // Floating Navigation Bar — moved from Scaffold slot to Stack for better transparency
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingNavBar(
                currentIndex: navigation.currentIndex,
                isVisible: navigation.isNavVisible,
                items: _navItems,
                onTap: (index) {
                  AppHaptics.selection();
                  context.read<NavigationProvider>().setIndex(index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
