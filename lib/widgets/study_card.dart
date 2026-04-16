import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/utils/date_helpers.dart';
import 'package:study_hub/utils/snackbar_helper.dart';

/// Card de evento de estudo — inspirado na referência visual
/// Card colorido com matéria, título, horário e indicador de sincronização
class StudyCard extends StatefulWidget {
  final StudyEvent event;
  final Color? color;
  final VoidCallback? onTap;
  final int index;

  const StudyCard({
    super.key,
    required this.event,
    this.color,
    this.onTap,
    this.index = 0,
  });

  @override
  State<StudyCard> createState() => _StudyCardState();
}

class _StudyCardState extends State<StudyCard> with SingleTickerProviderStateMixin {
  late AnimationController _wiggleController;
  late Animation<double> _wiggleAnimation;

  @override
  void initState() {
    super.initState();
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );

    _wiggleAnimation = Tween<double>(begin: -0.01, end: 0.01).animate(
      CurvedAnimation(parent: _wiggleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    super.dispose();
  }

  void _showDeleteDialog() async {
    // Começa a balançar (loop infinito indo e voltando)
    _wiggleController.repeat(reverse: true);

    final provider = context.read<StudyEventProvider>();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Evento?'),
        content: Text('Deseja remover "${widget.event.title}" do seu cronograma?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    // Para de balançar
    _wiggleController.stop();
    _wiggleController.reset();

    if (confirm == true) {
      final success = await provider.deleteEvent(widget.event);
      
      if (!success && mounted) {
        // Falha na sincronização do Google
        final forceDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Erro de Sincronização'),
            content: const Text('Não foi possível excluir o evento no Google Calendar. Deseja excluir apenas localmente?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Manter'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Excluir apenas local'),
              ),
            ],
          ),
        );

        if (forceDelete == true) {
          provider.removeEvent(widget.event.id);
          if (mounted) SnackbarHelper.showInfo(context, 'Removido apenas localmente');
        }
      } else if (mounted) {
        SnackbarHelper.showSuccess(context, 'Evento removido com sucesso!');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.color ?? AppColors.getSubjectColor(widget.index);
    final isLightCard = _isLightColor(cardColor);

    return AnimatedBuilder(
      animation: _wiggleAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _wiggleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: _showDeleteDialog,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: cardColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha superior: Matéria + Menu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Nome da matéria
                  Text(
                    widget.event.subject,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isLightCard ? AppColors.textPrimary : Colors.white,
                    ),
                  ),
                  // Ícone de sincronização
                  if (widget.event.syncedWithCalendar)
                    Icon(
                      Icons.cloud_done_rounded,
                      color: isLightCard
                          ? AppColors.textPrimary.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.8),
                      size: 20,
                    ),
                ],
              ),

              const SizedBox(height: 4),

              // Título do evento
              Text(
                widget.event.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: isLightCard
                      ? AppColors.textPrimary.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.9),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Linha inferior: Horário + Duração
              Row(
                children: [
                  // Ícone de relógio + horário
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: isLightCard
                        ? AppColors.textPrimary.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${DateHelpers.formatTime(widget.event.startTime.hour, widget.event.startTime.minute)} - ${DateHelpers.formatTime(widget.event.endTime.hour, widget.event.endTime.minute)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isLightCard
                          ? AppColors.textPrimary.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.85),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Duração
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: isLightCard
                        ? AppColors.textPrimary.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.event.formattedDuration,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isLightCard
                          ? AppColors.textPrimary.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Determina se a cor é clara (para ajustar cor do texto)
  bool _isLightColor(Color color) {
    return color.computeLuminance() > 0.5;
  }
}
