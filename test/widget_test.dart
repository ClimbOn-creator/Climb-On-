import 'package:climb_on/models/climb_route.dart';
import 'package:climb_on/state/climb_log_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Climb log toggles completed routes', () {
    final climbLog = ClimbLogState(persistenceEnabled: false);
    final route = ClimbRoute(
      id: 'vampire-in-the-sun',
      name: 'Vampire in the Sun',
      grade: '5.10a',
      rating: 4.9,
    );

    expect(climbLog.isCompleted(route), isFalse);
    expect(climbLog.sends, isEmpty);

    climbLog.toggleRoute(route);

    expect(climbLog.isCompleted(route), isTrue);
    expect(climbLog.sends.single.routeName, 'Vampire in the Sun');

    climbLog.toggleRoute(route);

    expect(climbLog.isCompleted(route), isFalse);
    expect(climbLog.sends, isEmpty);

    climbLog.dispose();
  });

  test('Climb log stores feed action state', () {
    final climbLog = ClimbLogState(persistenceEnabled: false);
    final route = ClimbRoute(
      id: 'moss-boss',
      name: 'Moss Boss',
      grade: 'V4',
      rating: 4.4,
    );

    climbLog.addAttempt(route, note: 'One-hang burn');
    climbLog.addGradeOpinion(route, 'V5');
    climbLog.addComment(route, 'Left heel beta helped.');
    climbLog.addPhoto(
      route,
      url: 'https://example.com/moss-boss.jpg',
      caption: 'Crux rail',
    );
    climbLog.toggleProject(route);

    expect(climbLog.attemptsFor(route).single.note, 'One-hang burn');
    expect(climbLog.gradeOpinionsFor(route).single.suggestedGrade, 'V5');
    expect(climbLog.commentsFor(route).single.body, 'Left heel beta helped.');
    expect(climbLog.photosFor(route).single.caption, 'Crux rail');
    expect(climbLog.isProject(route), isTrue);

    climbLog.dispose();
  });
}
