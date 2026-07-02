import 'package:latlong2/latlong.dart';

import '../models/models.dart';

final List<Crag> crags = [
  Crag(
    id: 'chosslandia',
    name: 'Chosslandia',
    province: 'BC',
    region: 'Victoria / UVic',
    location: const LatLng(48.4634, -123.3117),
    parking: const LatLng(48.4634, -123.3117),
    approachTrail:
        'Approximate UVic-area pin. Record or submit the confirmed approach before visiting.',
    accessNotes:
        'Confirm the exact location, land access, parking, and current climbing permission.',
    season: 'Confirm local conditions',
    dangerInfo:
        'New crag entry with an approximate location. Expect loose rock and verify all hazards before climbing.',
    walls: [
      Wall(
        id: 'chosslandia-main',
        name: 'Main',
        location: const LatLng(48.4634, -123.3117),
        routes: const [],
      ),
    ],
  ),
  Crag(
    id: 'mount-macdonald',
    name: 'Mount Macdonald',
    province: 'BC',
    region: 'Victoria',
    location: const LatLng(48.43989, -123.56344),
    parking: const LatLng(48.439309497252744, -123.5600993545882),
    approachTrail: 'Main pullout trail to the cliff band.',
    accessNotes: 'Respect local access and stay on established paths.',
    season: 'Spring through fall',
    dangerInfo: 'Loose gravel after rain. Helmets recommended.',
    walls: [
      Wall(
        id: 'mount-macdonald-main-wall',
        name: 'Main Wall',
        location: const LatLng(48.43990, -123.56346),
        routes: [
          ClimbRoute(
            id: 'vampire-in-the-sun',
            name: 'Vampire in the Sun',
            grade: '5.10a',
            rating: 4.9,
            location: const LatLng(48.43989, -123.56344),
            description: 'A clean Mount Macdonald line with sunny movement.',
            type: ClimbRouteType.sport,
            pitchType: PitchType.singlePitch,
            approachNotes:
                'Park at the Mount Macdonald pullout and follow the orange approach line to Main Wall.',
            descentNotes: 'Lower from anchors.',
            dangerInfo:
                'Loose gravel near the base after rain. Helmets recommended while parties are above.',
            recentAscents: [
              'Maya C. - redpoint - 2 days ago',
              'Will R. - top rope lap - last week',
            ],
            bolts: 10,
            heightMeters: 24,
            routeLength: 24,
            gearNotes: '10 quickdraws plus anchor gear.',
          ),
          ClimbRoute(
            id: 'new-route-for-old-men',
            name: 'New Route For Old Men',
            grade: '5.10c',
            rating: 4.6,
            location: const LatLng(48.43991, -123.56348),
            description: 'Technical climbing with a thoughtful finish.',
            type: ClimbRouteType.sport,
            pitchType: PitchType.singlePitch,
            approachNotes:
                'Same parking as Main Wall. Stay on the main trail until the final short turnoff.',
            descentNotes: 'Lower from chains.',
            dangerInfo:
                'Watch for wet streaks after storms. The upper ledge can collect small stones.',
            recentAscents: [
              'Jules P. - onsight - yesterday',
              'Ari S. - redpoint - 5 days ago',
            ],
            bolts: 9,
            heightMeters: 22,
            routeLength: 22,
            gearNotes: '9 quickdraws plus anchor gear.',
          ),
        ],
      ),
      Wall(
        id: 'mount-macdonald-salamander-wall',
        name: 'Salamander Wall',
        location: const LatLng(48.43995, -123.56351),
        routes: [
          ClimbRoute(
            id: 'sexagenarian',
            name: 'Sexagenarian',
            grade: '5.9+',
            rating: 4.2,
            location: const LatLng(48.43995, -123.56351),
            description: 'Friendly grade, good position, and a fun upper half.',
            type: ClimbRouteType.trad,
            pitchType: PitchType.singlePitch,
            approachNotes:
                'From parking, take the main approach, then trend left toward Salamander Wall.',
            descentNotes: 'Lower from anchors.',
            dangerInfo:
                'Base can be muddy. Give space to other parties on the narrow staging area.',
            recentAscents: [
              'Noah T. - flash - 3 days ago',
              'Sam K. - lead - 2 weeks ago',
            ],
            bolts: 8,
            heightMeters: 20,
            routeLength: 20,
            gearNotes: '8 quickdraws plus anchor gear.',
          ),
        ],
      ),
      Wall(
        id: 'mount-macdonald-boulder-field',
        name: 'Boulder Field',
        location: const LatLng(48.43983, -123.56322),
        routes: [
          ClimbRoute(
            id: 'moss-boss',
            name: 'Moss Boss',
            grade: 'V4',
            rating: 4.4,
            location: const LatLng(48.43983, -123.56322),
            description:
                'Powerful compression climbing on a compact bloc near the approach trail.',
            type: ClimbRouteType.boulder,
            pitchType: PitchType.boulder,
            angle: 'Overhung',
            heightMeters: 4,
            routeLength: 4,
            ropeLength: 0,
            approachNotes:
                'From the parking pullout, stay low and cut right before Main Wall.',
            descentNotes: 'Downclimb the slabby back side.',
            dangerInfo: 'Pads and spotters recommended. Landing is uneven.',
            recentAscents: [
              'Kai N. - send - yesterday',
              'Rae S. - session - 4 days ago',
            ],
            gearNotes: 'Two pads minimum.',
          ),
        ],
      ),
      Wall(
        id: 'mount-macdonald-upper-buttress',
        name: 'Upper Buttress',
        location: const LatLng(48.44005, -123.56362),
        routes: [
          ClimbRoute(
            id: 'cedar-staircase',
            name: 'Cedar Staircase',
            grade: '5.8',
            rating: 4.5,
            location: const LatLng(48.44005, -123.56362),
            description:
                'Moderate multipitch climbing with a scenic finish above the trees.',
            type: ClimbRouteType.trad,
            pitchType: PitchType.multiPitch,
            angle: 'Low angle',
            heightMeters: 72,
            routeLength: 72,
            ropeLength: 60,
            approachNotes:
                'Continue past Main Wall and scramble up to the Upper Buttress base.',
            descentNotes: 'Walk off climber left on the marked descent trail.',
            dangerInfo:
                'Route finding matters. Avoid parties above you on loose ledges.',
            recentAscents: [
              'Morgan P. - 3 pitches - last weekend',
              'Theo L. - team ascent - 2 weeks ago',
            ],
            gearNotes: 'Light rack to #2, nuts, alpine draws.',
          ),
        ],
      ),
    ],
  ),
  Crag(
    id: 'mount-wells',
    name: 'Mount Wells',
    province: 'BC',
    region: 'Victoria',
    location: const LatLng(48.43912, -123.5599),
    parking: const LatLng(48.439309497252744, -123.5600993545882),
    approachTrail: 'Shared parking, then low trail east to the North Face.',
    accessNotes: 'Stay on durable surfaces and avoid blocking the pullout.',
    season: 'Spring through fall',
    dangerInfo: 'Can seep after rain. Inspect rock quality before leading.',
    walls: [
      Wall(
        id: 'mount-wells-north-face',
        name: 'North Face',
        location: const LatLng(48.43912, -123.5599),
        routes: [
          ClimbRoute(
            id: 'old-mans-route',
            name: "Old Man's Route",
            grade: '5.8',
            rating: 4.0,
            location: const LatLng(48.43912, -123.5599),
            description: 'Approachable climbing on the North Face.',
            type: ClimbRouteType.trad,
            pitchType: PitchType.singlePitch,
            approachNotes:
                'From the shared parking, follow the low trail east to the North Face.',
            descentNotes: 'Lower from fixed anchors.',
            dangerInfo:
                'Check rock quality near the first bolt. Avoid climbing during heavy seepage.',
            recentAscents: [
              'Priya M. - lead - 4 days ago',
              'Ben L. - top rope - last week',
            ],
            bolts: 7,
            heightMeters: 18,
            routeLength: 18,
            gearNotes: '7 quickdraws plus anchor gear.',
          ),
        ],
      ),
    ],
  ),
];
