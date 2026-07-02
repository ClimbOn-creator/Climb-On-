import 'package:latlong2/latlong.dart';

import 'comment.dart';
import 'route_photo.dart';

enum ClimbRouteType { sport, trad, boulder, ice, mixed }

enum PitchType { boulder, singlePitch, multiPitch }

class ClimbRoute {
  const ClimbRoute({
    required this.id,
    required this.name,
    required this.grade,
    required this.rating,
    this.location,
    this.description = 'Route details coming soon.',
    this.type = ClimbRouteType.sport,
    this.pitchType = PitchType.singlePitch,
    this.angle = 'Vertical',
    this.heightMeters = 0,
    this.bolts = 0,
    this.gearNotes = 'No gear notes listed yet.',
    this.routeLength = 0,
    this.ropeLength = 60,
    this.topRope = false,
    this.imageUrl =
        'https://images.squarespace-cdn.com/content/v1/53f4116fe4b0fc4173f54f3f/b372d92d-f15e-4605-8a1b-76629df27e73/Main-Wall-2.jpg',
    this.trailheadImageUrl =
        'https://images.unsplash.com/photo-1522163182402-834f871fd851',
    this.approachNotes = 'Approach notes coming soon.',
    this.descentNotes = 'Descent notes coming soon.',
    this.dangerInfo =
        'No known danger notes yet. Confirm local conditions before climbing.',
    this.recentAscents = const [],
    this.photos = const [],
    this.comments = const [],
    this.createdBy = '',
  });

  final String id;
  final String name;
  final String grade;
  final double rating;
  final LatLng? location;
  final String description;
  final ClimbRouteType type;
  final PitchType pitchType;
  final String angle;
  final int heightMeters;
  final int bolts;
  final String gearNotes;
  final int routeLength;
  final int ropeLength;
  final bool topRope;
  final String imageUrl;
  final String trailheadImageUrl;
  final String approachNotes;
  final String descentNotes;
  final String dangerInfo;
  final List<String> recentAscents;
  final List<RoutePhoto> photos;
  final List<Comment> comments;
  final String createdBy;

  String get typeLabel {
    return switch (type) {
      ClimbRouteType.sport => 'Sport',
      ClimbRouteType.trad => 'Trad',
      ClimbRouteType.boulder => 'Boulder',
      ClimbRouteType.ice => 'Ice',
      ClimbRouteType.mixed => 'Mixed',
    };
  }

  String get pitchLabel {
    return switch (pitchType) {
      PitchType.boulder => 'Boulder',
      PitchType.singlePitch => 'Single pitch',
      PitchType.multiPitch => 'Multipitch',
    };
  }
}
