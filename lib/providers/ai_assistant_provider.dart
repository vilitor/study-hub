import 'package:flutter/foundation.dart';
import 'package:study_hub/models/ai_assistant.dart';
import 'package:study_hub/models/study_goal.dart';
import 'package:study_hub/providers/certificate_provider.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/services/ai_command_executor.dart';
import 'package:study_hub/services/ai_context_builder.dart';
import 'package:study_hub/services/ai_insight_engine.dart';
import 'package:study_hub/services/ai_intent_parser.dart';
import 'package:study_hub/services/ai_knowledge_base.dart';
import 'package:study_hub/services/ai_local_summarizer.dart';
import 'package:study_hub/services/ai_recommendation_engine.dart';
import 'package:study_hub/services/ai_text_utils.dart';
import 'package:study_hub/utils/date_helpers.dart';

class AiAssistantProvider extends ChangeNotifier {
  final AiIntentParser _parser;
  final AiContextBuilder _contextBuilder;
  final AiInsightEngine _insights;
  final AiKnowledgeBase _knowledgeBase;
  final AiRecommendationEngine _recommendations;
  final AiCommandExecutor _executor;
  final AiLocalSummarizer _summarizer;

  final List<AiMessage> _messages = [_initialMessage()];
  AiActionDraft? _pendingAction;
  bool _isProcessing = false;

  AiAssistantProvider({
    AiIntentParser parser = const AiIntentParser(),
    AiContextBuilder contextBuilder = const AiContextBuilder(),
    AiInsightEngine insights = const AiInsightEngine(),
    AiKnowledgeBase knowledgeBase = const AiKnowledgeBase(),
    AiRecommendationEngine recommendations = const AiRecommendationEngine(),
    AiCommandExecutor executor = const AiCommandExecutor(),
    AiLocalSummarizer summarizer = const AiLocalSummarizer(),
  }) : _parser = parser,
       _contextBuilder = contextBuilder,
       _insights = insights,
       _knowledgeBase = knowledgeBase,
       _recommendations = recommendations,
       _executor = executor,
       _summarizer = summarizer;

  List<AiMessage> get messages => List.unmodifiable(_messages);
  AiActionDraft? get pendingAction => _pendingAction;
  bool get isProcessing => _isProcessing;

  AiContextSnapshot buildSnapshot({
    required StudyLogProvider logs,
    required StudyEventProvider events,
    required GoalProvider goals,
    required CertificateProvider certificates,
    required SettingsProvider settings,
  }) {
    return _contextBuilder.build(
      logs: logs,
      events: events,
      goals: goals,
      certificates: certificates,
      settings: settings,
    );
  }

  AiRecommendation recommendationFor(AiContextSnapshot snapshot) {
    return _recommendations.nextBestMove(snapshot);
  }

