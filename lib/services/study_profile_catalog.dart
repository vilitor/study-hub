import 'package:study_hub/models/study_profile.dart';

class StudyProfileCatalog {
  static const currentOnboardingVersion = 1;

  static const legacyStarterSubjects = [
    'Logic',
    'Computer Networks',
    'Operating Systems',
    'Security',
    'Testing',
    'Architecture',
    'Data Analysis',
    'Statistics',
    'Anatomy',
    'Physiology',
    'Pathology',
    'Pharmacology',
    'Clinical Reasoning',
    'Semiology',
    'Biochemistry',
    'Microbiology',
    'Cognitive Psychology',
    'Behavioral Psychology',
    'Developmental Psychology',
    'Social Psychology',
    'Psychopathology',
    'Neuropsychology',
    'Research Methods',
    'Calculus',
    'Physics',
    'Mechanics',
    'Materials',
    'Thermodynamics',
    'Technical Drawing',
    'Project Management',
    'Constitutional Law',
    'Civil Law',
    'Criminal Law',
    'Administrative Law',
    'Civil Procedure',
    'Legal Theory',
    'Labor Law',
  ];

  static const profiles = [
    StudyProfile(
      id: 'technology',
      label: 'Tecnologia / TI',
      description:
          'Sistemas, infraestrutura, suporte, ferramentas e trabalho digital.',
      previewLabel: 'Sistemas digitais',
      starterSubjects: [
        'Lógica',
        'Redes de Computadores',
        'Sistemas Operacionais',
        'SQL',
        'Segurança',
        'Cloud',
      ],
      focuses: [
        StudyFocus(
          id: 'software_development',
          label: 'Desenvolvimento de Software',
          description: 'Código, web, APIs e engenharia de produto.',
          starterSubjects: [
            'Lógica',
            'Python',
            'HTML',
            'CSS',
            'JavaScript',
            'SQL',
            'APIs',
            'Git',
            'Testes',
            'Arquitetura',
          ],
        ),
        StudyFocus(
          id: 'data_bi',
          label: 'Dados / Análise',
          description: 'Análises, dashboards, modelagem de dados e relatórios.',
          starterSubjects: [
            'SQL',
            'Excel',
            'Power BI',
            'Análise de Dados',
            'Estatística',
            'Python',
            'ETL',
            'Dashboards',
          ],
        ),
        StudyFocus(
          id: 'general_technology',
          label: 'Tecnologia Geral',
          description: 'Um espaço inicial amplo para estudos de tecnologia.',
        ),
      ],
    ),
    StudyProfile(
      id: 'medicine',
      label: 'Medicina',
      description: 'Fundamentos clínicos, ciências da saúde e prática médica.',
      previewLabel: 'Trilha clínica',
      starterSubjects: [
        'Anatomia',
        'Fisiologia',
        'Patologia',
        'Farmacologia',
        'Raciocínio Clínico',
        'Semiologia',
        'Bioquímica',
        'Microbiologia',
      ],
    ),
    StudyProfile(
      id: 'psychology',
      label: 'Psicologia',
      description: 'Comportamento humano, cognição, desenvolvimento e prática.',
      previewLabel: 'Mente e comportamento',
      starterSubjects: [
        'Psicologia Cognitiva',
        'Psicologia Comportamental',
        'Psicologia do Desenvolvimento',
        'Psicologia Social',
        'Psicopatologia',
        'Neuropsicologia',
        'Métodos de Pesquisa',
      ],
    ),
    StudyProfile(
      id: 'engineering',
      label: 'Engenharia',
      description: 'Matemática aplicada, sistemas, projeto e execução técnica.',
      previewLabel: 'Projeto de sistemas',
      starterSubjects: [
        'Cálculo',
        'Física',
        'Mecânica',
        'Materiais',
        'Termodinâmica',
        'Desenho Técnico',
        'Gestão de Projetos',
      ],
    ),
    StudyProfile(
      id: 'architecture',
      label: 'Arquitetura',
      description: 'Projeto, estruturas, cidades e representação técnica.',
      previewLabel: 'Espaço construído',
      starterSubjects: [
        'Ateliê de Projeto',
        'Urbanismo',
        'Estruturas',
        'História da Arquitetura',
        'Desenho Técnico',
        'Materiais',
        'Sustentabilidade',
      ],
    ),
    StudyProfile(
      id: 'law',
      label: 'Direito',
      description: 'Raciocínio jurídico, doutrina, casos e sistemas públicos.',
      previewLabel: 'Estrutura jurídica',
      starterSubjects: [
        'Direito Constitucional',
        'Direito Civil',
        'Direito Penal',
        'Direito Administrativo',
        'Processo Civil',
        'Teoria do Direito',
        'Direito do Trabalho',
      ],
    ),
    StudyProfile(
      id: 'business',
      label: 'Administração / Negócios',
      description: 'Gestão, operações, finanças e estratégia.',
      previewLabel: 'Sistemas de negócio',
      starterSubjects: [
        'Gestão',
        'Finanças',
        'Marketing',
        'Operações',
        'Estratégia',
        'Contabilidade',
        'Economia',
        'Análise de Dados',
      ],
    ),
    StudyProfile(
      id: 'history',
      label: 'História',
      description: 'Processos históricos, fontes, sociedades e períodos.',
      previewLabel: 'Linha histórica',
      starterSubjects: [
        'História Antiga',
        'História Medieval',
        'História Moderna',
        'História Contemporânea',
        'História do Brasil',
        'Historiografia',
        'Análise de Fontes',
      ],
    ),
    StudyProfile(
      id: 'geography',
      label: 'Geografia',
      description: 'Território, ambiente, mapas, sociedade e economia.',
      previewLabel: 'Análise espacial',
      starterSubjects: [
        'Geografia Física',
        'Geografia Humana',
        'Cartografia',
        'Geopolítica',
        'Climatologia',
        'Geografia Urbana',
        'Estudos Ambientais',
      ],
    ),
    StudyProfile(
      id: 'other',
      label: 'Outro',
      description: 'Comece com um espaço limpo e molde seu próprio sistema.',
      previewLabel: 'Espaço personalizado',
      starterSubjects: [],
    ),
  ];

  const StudyProfileCatalog();

  StudyProfile? findProfile(String? id) {
    if (id == null || id.isEmpty) return null;
    return profiles.where((profile) => profile.id == id).firstOrNull;
  }

  StudyFocus? findFocus(StudyProfile profile, String? id) {
    if (id == null || id.isEmpty) return null;
    return profile.focuses.where((focus) => focus.id == id).firstOrNull;
  }

  List<String> starterSubjects({
    required String? profileId,
    required String? focusId,
  }) {
    final profile = findProfile(profileId);
    if (profile == null || profile.isOther) return const [];
    return profile.subjectsForFocus(focusId);
  }

  List<String> allStarterSubjects() {
    final subjects = <String>[];
    final seen = <String>{};
    for (final subject in legacyStarterSubjects) {
      final key = subject.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      subjects.add(subject);
    }
    for (final profile in profiles) {
      for (final subject in profile.starterSubjects) {
        final key = subject.trim().toLowerCase();
        if (key.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        subjects.add(subject);
      }
      for (final focus in profile.focuses) {
        for (final subject in focus.starterSubjects) {
          final key = subject.trim().toLowerCase();
          if (key.isEmpty || seen.contains(key)) continue;
          seen.add(key);
          subjects.add(subject);
        }
      }
    }
    return subjects;
  }
}
