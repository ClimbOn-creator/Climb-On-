final RegExp _boulderGradeQuery = RegExp(r'^v\d+$', caseSensitive: false);
final RegExp _ydsGradeQuery = RegExp(
  r'^5\.(\d{1,2})([abcd])?([+-])?$',
  caseSensitive: false,
);

bool isClimbGradeQuery(String query) {
  final normalized = query.trim();
  return _boulderGradeQuery.hasMatch(normalized) ||
      _ydsGradeQuery.hasMatch(normalized);
}

bool climbGradeMatchesQuery(String grade, String query) {
  final normalizedGrade = grade.trim().toLowerCase();
  final normalizedQuery = query.trim().toLowerCase();

  if (_boulderGradeQuery.hasMatch(normalizedQuery)) {
    return normalizedGrade == normalizedQuery;
  }

  final ydsMatch = _ydsGradeQuery.firstMatch(normalizedQuery);
  if (ydsMatch == null) return false;

  final number = int.parse(ydsMatch.group(1)!);
  final letter = ydsMatch.group(2);
  final modifier = ydsMatch.group(3);

  if (letter == null && modifier == null && number >= 10 && number <= 15) {
    return RegExp(
      '^5\\.$number(?:[a-d])?\$',
      caseSensitive: false,
    ).hasMatch(normalizedGrade);
  }

  return normalizedGrade == normalizedQuery;
}
