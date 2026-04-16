import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/config/app_routes.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/screens/home/home_screen.dart';
import 'package:study_hub/screens/create_event/create_event_screen.dart';
import 'package:study_hub/screens/study_log/study_log_screen.dart';
import 'package:study_hub/screens/settings/settings_screen.dart';

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
      ],
      child: MaterialApp(
        title: 'StudyHub',
        debugShowCheckedModeBanner: false,

        // Tema visual do app
        theme: AppTheme.lightTheme,

        // Tela inicial com navegação por abas
        home: const MainNavigationScreen(),

        // Rotas nomeadas para navegação entre telas
        routes: {
          AppRoutes.createEvent: (context) => const CreateEventScreen(),
          AppRoutes.studyLog: (context) => const StudyLogScreen(),
          AppRoutes.settings: (context) => const SettingsScreen(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      // Bottom Navigation Bar — inspirada na referência visual
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_rounded,
                  label: 'Home',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.calendar_month_rounded,
                  label: 'Agenda',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.edit_note_rounded,
                  label: 'Registro',
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.settings_rounded,
                  label: 'Config',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Item individual da bottom navigation
  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppColors.primaryGreen : AppColors.textHint,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color:
                    isSelected ? AppColors.primaryGreen : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
