class StudyFocus {
  final String id;
  final String label;
  final String description;
  final List<String> starterSubjects;

  const StudyFocus({
    required this.id,
    required this.label,
    required this.description,
    this.starterSubjects = const [],
  });
}

class StudyProfile {
  final String id;
  final String label;
  final String description;
  final String previewLabel;
  final List<String> starterSubjects;
  final List<StudyFocus> focuses;

  const StudyProfile({
    required this.id,
    required this.label,
    required this.description,
    required this.previewLabel,
    required this.starterSubjects,
    this.focuses = const [],
  });

  bool get isOther => id == 'other';

  List<String> subjectsForFocus(String? focusId) {
    final focus = focuses.where((item) => item.id == focusId).firstOrNull;
    if (focus == null || focus.starterSubjects.isEmpty) {
      return starterSubjects;
    }
    return focus.starterSubjects;
  }
}
