import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/certificate.dart';
import 'package:study_hub/providers/certificate_provider.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/screens/achievements/achievements_screen.dart';
import 'package:study_hub/widgets/certificate_widgets.dart';

void main() {
  testWidgets('Achievements screen renders empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CertificateProvider()),
          ChangeNotifierProvider(create: (_) => StudyLogProvider()),
          ChangeNotifierProvider(create: (_) => GoalProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AchievementsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conquistas'), findsOneWidget);
    expect(find.text('Nenhum certificado salvo'), findsOneWidget);
    expect(find.text('Adicionar certificado'), findsOneWidget);
  });

  testWidgets('Certificate card renders metadata and validation badge', (
    tester,
  ) async {
    final certificate = Certificate(
      title: 'Flutter UI',
      provider: 'Alura',
      issueDate: DateTime(2026, 5, 6),
      validation: const CertificateValidation(
        status: CertificateValidationStatus.trustedProviderLink,
        providerName: 'Alura',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: CertificateCard(certificate: certificate, onTap: () {}),
        ),
      ),
    );

    expect(find.text('Flutter UI'), findsOneWidget);
    expect(find.text('Alura'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
  });
}
