import 'package:study_hub/models/ai_assistant.dart';
import 'package:study_hub/services/ai_context_builder.dart';
import 'package:study_hub/services/ai_insight_engine.dart';

class AiRecommendationEngine {
  final AiInsightEngine _insights;

  const AiRecommendationEngine({
    AiInsightEngine insights = const AiInsightEngine(),
  }) : _insights = insights;

  AiRecommendation nextBestMove(AiContextSnapshot context) {
    final summary = _insights.summarize(context);
    if (context.logs.isEmpty) {
      return const AiRecommendation(
        title: 'Comece com um registro curto',
        body:
            'Depois do primeiro registro, eu consigo mostrar padroes, dias fortes e proximos passos.',
        tone: AiInsightTone.neutral,
      );
    }
    return AiRecommendation(
      title: summary.headline,
      body: summary.detail,
      tone: summary.tone,
      actionDraft: summary.weakestSubject == null
          ? null
          : AiActionDraft(
              type: AiActionType.createEvent,
              title: 'Revisar ${summary.weakestSubject}',
              subject: summary.weakestSubject,
              description: 'Sugestão local da Luma para equilibrar a semana.',
              date: DateTime.now().add(const Duration(days: 1)),
              startMinuteOfDay: 9 * 60,
              endMinuteOfDay: 9 * 60 + 30,
            ),
    );
  }
}
