# Where To Add Crags, Walls, And Routes

Right now, type new Victoria crags/routes here:

`lib/data/sample_crags.dart`

That file feeds the map, Crags screen, Feed screen, route filters, and approach lines.

## Add A Crag

Add a new `Crag(...)` inside the `crags = [...]` list.

Important fields:

- `id`: stable lowercase id, like `kingdom-boulders`
- `name`: public crag name
- `province`: `BC`
- `region`: `Victoria`
- `location`: crag GPS point
- `parking`: parking GPS point
- `approachTrail`: how to walk in
- `accessNotes`: access/land-owner/ethics info
- `season`: best season
- `dangerInfo`: closures, loose rock, seepage, hazards
- `walls`: list of walls or boulder sectors

## Add A Wall Or Boulder Sector

Inside a crag, add:

```dart
Wall(
  id: 'crag-name-main-wall',
  name: 'Main Wall',
  routes: [
    // routes go here
  ],
)
```

For bouldering, a `Wall` can mean a sector, like `Warmup Boulders`.

## Add A Route

Inside a wall/sector, add:

```dart
ClimbRoute(
  id: 'unique-route-id',
  name: 'Route Name',
  grade: '5.10a',
  rating: 4.5,
  location: const LatLng(48.00000, -123.00000),
  type: ClimbRouteType.sport,
  pitchType: PitchType.singlePitch,
  angle: 'Vertical',
  heightMeters: 22,
  routeLength: 22,
  ropeLength: 60,
  bolts: 8,
  description: 'What the route is like.',
  approachNotes: 'How to get there from parking.',
  descentNotes: 'Lower, rappel, walk off, or downclimb.',
  dangerInfo: 'Loose rock, bad landing, seepage, closures.',
  gearNotes: 'Draws, rack, pads, anchor gear.',
)
```

Use these route types:

- `ClimbRouteType.sport`
- `ClimbRouteType.trad`
- `ClimbRouteType.boulder`
- `ClimbRouteType.ice`
- `ClimbRouteType.mixed`

Use these pitch types:

- `PitchType.boulder`
- `PitchType.singlePitch`
- `PitchType.multiPitch`

## Later: Real Database

Once Supabase is connected, this same data will move into the tables in:

`supabase/schema.sql`

Until then, `lib/data/sample_crags.dart` is the place to type routes.
