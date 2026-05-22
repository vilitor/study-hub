import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/config/app_theme.dart';
import 'package:study_hub/models/study_profile.dart';
import 'package:study_hub/providers/local_study_schema_provider.dart';
import 'package:study_hub/providers/onboarding_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/services/app_haptics.dart';
import 'package:study_hub/services/study_profile_catalog.dart';
import 'package:study_hub/widgets/app_surface.dart';
import 'package:study_hub/widgets/study_profile_preview.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _catalog = const StudyProfileCatalog();
  int _page = 0;
  StudyProfile _selectedProfile = StudyProfileCatalog.profiles.first;
  StudyFocus? _selectedFocus = StudyProfileCatalog.profiles.first.focuses.first;
  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Scaffold(
      backgroundColor: context.colors.scaffoldBase,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.screenPadding,
                spacing.md,
                spacing.screenPadding,
                spacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(child: _ProgressDots(page: _page)),
                  TextButton(
                    onPressed: _isSaving ? null : _skip,
                    child: const Text('Pular'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (value) => setState(() => _page = value),
                children: [
                  _WelcomeStep(onContinue: _next),
                  _ProfileStep(
                    selectedProfile: _selectedProfile,
                    selectedFocus: _selectedFocus,
                    onProfileSelected: _selectProfile,
                    onFocusSelected: (focus) {
                      AppHaptics.selection();
                      setState(() => _selectedFocus = focus);
                    },
                    onContinue: _next,
                  ),
                  _ConfirmStep(
                    profile: _selectedProfile,
                    focus: _selectedFocus,
                    isSaving: _isSaving,
                    onBack: _previous,
                    onFinish: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectProfile(StudyProfile profile) {
    AppHaptics.selection();
    setState(() {
      _selectedProfile = profile;
      _selectedFocus = profile.focuses.isEmpty ? null : profile.focuses.first;
    });
  }

  Future<void> _next() async {
    AppHaptics.selection();
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _previous() async {
    AppHaptics.selection();
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _skip() async {
    setState(() => _isSaving = true);
    try {
      await context.read<OnboardingProvider>().skipOnboarding();
      if (!mounted) return;
      await context.read<SettingsProvider>().loadSettings();
      await _loadSchemaForMain();
    } catch (e) {
      if (!mounted) return;
      _showError('Não foi possível concluir agora. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _finish() async {
    setState(() => _isSaving = true);
    try {
      await context.read<OnboardingProvider>().completeOnboarding(
        profile: _selectedProfile,
        focus: _selectedFocus,
      );
      if (!mounted) return;
      await context.read<SettingsProvider>().loadSettings();
      await _loadSchemaForMain();
      if (!mounted) return;
      final warning = context.read<OnboardingProvider>().lastError;
      if (warning != null && warning.isNotEmpty && mounted) {
        _showError(warning);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Não foi possível concluir agora. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _loadSchemaForMain() async {
    try {
      final subjects = _catalog.starterSubjects(
        profileId: _selectedProfile.id,
        focusId: _selectedFocus?.id,
      );
      await context.read<LocalStudySchemaProvider>().loadFields(
        defaultCategories: subjects,
        useFallbackCategories: false,
        refreshDefaultCategoryOptions: true,
      );
    } on ProviderNotFoundException {
      // Some widget tests mount onboarding without the full app provider tree.
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProgressDots extends StatelessWidget {
  final int page;

  const _ProgressDots({required this.page});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        final active = index == page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(right: 8),
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? context.colors.accent : context.colors.borderStrong,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onContinue;

  const _WelcomeStep({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        spacing.screenPadding,
        spacing.lg,
        spacing.screenPadding,
        spacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('StudyHub', style: context.theme.textTheme.headlineLarge),
          SizedBox(height: spacing.sm),
          Text(
            'Organize estudos, registre progresso, acompanhe metas e mantenha tudo local-first com sincronização quando estiver disponível.',
            style: context.theme.textTheme.bodyLarge,
          ),
          SizedBox(height: spacing.sectionGap),
          AppSurface(
            color: Color.alphaBlend(
              context.colors.accent.withValues(alpha: 0.05),
              context.colors.surfaceElevated,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: context.colors.accent,
                  ),
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: Text(
                    'Luma vai ajudar com o primeiro mapa do app, sem tirar seu controle.',
                    style: context.theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: spacing.sectionGap),
          _ValueTile(
            icon: Icons.event_available_rounded,
            title: 'Planeje',
            body: 'Crie eventos de estudo e conecte ao Google Calendar.',
          ),
          _ValueTile(
            icon: Icons.edit_note_rounded,
            title: 'Registre',
            body:
                'Salve tempo, conteudo e notas em uma tabela local ou Notion.',
          ),
          _ValueTile(
            icon: Icons.auto_graph_rounded,
            title: 'Evolua',
            body: 'Veja desempenho, metas, historico e conquistas.',
          ),
          SizedBox(height: spacing.xxl),
          FilledButton(onPressed: onContinue, child: const Text('Continuar')),
        ],
      ),
    );
  }
}

class _ProfileStep extends StatelessWidget {
  final StudyProfile selectedProfile;
  final StudyFocus? selectedFocus;
  final ValueChanged<StudyProfile> onProfileSelected;
  final ValueChanged<StudyFocus?> onFocusSelected;
  final VoidCallback onContinue;

  const _ProfileStep({
    required this.selectedProfile,
    required this.selectedFocus,
    required this.onProfileSelected,
    required this.onFocusSelected,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        spacing.screenPadding,
        spacing.lg,
        spacing.screenPadding,
        spacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Personalize seu espaco',
            style: context.theme.textTheme.headlineMedium,
          ),
          SizedBox(height: spacing.xs),
          Text(
            'Escolha uma area para criar um ponto de partida. Tudo podera ser editado depois.',
            style: context.theme.textTheme.bodyMedium,
          ),
          SizedBox(height: spacing.lg),
          StudyProfilePreview(profileId: selectedProfile.id),
          SizedBox(height: spacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              return GridView.count(
                crossAxisCount: compact ? 1 : 2,
                childAspectRatio: compact ? 4.2 : 3.3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: spacing.sm,
                crossAxisSpacing: spacing.sm,
                children: StudyProfileCatalog.profiles.map((profile) {
                  return _ProfileCard(
                    profile: profile,
                    selected: profile.id == selectedProfile.id,
                    onTap: () => onProfileSelected(profile),
                  );
                }).toList(),
              );
            },
          ),
          if (selectedProfile.focuses.isNotEmpty) ...[
            SizedBox(height: spacing.lg),
            Text('Foco opcional', style: context.theme.textTheme.titleMedium),
            SizedBox(height: spacing.sm),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: selectedProfile.focuses.map((focus) {
                final selected = selectedFocus?.id == focus.id;
                return ChoiceChip(
                  label: Text(focus.label),
                  selected: selected,
                  onSelected: (_) => onFocusSelected(focus),
                );
              }).toList(),
            ),
          ],
          SizedBox(height: spacing.xxl),
          FilledButton(onPressed: onContinue, child: const Text('Continuar')),
        ],
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  final StudyProfile profile;
  final StudyFocus? focus;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  const _ConfirmStep({
    required this.profile,
    required this.focus,
    required this.isSaving,
    required this.onBack,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final isOther = profile.isOther;
    final subjects = profile.subjectsForFocus(focus?.id);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        spacing.screenPadding,
        spacing.lg,
        spacing.screenPadding,
        spacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pronto para entrar',
            style: context.theme.textTheme.headlineMedium,
          ),
          SizedBox(height: spacing.sm),
          Text(
            isOther
                ? 'Você vai começar com um espaço limpo e intencional para criar suas próprias matérias.'
                : 'Vamos preparar um conjunto inicial para ${focus?.label ?? profile.label}.',
            style: context.theme.textTheme.bodyLarge,
          ),
          SizedBox(height: spacing.sectionGap),
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOther ? 'Começo personalizado' : 'Matérias iniciais',
                  style: context.theme.textTheme.titleMedium,
                ),
                SizedBox(height: spacing.sm),
                Text(
                  'Todas as matérias iniciais são editáveis. A plataforma continua totalmente customizável; isso é apenas um ponto de partida.',
                  style: context.theme.textTheme.bodyMedium,
                ),
                SizedBox(height: spacing.md),
                if (isOther)
                  AppSurface.subtle(
                    padding: EdgeInsets.all(spacing.md),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          color: context.colors.accent,
                        ),
                        SizedBox(width: spacing.sm),
                        Expanded(
                          child: Text(
                            'Depois de entrar, use Agenda > Matérias para adicionar sua primeira matéria manualmente.',
                            style: context.theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Wrap(
                    spacing: spacing.xs,
                    runSpacing: spacing.xs,
                    children: subjects.take(10).map((subject) {
                      return Chip(label: Text(subject));
                    }).toList(),
                  ),
              ],
            ),
          ),
          SizedBox(height: spacing.xxl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isSaving ? null : onBack,
                  child: const Text('Voltar'),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: isSaving ? null : onFinish,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Entrar no app'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _ValueTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.sm),
      child: AppSurface.subtle(
        padding: EdgeInsets.all(context.spacing.md),
        child: Row(
          children: [
            Icon(icon, color: context.colors.accent),
            SizedBox(width: context.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(body, style: context.theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final StudyProfile profile;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(context.spacing.cardRadius),
        onTap: onTap,
        child: AppSurface(
          padding: EdgeInsets.all(context.spacing.md),
          color: selected
              ? Color.alphaBlend(
                  context.colors.accent.withValues(alpha: 0.1),
                  context.colors.surfaceElevated,
                )
              : context.colors.surfaceElevated,
          border: Border.all(
            color: selected
                ? context.colors.accent
                : context.colors.borderSubtle,
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected
                    ? context.colors.accent
                    : context.colors.textDisabled,
              ),
              SizedBox(width: context.spacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      profile.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
