import 'package:flutter/foundation.dart';
import 'package:study_hub/models/auth_session.dart';
import 'package:study_hub/models/onboarding_state.dart';
import 'package:study_hub/models/study_goal.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/repositories/subject_repository.dart';
import 'package:study_hub/models/app_settings.dart';
import 'package:study_hub/models/notion_schema.dart';

class GuideStep {
  final String title;
  final String body;
  final String actionLabel;
  final int? navigationIndex;

  const GuideStep({
    required this.title,
    required this.body,
    required this.actionLabel,
    this.navigationIndex,
  });
}

class ContextualGuideProvider extends ChangeNotifier {
  int _index = 0;
  bool _dismissedForSession = false;

  int get index => _index;
  bool get dismissedForSession => _dismissedForSession;

  List<GuideStep> steps({
    required OnboardingState onboarding,
    required AppSettings settings,
    required AuthSessionStatus authStatus,
    required StudyEventProvider events,
    required StudyLogProvider logs,
    required List<StudyGoal> goals,
    required NotionDatabaseSchema? schema,
  }) {
    final subjects = const SubjectRepository().getSubjects(
      settings: settings,
      schema: schema,
    );
    final result = <GuideStep>[];

    if (subjects.isEmpty) {
      result.add(
        const GuideStep(
          title: 'Comece com suas matérias',
          body:
              'Seu espaço está limpo de propósito. Adicione as primeiras matérias para moldar agenda, metas e registros ao seu jeito.',
          actionLabel: 'Abrir matérias',
          navigationIndex: 2,
        ),
      );
    }

    if (events.totalEvents == 0) {
      result.add(
        const GuideStep(
          title: 'Planeje a primeira sessao',
          body:
              'A agenda ajuda a transformar intencao em horario. Crie um evento simples para o proximo bloco de estudo.',
          actionLabel: 'Criar evento',
          navigationIndex: 2,
        ),
      );
    }

    if (logs.totalLogs == 0) {
      result.add(
        const GuideStep(
          title: 'Registre o que estudou',
          body:
              'Depois de estudar, salve tempo, assunto e notas. O desempenho e a Luma ficam melhores a cada registro.',
          actionLabel: 'Registrar estudo',
          navigationIndex: 3,
        ),
      );
    }

    if (goals.isEmpty) {
      result.add(
        const GuideStep(
          title: 'Defina uma meta quando fizer sentido',
          body:
              'Metas sao opcionais. Use-as para acompanhar consistencia por semana, mes ou materia.',
          actionLabel: 'Ver inicio',
          navigationIndex: 0,
        ),
      );
    }

    result.add(
      GuideStep(
        title: authStatus == AuthSessionStatus.guest
            ? 'Local-first, sem pressa para entrar'
            : 'Sincronização em segundo plano',
        body: authStatus == AuthSessionStatus.guest
            ? 'Como visitante, seus dados ficam neste dispositivo. Você pode conectar o Google depois para backup e Calendar.'
            : 'O Study Hub salva localmente primeiro e sincroniza quando possível, sem bloquear seu fluxo.',
        actionLabel: 'Entendi',
      ),
    );

    return result;
  }

  bool shouldShow({
    required OnboardingState onboarding,
    required List<GuideStep> steps,
  }) {
    return onboarding.onboardingCompleted &&
        !onboarding.contextualGuideCompleted &&
        !_dismissedForSession &&
        steps.isNotEmpty;
  }

  void next(int total) {
    if (_index < total - 1) {
      _index++;
      notifyListeners();
    }
  }

  void reset() {
    _index = 0;
    _dismissedForSession = false;
    notifyListeners();
  }

  void dismissForSession() {
    _dismissedForSession = true;
    notifyListeners();
  }
}
