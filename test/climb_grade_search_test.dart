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
    expect(isClimbGradeQuery('sport'), isFalse);
  });
}