  Future<void> submit({
    required String input,
    required StudyLogProvider logs,
    required StudyEventProvider events,
    required GoalProvider goals,
    required CertificateProvider certificates,
    required SettingsProvider settings,
  }) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty || _isProcessing) return;
    _isProcessing = true;
    _messages.add(
      AiMessage(
        author: AiMessageAuthor.user,
        kind: AiMessageKind.text,
        body: trimmed,
      ),
    );
    notifyListeners();

    final snapshot = buildSnapshot(
      logs: logs,
      events: events,
      goals: goals,
      certificates: certificates,
      settings: settings,
    );
    final intent = _parser.parse(trimmed);
    final response = _respond(intent, snapshot);
    _messages.add(response);
    _pendingAction = response.actionDraft;
    _isProcessing = false;
    notifyListeners();
  }

  Future<bool> confirmPendingAction({
    required StudyEventProvider events,
    required GoalProvider goals,
  }) async {
    final draft = _pendingAction;
    if (draft == null) return false;
    _isProcessing = true;
    notifyListeners();
    final success = await _executor.execute(
      draft: draft,
      events: events,
      goals: goals,
    );
    _messages.add(
      AiMessage(
        author: AiMessageAuthor.luma,
        kind: AiMessageKind.text,
        title: success ? 'Ação concluída' : 'Não consegui concluir',
        body: success
            ? _successMessageFor(draft)
            : 'A ação não foi salva. Seus dados locais não foram alterados.',
      ),
    );
    if (success) _pendingAction = null;
    _isProcessing = false;
    notifyListeners();
    return success;
  }

  void clearPendingAction() {
    _pendingAction = null;
    notifyListeners();
  }

  void resetForAccount() {
    _messages
      ..clear()
      ..add(_initialMessage());
    _pendingAction = null;
    _isProcessing = false;
    notifyListeners();
  }

  void runQuickAction({
    required String command,
    required StudyLogProvider logs,
    required StudyEventProvider events,
    required GoalProvider goals,
    required CertificateProvider certificates,
    required SettingsProvider settings,
  }) {
    submit(
      input: command,
      logs: logs,
      events: events,
      goals: goals,
      certificates: certificates,
      settings: settings,
    );
  }

  AiMessage _respond(AiParsedIntent intent, AiContextSnapshot snapshot) {
    return switch (intent.type) {
      AiIntentType.appHelp => _help(intent),
      AiIntentType.createEvent => _eventDraft(intent),
      AiIntentType.createGoal => _goalDraft(intent),
      AiIntentType.historySearch => _history(intent, snapshot),
      AiIntentType.productivityInsight => _productivity(snapshot),
      AiIntentType.summarize => _summary(intent),
      AiIntentType.openRoute => _openRouteDraft(intent),
      AiIntentType.unknown => _fallback(snapshot),
    };
  }

  AiMessage _help(AiParsedIntent intent) {
    final entry = _knowledgeBase.find(intent.query);
    if (entry == null) {
      return AiMessage(
        author: AiMessageAuthor.luma,
        kind: AiMessageKind.help,
        title: 'Ajuda do Study Hub',
        body:
            'Posso explicar metas, certificados, agenda, registros, Notion, sincronização e atualizações. Pergunte por uma dessas áreas.',
      );
    }
    return AiMessage(
      author: AiMessageAuthor.luma,
      kind: AiMessageKind.help,
      title: entry.title,
      body: entry.answer,
      actionDraft: entry.action,
    );
  }

  AiMessage _eventDraft(AiParsedIntent intent) {
    final date = intent.date ?? DateTime.now();
    final start = intent.startMinuteOfDay ?? 9 * 60;
    final end = intent.endMinuteOfDay ?? start + 60;
    final subject = intent.subject ?? 'Geral';
    final draft = AiActionDraft(
      type: AiActionType.createEvent,
      title: 'Estudar $subject',
      subject: subject,
      description: 'Criado localmente pela Luma após confirmação.',
      date: date,
      startMinuteOfDay: start,
      endMinuteOfDay: end,
    );
    return AiMessage(
      author: AiMessageAuthor.luma,
      kind: AiMessageKind.actionDraft,
      title: 'Evento pronto para revisar',
      body:
          'Vou criar um evento de $subject em ${DateHelpers.formatShortDate(date)}, das ${_formatMinute(start)} as ${_formatMinute(end)}. Confirmo antes de salvar.',
      actionDraft: draft,
    );
  }

  AiMessage _goalDraft(AiParsedIntent intent) {
    final subject = intent.subject;
    final type = intent.goalType ?? GoalType.weekly;
    final minutes = intent.targetMinutes ?? 120;
    final draft = AiActionDraft(
      type: AiActionType.createGoal,
      title: type == GoalType.weekly ? 'Meta semanal' : 'Meta mensal',
      goalType: type,
      targetMinutes: minutes,
      goalSubjects: subject == null ? const [] : [subject],
    );
    return AiMessage(
      author: AiMessageAuthor.luma,
      kind: AiMessageKind.actionDraft,
      title: 'Meta pronta para revisar',
      body:
          'Sugeri uma meta ${type == GoalType.weekly ? 'semanal' : 'mensal'} de ${DateHelpers.formatDuration(minutes)}${subject == null ? '' : ' para $subject'}.',
      actionDraft: draft,
    );
  }

  AiMessage _history(AiParsedIntent intent, AiContextSnapshot snapshot) {
    final logs = snapshot.logs.where((log) {
      final matchesDate =
          intent.date == null || DateHelpers.isSameDay(log.date, intent.date!);
      final subject = intent.subject;
      final matchesSubject =
          subject == null ||
          AiTextUtils.looseContains(AiTextUtils.subjectForLog(log), subject) ||
          AiTextUtils.looseContains(AiTextUtils.noteTextForLog(log), subject);
      return matchesDate && matchesSubject;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));

    if (logs.isEmpty) {
      return AiMessage(
        author: AiMessageAuthor.luma,
        kind: AiMessageKind.searchResults,
        title: 'Nada encontrado',
        body:
            'Nao encontrei registros locais para essa busca. Tente uma materia, data ou termo de nota diferente.',
      );
    }

    final total = logs.fold<int>(0, (sum, log) => sum + log.studyTimeMinutes);
    return AiMessage(
      author: AiMessageAuthor.luma,
      kind: AiMessageKind.searchResults,
      title: 'Encontrei ${logs.length} registro(s)',
      body:
          'Total nessa busca: ${DateHelpers.formatDuration(total)}. Tudo veio do historico local sincronizado.',
      results: logs.take(6).map((log) {
        return AiResultItem(
          title: AiTextUtils.titleForLog(log),
          subtitle:
              '${AiTextUtils.subjectForLog(log)} • ${DateHelpers.formatShortDate(log.date)}',
          detail: AiTextUtils.noteTextForLog(log).isEmpty
              ? DateHelpers.formatDuration(log.studyTimeMinutes)
              : AiTextUtils.noteTextForLog(log),
          date: log.date,
        );
      }).toList(),
    );
  }

  AiMessage _productivity(AiContextSnapshot snapshot) {
    final cards = _insights.productivityCards(snapshot);
    final summary = _insights.summarize(snapshot);
    return AiMessage(
      author: AiMessageAuthor.luma,
      kind: AiMessageKind.insight,
      title: summary.headline,
      body: summary.detail,
      results: cards,
    );
  }

  AiMessage _summary(AiParsedIntent intent) {
    final cleaned = intent.query
        .replaceFirst(
          RegExp(r'resuma|resumir|summarize|summary', caseSensitive: false),
          '',
        )
        .trim();
    final summary = _summarizer.summarize(
      cleaned.isEmpty ? intent.query : cleaned,
    );
    return AiMessage(
      author: AiMessageAuthor.luma,
      kind: AiMessageKind.summary,
      title: 'Resumo local',
      body:
          'Usei uma estratégia local de extração de frases importantes. Revise antes de salvar como nota.\n\n$summary',
    );
  }

  AiMessage _openRouteDraft(AiParsedIntent intent) {
    return AiMessage(
      author: AiMessageAuthor.luma,
      kind: AiMessageKind.actionDraft,
      title: 'Abrir area',
      body: 'Posso te levar para essa area agora.',
      actionDraft: AiActionDraft(
        type: AiActionType.openRoute,
        title: 'Abrir',
        routeName: intent.routeName,
      ),
    );
  }

  AiMessage _fallback(AiContextSnapshot snapshot) {
    final recommendation = _recommendations.nextBestMove(snapshot);
    return AiMessage(
      author: AiMessageAuthor.luma,
      kind: AiMessageKind.insight,
      title: recommendation.title,
      body:
          '${recommendation.body}\n\nTambem posso buscar historico, explicar o app ou criar eventos e metas por comando.',
      actionDraft: recommendation.actionDraft,
    );
  }

  String _successMessageFor(AiActionDraft draft) {
    return switch (draft.type) {
      AiActionType.createEvent =>
        'Evento salvo localmente. Se o Google Calendar estiver conectado, o fluxo existente tentara sincronizar.',
      AiActionType.createGoal =>
        'Meta salva localmente e colocada no fluxo de sincronização.',
      AiActionType.openRoute => 'Area aberta.',
    };
  }

  String _formatMinute(int minuteOfDay) {
    final hour = minuteOfDay ~/ 60;
    final minute = minuteOfDay % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static AiMessage _initialMessage() {
    return AiMessage(
      author: AiMessageAuthor.luma,
      kind: AiMessageKind.text,
      title: 'Luma',
      body:
          'Estou pronta para buscar seu histórico, criar planos e executar ações locais quando você confirmar.',
    );
  }
}
