import 'package:study_hub/models/ai_assistant.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/providers/study_event_provider.dart';

class AiCommandExecutor {
  const AiCommandExecutor();

  Future<bool> execute({
    required AiActionDraft draft,
    required StudyEventProvider events,
    required GoalProvider goals,
  }) async {
    return switch (draft.type) {
      AiActionType.createEvent => events.addEvent(draft.toStudyEvent()),
      AiActionType.createGoal => goals.addGoal(draft.toStudyGoal()),
      AiActionType.openRoute => true,
    };
  }
}
