class OnboardingState {
  final bool onboardingCompleted;
  final int onboardingVersion;
  final DateTime? onboardingCompletedAt;
  final bool profilePersonalizationCompleted;
  final DateTime? profilePersonalizationCompletedAt;
  final bool starterSubjectsSeeded;
  final DateTime? starterSubjectsSeededAt;
  final bool legacyMigrationCompleted;
  final DateTime? legacyMigrationCompletedAt;
  final bool contextualGuideCompleted;
  final String? selectedStudyProfileId;
  final String? selectedStudyProfileLabel;
  final String? selectedStudyFocusId;
  final String? selectedStudyFocusLabel;

  const OnboardingState({
    this.onboardingCompleted = false,
    this.onboardingVersion = 0,
    this.onboardingCompletedAt,
    this.profilePersonalizationCompleted = false,
    this.profilePersonalizationCompletedAt,
    this.starterSubjectsSeeded = false,
    this.starterSubjectsSeededAt,
    this.legacyMigrationCompleted = false,
    this.legacyMigrationCompletedAt,
    this.contextualGuideCompleted = false,
    this.selectedStudyProfileId,
    this.selectedStudyProfileLabel,
    this.selectedStudyFocusId,
    this.selectedStudyFocusLabel,
  });

  bool get shouldShowOnboarding =>
      !legacyMigrationCompleted && !onboardingCompleted;

  OnboardingState copyWith({
    bool? onboardingCompleted,
    int? onboardingVersion,
    DateTime? onboardingCompletedAt,
    bool? profilePersonalizationCompleted,
    DateTime? profilePersonalizationCompletedAt,
    bool? starterSubjectsSeeded,
    DateTime? starterSubjectsSeededAt,
    bool? legacyMigrationCompleted,
    DateTime? legacyMigrationCompletedAt,
    bool? contextualGuideCompleted,
    String? selectedStudyProfileId,
    String? selectedStudyProfileLabel,
    String? selectedStudyFocusId,
    String? selectedStudyFocusLabel,
    bool clearFocus = false,
  }) {
    return OnboardingState(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingVersion: onboardingVersion ?? this.onboardingVersion,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
      profilePersonalizationCompleted:
          profilePersonalizationCompleted ??
          this.profilePersonalizationCompleted,
      profilePersonalizationCompletedAt:
          profilePersonalizationCompletedAt ??
          this.profilePersonalizationCompletedAt,
      starterSubjectsSeeded:
          starterSubjectsSeeded ?? this.starterSubjectsSeeded,
      starterSubjectsSeededAt:
          starterSubjectsSeededAt ?? this.starterSubjectsSeededAt,
      legacyMigrationCompleted:
          legacyMigrationCompleted ?? this.legacyMigrationCompleted,
      legacyMigrationCompletedAt:
          legacyMigrationCompletedAt ?? this.legacyMigrationCompletedAt,
      contextualGuideCompleted:
          contextualGuideCompleted ?? this.contextualGuideCompleted,
      selectedStudyProfileId:
          selectedStudyProfileId ?? this.selectedStudyProfileId,
      selectedStudyProfileLabel:
          selectedStudyProfileLabel ?? this.selectedStudyProfileLabel,
      selectedStudyFocusId: clearFocus
          ? null
          : selectedStudyFocusId ?? this.selectedStudyFocusId,
      selectedStudyFocusLabel: clearFocus
          ? null
          : selectedStudyFocusLabel ?? this.selectedStudyFocusLabel,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'onboardingCompleted': onboardingCompleted,
      'onboardingVersion': onboardingVersion,
      'onboardingCompletedAt': onboardingCompletedAt?.toIso8601String(),
      'profilePersonalizationCompleted': profilePersonalizationCompleted,
      'profilePersonalizationCompletedAt': profilePersonalizationCompletedAt
          ?.toIso8601String(),
      'starterSubjectsSeeded': starterSubjectsSeeded,
      'starterSubjectsSeededAt': starterSubjectsSeededAt?.toIso8601String(),
      'legacyMigrationCompleted': legacyMigrationCompleted,
      'legacyMigrationCompletedAt': legacyMigrationCompletedAt
          ?.toIso8601String(),
      'contextualGuideCompleted': contextualGuideCompleted,
      'selectedStudyProfileId': selectedStudyProfileId,
      'selectedStudyProfileLabel': selectedStudyProfileLabel,
      'selectedStudyFocusId': selectedStudyFocusId,
      'selectedStudyFocusLabel': selectedStudyFocusLabel,
    };
  }

  factory OnboardingState.fromMap(Map<String, dynamic> map) {
    return OnboardingState(
      onboardingCompleted: map['onboardingCompleted'] as bool? ?? false,
      onboardingVersion: (map['onboardingVersion'] as num?)?.toInt() ?? 0,
      onboardingCompletedAt: _date(map['onboardingCompletedAt']),
      profilePersonalizationCompleted:
          map['profilePersonalizationCompleted'] as bool? ?? false,
      profilePersonalizationCompletedAt: _date(
        map['profilePersonalizationCompletedAt'],
      ),
      starterSubjectsSeeded: map['starterSubjectsSeeded'] as bool? ?? false,
      starterSubjectsSeededAt: _date(map['starterSubjectsSeededAt']),
      legacyMigrationCompleted:
          map['legacyMigrationCompleted'] as bool? ?? false,
      legacyMigrationCompletedAt: _date(map['legacyMigrationCompletedAt']),
      contextualGuideCompleted:
          map['contextualGuideCompleted'] as bool? ?? false,
      selectedStudyProfileId: _string(map['selectedStudyProfileId']),
      selectedStudyProfileLabel: _string(map['selectedStudyProfileLabel']),
      selectedStudyFocusId: _string(map['selectedStudyFocusId']),
      selectedStudyFocusLabel: _string(map['selectedStudyFocusLabel']),
    );
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static String? _string(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
