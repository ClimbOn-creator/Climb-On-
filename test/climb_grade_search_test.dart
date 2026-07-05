import 'package:climb_on/utils/climb_grade_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('boulder grades match exactly', () {
    expect(climbGradeMatchesQuery('V1', 'V1'), isTrue);
    expect(climbGradeMatchesQuery('v1', 'V1'), isTrue);
    expect(climbGradeMatchesQuery('V10', 'V1'), isFalse);
    expect(climbGradeMatchesQuery('V11', 'V1'), isFalse);
  });

  test('base YDS grades from 5.10 through 5.15 include letter grades', () {
    for (final number in [10, 11, 12, 13, 14, 15]) {
      expect(climbGradeMatchesQuery('5.$number', '5.$number'), isTrue);
      for (final letter in ['a', 'b', 'c', 'd']) {
        expect(climbGradeMatchesQuery('5.$number$letter', '5.$number'), isTrue);
      }
    }

    expect(climbGradeMatchesQuery('5.11a', '5.10'), isFalse);
    expect(climbGradeMatchesQuery('5.10a', '5.10a'), isTrue);
    expect(climbGradeMatchesQuery('5.10b', '5.10a'), isFalse);
  });

  test('recognizes climbing grade queries', () {
    expect(isClimbGradeQuery(' V1 '), isTrue);
    expect(isClimbGradeQuery('5.10'), isTrue);
    expect(isClimbGradeQuery('5.10c'), isTrue);
    expect(isClimbGradeQuery('5.13 R'), isTrue);
    expect(isClimbGradeQuery('5.13X'), isTrue);
    expect(isClimbGradeQuery('sport'), isFalse);
  });

  test('R and X protection ratings ignore the preceding space', () {
    expect(normalizeClimbGrade('5.13 R'), '5.13R');
    expect(normalizeClimbGrade('5.13r'), '5.13R');
    expect(climbGradeMatchesQuery('5.13R', '5.13 R'), isTrue);
    expect(climbGradeMatchesQuery('5.13 R', '5.13R'), isTrue);
    expect(climbGradeMatchesQuery('5.13X', '5.13 X'), isTrue);
    expect(climbGradeMatchesQuery('5.13X', '5.13R'), isFalse);
  });

  test('base grades include their R and X protection variants', () {
    expect(climbGradeMatchesQuery('5.13R', '5.13'), isTrue);
    expect(climbGradeMatchesQuery('5.13 X', '5.13'), isTrue);
    expect(climbGradeMatchesQuery('5.13a R', '5.13'), isTrue);
    expect(climbGradeMatchesQuery('5.13aX', '5.13a'), isTrue);
    expect(climbGradeMatchesQuery('5.14R', '5.13'), isFalse);
  });
}
