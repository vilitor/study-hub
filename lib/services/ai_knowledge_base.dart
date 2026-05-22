import 'package:study_hub/config/app_routes.dart';
import 'package:study_hub/models/ai_assistant.dart';
import 'package:study_hub/services/ai_text_utils.dart';

class AiKnowledgeEntry {
  final List<String> keywords;
  final String title;
  final String answer;
  final AiActionDraft? action;

  const AiKnowledgeEntry({
    required this.keywords,
    required this.title,
    required this.answer,
    this.action,
  });
}

class AiKnowledgeBase {
  static const entries = [
    AiKnowledgeEntry(
      keywords: ['goal', 'goals', 'meta', 'metas', 'subject', 'materia'],
      title: 'Metas e matérias',
      answer:
          'As matérias das metas seguem a mesma origem usada nos eventos. Abra Início, toque em adicionar meta e escolha as matérias; para editar a lista local, use Agenda > Matérias.',
    ),
    AiKnowledgeEntry(
      keywords: [
        'certificate',
        'certificates',
        'certificado',
        'certificados',
        'achievement',
        'achievements',
        'conquista',
        'conquistas',
      ],
      title: 'Certificados e conquistas',
      answer:
          'Certificados ficam em Conquistas. Eles alimentam sua progressão e ajudam Luma a entender sua jornada. Você pode adicionar certificados, anexos e links de validação.',
      action: AiActionDraft(
        type: AiActionType.openRoute,
        title: 'Abrir conquistas',
        routeName: AppRoutes.achievements,
      ),
    ),
    AiKnowledgeEntry(
      keywords: ['calendar', 'google', 'agenda', 'event', 'evento'],
      title: 'Agenda e Google Calendar',
      answer:
          'Eventos são salvos localmente primeiro. Quando sua conta Google está conectada, o app tenta criar o evento também no Google Calendar sem bloquear seu planejamento local.',
      action: AiActionDraft(
        type: AiActionType.openRoute,
        title: 'Abrir agenda',
        routeName: AppRoutes.createEvent,
      ),
    ),
    AiKnowledgeEntry(
      keywords: ['notion', 'local', 'table', 'tabela', 'registro'],
      title: 'Registro local e Notion',
      answer:
          'O registro pode usar a tabela local ou campos do Notion. O modo local funciona offline; o Notion usa campos em cache e sincroniza quando possível.',
      action: AiActionDraft(
        type: AiActionType.openRoute,
        title: 'Abrir registro',
        routeName: AppRoutes.studyLog,
      ),
    ),
    AiKnowledgeEntry(
      keywords: ['sync', 'firebase', 'offline', 'sincronizacao', 'nuvem'],
      title: 'Sincronização offline-first',
      answer:
          'O Study Hub salva primeiro no dispositivo e coloca mudanças em uma fila de sincronização. Quando a conexão volta, Firestore recebe os dados sem apagar seu fluxo local.',
    ),
    AiKnowledgeEntry(
      keywords: ['update', 'github', 'atualizacao', 'versao'],
      title: 'Atualizacoes',
      answer:
          'Atualizações são verificadas pelo sistema GitHub updater nas Configurações. Luma não altera esse fluxo; ela apenas ajuda você a encontrar onde verificar novas versões.',
      action: AiActionDraft(
        type: AiActionType.openRoute,
        title: 'Abrir configurações',
        routeName: AppRoutes.settings,
      ),
    ),
  ];

  const AiKnowledgeBase();

  AiKnowledgeEntry? find(String query) {
    final tokens = AiTextUtils.tokens(query).toSet();
    AiKnowledgeEntry? best;
    var bestScore = 0;
    for (final entry in entries) {
      final score = entry.keywords
          .where((keyword) => tokens.contains(AiTextUtils.normalize(keyword)))
          .length;
      if (score > bestScore) {
        best = entry;
        bestScore = score;
      }
    }
    return best;
  }
}
