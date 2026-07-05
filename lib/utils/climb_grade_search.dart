final RegExp _boulderGradeQuery = RegExp(r'^v\d+$', caseSensitive: false);
final RegExp _ydsGradeQuery = RegExp(
  r'^5\.(\d{1,2})([abcd])?([+-])?([rx])?$',
  caseSensitive: false,
);

String normalizeClimbGrade(String grade) {
  return grade.trim().replaceFirstMapped(
    RegExp(r'\s*([rx])$', caseSensitive: false),
    (match) => match.group(1)!.toUpperCase(),
  );
}

bool isClimbGradeQuery(String query) {
  final normalized = normalizeClimbGrade(query);
  return _boulderGradeQuery.hasMatch(normalized) ||
      _ydsGradeQuery.hasMatch(normalized);
}

bool climbGradeMatchesQuery(String grade, String query) {
  final normalizedGrade = normalizeClimbGrade(grade).toLowerCase();
  final normalizedQuery = normalizeClimbGrade(query).toLowerCase();

  if (_boulderGradeQuery.hasMatch(normalizedQuery)) {
    return normalizedGrade == normalizedQuery;
  }

  final ydsMatch = _ydsGradeQuery.firstMatch(normalizedQuery);
  if (ydsMatch == null) return false;

  final number = int.parse(ydsMatch.group(1)!);
  final letter = ydsMatch.group(2);
  final modifier = ydsMatch.group(3);
  final protectionRating = ydsMatch.group(4);

  final gradeMatch = _ydsGradeQuery.firstMatch(normalizedGrade);
  if (gradeMatch == null || gradeMatch.group(1) != ydsMatch.group(1)) {
    return false;
  }

  final gradeLetter = gradeMatch.group(2);
  final gradeModifier = gradeMatch.group(3);
  final gradeProtectionRating = gradeMatch.group(4);

  if (protectionRating != null) {
    return normalizedGrade == normalizedQuery;
  }

  if (modifier != gradeModifier) return false;

  if (letter == null && modifier == null && number >= 10 && number <= 15) {
    return gradeLetter == null || RegExp(r'^[a-d]$').hasMatch(gradeLetter);
  }

  return letter == gradeLetter &&
      (gradeProtectionRating == null ||
          RegExp(r'^[rx]$').hasMatch(gradeProtectionRating));
}
