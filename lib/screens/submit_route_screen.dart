import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/crag.dart';
import '../services/database_service.dart';
import '../state/activity_mode_state.dart';
import '../state/catalog_state.dart';
import '../state/admin_state.dart';
import '../state/map_path_state.dart';
import '../state/ski_route_state.dart';
import '../state/trail_library_state.dart';
import '../theme/climb_on_theme.dart';
import '../utils/number_parser.dart';
import '../utils/picked_upload_image.dart';
import '../utils/vancouver_island.dart';
import '../widgets/side_banner_layout.dart';

class SubmitRouteScreen extends ConsumerStatefulWidget {
  const SubmitRouteScreen({super.key});

  @override
  ConsumerState<SubmitRouteScreen> createState() => _SubmitRouteScreenState();
}

class _SubmitRouteScreenState extends ConsumerState<SubmitRouteScreen> {
  final formKey = GlobalKey<FormState>();
  final submitterName = TextEditingController();
  final cragName = TextEditingController();
  final wallName = TextEditingController();
  final routeName = TextEditingController();
  final grade = TextEditingController();
  final bolts = TextEditingController(text: '0');
  final heightMeters = TextEditingController();
  final routeLength = TextEditingController();
  final ropeLength = TextEditingController(text: '60');
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  final description = TextEditingController();
  final approachNotes = TextEditingController();
  final descentNotes = TextEditingController();
  final dangerInfo = TextEditingController();
  final gearNotes = TextEditingController();
  final skiArea = TextEditingController();
  final region = TextEditingController();
  final distanceKm = TextEditingController();
  final elevationGain = TextEditingController();
  final trailheadLatitude = TextEditingController();
  final trailheadLongitude = TextEditingController();
  final season = TextEditingController();

  String routeType = 'sport';
  String pitchType = 'single_pitch';
  String angle = 'Vertical';
  String skiDifficulty = 'Intermediate';
  String aspect = 'North';
  String avalancheTerrain = 'Challenging';
  bool topRope = false;
  bool submitting = false;
  List<PickedUploadImage> photos = [];
  String? selectedCragId;
  String? selectedWallId;

  @override
  void initState() {
    super.initState();
    final trail = ref.read(selectedLibraryTrailProvider);
    if (trail == null || trail.points.isEmpty) return;
    final cragPoint = trail.points.last;
    cragName.text = trail.name;
    wallName.text = 'Main';
    latitude.text = cragPoint.latitude.toStringAsFixed(6);
    longitude.text = cragPoint.longitude.toStringAsFixed(6);
    approachNotes.text =
        'Approach recorded as “${trail.name}” '
        '(${trail.distanceMeters.round()} m).';
  }

  @override
  void dispose() {
    for (final controller in [
      submitterName,
      cragName,
      wallName,
      routeName,
      grade,
      bolts,
      heightMeters,
      routeLength,
      ropeLength,
      latitude,
      longitude,
      description,
      approachNotes,
      descentNotes,
      dangerInfo,
      gearNotes,
      skiArea,
      region,
      distanceKm,
      elevationGain,
      trailheadLatitude,
      trailheadLongitude,
      season,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final mode = ref.watch(activityModeProvider);
    final catalogCrags =
        ref.watch(catalogProvider).valueOrNull ?? const <Crag>[];
    final isAdmin = ref.watch(isMapAdminProvider).valueOrNull == true;
    final isOwnerAccount = ref.watch(isOwnerAccountProvider);
    final isSki = mode == ActivityMode.ski;
    final sourceTrail = ref.watch(selectedLibraryTrailProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SideBannerLayout(
        maxContentWidth: 1180,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final form = Form(
              key: formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  desktop ? 32 : 16,
                  desktop ? 32 : 24,
                  desktop ? 32 : 16,
                  44,
                ),
                children: [
                  if (sourceTrail != null && !isSki) ...[
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: Icon(Icons.route, color: sourceTrail.color),
                        title: Text('Using “${sourceTrail.name}”'),
                        subtitle: const Text(
                          'The saved trail will be included with this new public crag submission.',
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove saved trail',
                          onPressed: () =>
                              ref
                                      .read(
                                        selectedLibraryTrailProvider.notifier,
                                      )
                                      .state =
                                  null,
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    isSki ? 'CONTRIBUTE A WINTER LINE' : 'CONTRIBUTE A CLIMB',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: PacificTerrainColors.cedar,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isSki ? 'Add a ski tour' : 'Add to the field guide',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSki
                        ? 'Share a complete, safety-minded touring objective with the community.'
                        : 'Document a route with the detail another climber needs to arrive prepared.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _SubmissionSection(
                    number: '01',
                    title: isSki ? 'Tour identity' : 'Route identity',
                    subtitle: isSki
                        ? 'Name the objective and establish its character.'
                        : 'Place the route in the correct crag and wall.',
                    child: Column(
                      children: [
                        _Field(controller: submitterName, label: 'Your name'),
                        if (isSki)
                          ..._skiFields()
                        else
                          ..._climbFields(catalogCrags),
                      ],
                    ),
                  ),
                  _SubmissionSection(
                    number: '02',
                    title: 'Pin the location',
                    subtitle:
                        'Accurate coordinates keep visitors on the right trail and out of sensitive areas.',
                    child: Column(
                      children: [
                        if (isSki) ...[
                          _Field(
                            controller: trailheadLatitude,
                            label: 'Trailhead latitude',
                            decimal: true,
                          ),
                          _Field(
                            controller: trailheadLongitude,
                            label: 'Trailhead longitude',
                            decimal: true,
                          ),
                        ] else ...[
                          _Field(
                            controller: latitude,
                            label: 'GPS latitude',
                            decimal: true,
                          ),
                          _Field(
                            controller: longitude,
                            label: 'GPS longitude',
                            decimal: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  _SubmissionSection(
                    number: '03',
                    title: 'Photos & field notes',
                    subtitle:
                        'A clear image and honest notes make this useful—not merely another pin.',
                    child: Column(
                      children: [
                        _RequiredPictureUpload(
                          photos: photos,
                          onPressed: submitting ? null : pickPicture,
                          onRemove: submitting
                              ? null
                              : (index) =>
                                    setState(() => photos.removeAt(index)),
                        ),
                        _Field(
                          controller: description,
                          label: isSki
                              ? 'Tour description'
                              : 'Route description',
                          lines: 3,
                        ),
                        _Field(
                          controller: approachNotes,
                          label: 'Approach notes',
                          lines: 3,
                        ),
                        _Field(
                          controller: descentNotes,
                          label: 'Descent notes',
                          lines: 2,
                        ),
                        _Field(
                          controller: dangerInfo,
                          label: 'Danger/safety notes',
                          lines: 2,
                        ),
                        _Field(
                          controller: gearNotes,
                          label: 'Gear notes',
                          lines: 2,
                        ),
                      ],
                    ),
                  ),
                  _PublishPanel(
                    isAdmin: isAdmin,
                    isOwnerAccount: isOwnerAccount,
                    isSki: isSki,
                    submitting: submitting,
                    onSubmit: () => submit(isAdmin),
                  ),
                ],
              ),
            );

            if (!desktop) return form;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 260, child: _SubmissionAside(isSki: isSki)),
                Expanded(child: form),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _climbFields(List<Crag> crags) {
    Crag? selectedCrag;
    for (final crag in crags) {
      if (crag.id == selectedCragId) selectedCrag = crag;
    }
    final walls = selectedCrag?.walls ?? const [];
    return [
      _ExistingLocationField(
        key: ValueKey('crag-${selectedCragId ?? 'new'}'),
        label: 'Existing crag',
        value: selectedCragId ?? '',
        emptyLabel: 'New crag / not listed',
        options: {for (final crag in crags) crag.id: crag.name},
        onChanged: (id) {
          setState(() {
            selectedCragId = id.isEmpty ? null : id;
            selectedWallId = null;
            wallName.clear();
            if (id.isEmpty) {
              cragName.clear();
            } else {
              final crag = crags.firstWhere((item) => item.id == id);
              cragName.text = crag.name;
            }
          });
        },
      ),
      if (selectedCrag != null)
        _ExistingLocationField(
          key: ValueKey('wall-${selectedWallId ?? 'new'}'),
          label: 'Existing wall',
          value: selectedWallId ?? '',
          emptyLabel: 'New wall / not listed',
          options: {for (final wall in walls) wall.id: wall.name},
          onChanged: (id) {
            setState(() {
              selectedWallId = id.isEmpty ? null : id;
              if (id.isEmpty) {
                wallName.clear();
              } else {
                final wall = walls.firstWhere((item) => item.id == id);
                wallName.text = wall.name;
                latitude.text = wall.location.latitude.toStringAsFixed(6);
                longitude.text = wall.location.longitude.toStringAsFixed(6);
              }
            });
          },
        ),
      _Field(
        controller: cragName,
        label: 'Crag name',
        readOnly: selectedCragId != null,
      ),
      _Field(
        controller: wallName,
        label: 'Wall or sector name',
        readOnly: selectedWallId != null,
      ),
      _Field(controller: routeName, label: 'Route name'),
      _Field(controller: grade, label: 'Grade'),
      _MenuField(
        label: 'Route type',
        value: routeType,
        values: const ['sport', 'trad', 'top_rope', 'boulder', 'mixed', 'ice'],
        onChanged: (value) => setState(() {
          routeType = value;
          if (value == 'top_rope') topRope = true;
        }),
      ),
      _MenuField(
        label: 'Pitch type',
        value: pitchType,
        values: const ['single_pitch', 'multi_pitch', 'boulder'],
        onChanged: (value) => setState(() => pitchType = value),
      ),
      _MenuField(
        label: 'Wall angle',
        value: angle,
        values: const [
          'Slab',
          'Low angle',
          'Vertical',
          'Slightly overhung',
          'Overhung',
          'Roof',
          'Arete',
        ],
        onChanged: (value) => setState(() => angle = value),
      ),
      _Field(controller: bolts, label: 'Bolts', numeric: true),
      _Field(
        controller: heightMeters,
        label: 'Height in meters',
        numeric: true,
      ),
      _Field(
        controller: routeLength,
        label: 'Route length in meters',
        numeric: true,
      ),
      _Field(
        controller: ropeLength,
        label: 'Rope length needed in meters',
        numeric: true,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Top rope access'),
        value: topRope,
        onChanged: (value) => setState(() => topRope = value),
      ),
    ];
  }

  List<Widget> _skiFields() {
    return [
      _Field(controller: routeName, label: 'Tour name'),
      _Field(controller: skiArea, label: 'Ski area or zone'),
      _Field(controller: region, label: 'Region'),
      _MenuField(
        label: 'Difficulty',
        value: skiDifficulty,
        values: const [
          'Beginner',
          'Beginner to Intermediate',
          'Intermediate',
          'Advanced',
          'Expert',
        ],
        onChanged: (value) => setState(() => skiDifficulty = value),
      ),
      _Field(controller: distanceKm, label: 'Distance in km', decimal: true),
      _Field(
        controller: elevationGain,
        label: 'Elevation gain in meters',
        numeric: true,
      ),
      _MenuField(
        label: 'Aspect',
        value: aspect,
        values: const [
          'North',
          'Northeast',
          'East',
          'Southeast',
          'South',
          'Southwest',
          'West',
          'Northwest',
          'Rolling',
        ],
        onChanged: (value) => setState(() => aspect = value),
      ),
      _MenuField(
        label: 'Avalanche terrain',
        value: avalancheTerrain,
        values: const ['Simple', 'Challenging', 'Complex'],
        onChanged: (value) => setState(() => avalancheTerrain = value),
      ),
      _Field(controller: season, label: 'Best season'),
    ];
  }

  Future<void> submit(bool isAdmin) async {
    if (!formKey.currentState!.validate()) return;
    final mode = ref.read(activityModeProvider);
    final sourceTrail = ref.read(selectedLibraryTrailProvider);
    if (mode == ActivityMode.ski) {
      final trailhead = LatLng(
        parseNumberWithUnits(trailheadLatitude.text)!,
        parseNumberWithUnits(trailheadLongitude.text)!,
      );
      if (!isOnVancouverIsland(trailhead)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ski tours must be located on Vancouver Island.'),
          ),
        );
        return;
      }
    }
    final selectedPhotos = [...photos];
    if (selectedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one picture is required.')),
      );
      return;
    }
    final mainPhoto = selectedPhotos.first;
    final uploadPhotos = [
      for (final photo in selectedPhotos)
        UploadPhotoPayload(
          bytes: photo.bytes,
          fileName: photo.fileName,
          contentType: photo.contentType,
        ),
    ];

    setState(() => submitting = true);
    try {
      if (mode == ActivityMode.ski) {
        final skiValues = {
          'submitter_name': submitterName.text.trim(),
          'route_name': routeName.text.trim(),
          'area': skiArea.text.trim(),
          'region': region.text.trim(),
          'difficulty': skiDifficulty,
          'distance_km': parseNumberWithUnits(distanceKm.text)!,
          'elevation_gain_meters': parseWholeNumberWithUnits(
            elevationGain.text,
          )!,
          'aspect': aspect,
          'avalanche_terrain': avalancheTerrain,
          'season': season.text.trim(),
          'latitude': parseNumberWithUnits(trailheadLatitude.text)!,
          'longitude': parseNumberWithUnits(trailheadLongitude.text)!,
          'trailhead_latitude': parseNumberWithUnits(trailheadLatitude.text)!,
          'trailhead_longitude': parseNumberWithUnits(trailheadLongitude.text)!,
          'description': description.text.trim(),
          'approach_notes': approachNotes.text.trim(),
          'descent_notes': descentNotes.text.trim(),
          'danger_info': dangerInfo.text.trim(),
        };
        if (isAdmin) {
          await const DatabaseService().adminSaveSkiRoute(
            values: {
              'route_name': routeName.text.trim(),
              'route_area': skiArea.text.trim(),
              'route_region': region.text.trim(),
              'route_difficulty': skiDifficulty,
              'route_distance_km': skiValues['distance_km'],
              'route_elevation_gain_meters': skiValues['elevation_gain_meters'],
              'route_aspect': aspect,
              'route_avalanche_terrain': avalancheTerrain,
              'route_season': season.text.trim(),
              'route_lat': skiValues['latitude'],
              'route_lng': skiValues['longitude'],
              'route_trailhead_lat': skiValues['trailhead_latitude'],
              'route_trailhead_lng': skiValues['trailhead_longitude'],
              'route_description': description.text.trim(),
              'route_approach_notes': approachNotes.text.trim(),
              'route_descent_notes': descentNotes.text.trim(),
              'route_danger_info': dangerInfo.text.trim(),
              'route_image_url': '',
            },
            imageBytes: mainPhoto.bytes,
            imageName: mainPhoto.fileName,
            imageContentType: mainPhoto.contentType,
          );
          ref.invalidate(skiRouteCatalogProvider);
          ref.invalidate(mapPathCatalogProvider);
        } else {
          await const DatabaseService().submitSkiRouteWithPhotos(
            skiValues,
            photos: uploadPhotos,
          );
        }
      } else {
        final routeValues = <String, Object?>{
          'submitter_name': submitterName.text.trim(),
          'crag_name': cragName.text.trim(),
          'wall_name': wallName.text.trim(),
          'crag_id': selectedCragId,
          'wall_id': selectedWallId,
          'route_name': routeName.text.trim(),
          'grade': grade.text.trim(),
          'route_type': routeType,
          'pitch_type': pitchType,
          'angle': angle,
          'bolts': parseWholeNumberWithUnits(bolts.text)!,
          'height_meters': parseWholeNumberWithUnits(heightMeters.text)!,
          'route_length': parseWholeNumberWithUnits(routeLength.text)!,
          'rope_length': parseWholeNumberWithUnits(ropeLength.text)!,
          'top_rope': topRope,
          'latitude': parseNumberWithUnits(latitude.text)!,
          'longitude': parseNumberWithUnits(longitude.text)!,
          'description': description.text.trim(),
          'approach_notes': approachNotes.text.trim(),
          'descent_notes': descentNotes.text.trim(),
          'danger_info': dangerInfo.text.trim(),
          'gear_notes': gearNotes.text.trim(),
          if (sourceTrail != null && selectedCragId == null) ...{
            'approach_path_points': [
              for (final point in sourceTrail.points)
                [point.latitude, point.longitude],
            ],
            'approach_distance_meters': sourceTrail.distanceMeters,
          },
        };
        if (isAdmin) {
          final service = const DatabaseService();
          final wallId = await service.adminResolveCatalogWall(
            cragId: selectedCragId,
            wallId: selectedWallId,
            cragName: cragName.text.trim(),
            wallName: wallName.text.trim(),
            latitude: parseNumberWithUnits(latitude.text)!,
            longitude: parseNumberWithUnits(longitude.text)!,
            cragWarning: dangerInfo.text.trim(),
          );
          await service.adminSaveCatalogRoute(
            wallId: wallId,
            values: {
              'route_name': routeName.text.trim(),
              'route_grade': grade.text.trim(),
              'route_rating': 0.0,
              'route_type_value': routeType,
              'pitch_type_value': pitchType,
              'route_angle': angle,
              'route_height': routeValues['height_meters'],
              'route_bolts': routeValues['bolts'],
              'route_gear_notes': gearNotes.text.trim(),
              'route_length_value': routeValues['route_length'],
              'route_rope_length': routeValues['rope_length'],
              'route_top_rope': topRope,
              'route_lat': routeValues['latitude'],
              'route_lng': routeValues['longitude'],
              'route_description': description.text.trim(),
              'route_approach_notes': approachNotes.text.trim(),
              'route_descent_notes': descentNotes.text.trim(),
              'route_danger_info': dangerInfo.text.trim(),
              'route_image_url': '',
            },
            imageBytes: mainPhoto.bytes,
            imageName: mainPhoto.fileName,
            imageContentType: mainPhoto.contentType,
          );
          ref.invalidate(catalogProvider);
        } else {
          await const DatabaseService().submitRouteWithPhotos(
            routeValues,
            photos: uploadPhotos,
          );
        }
      }
      if (!mounted) return;
      formKey.currentState!.reset();
      setState(() {
        photos = [];
        selectedCragId = null;
        selectedWallId = null;
      });
      ref.read(selectedLibraryTrailProvider.notifier).state = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mode == ActivityMode.ski
                ? 'Ski tour submitted for review'
                : isAdmin
                ? 'Route published to the map and feed'
                : 'Climb submitted for review',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> pickPicture() async {
    try {
      final pickedPhotos = await pickUploadImages();
      if (pickedPhotos.isEmpty || !mounted) return;
      setState(() {
        photos = [...photos, ...pickedPhotos];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open picture: $error')));
    }
  }
}

class _SubmissionAside extends StatelessWidget {
  const _SubmissionAside({required this.isSki});

  final bool isSki;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PacificTerrainColors.navy,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.landscape_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 34,
            ),
            const SizedBox(height: 22),
            Text(
              isSki ? 'BUILD A GOOD TOUR' : 'BUILD A GOOD ENTRY',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: PacificTerrainColors.sand,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Useful beta is precise, current, and honest about uncertainty.',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 30),
            const _GuideStep(number: '01', label: 'Identity & character'),
            const _GuideStep(number: '02', label: 'Verified location'),
            const _GuideStep(number: '03', label: 'Photos & field notes'),
            const _GuideStep(number: '04', label: 'Community review'),
            const Spacer(),
            Text(
              'Access changes. Re-check closures, land ownership, hazards, and parking before publishing.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white60,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SubmissionSection extends StatelessWidget {
  const _SubmissionSection({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String number;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      number,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(height: 1),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _PublishPanel extends StatelessWidget {
  const _PublishPanel({
    required this.isAdmin,
    required this.isOwnerAccount,
    required this.isSki,
    required this.submitting,
    required this.onSubmit,
  });

  final bool isAdmin;
  final bool isOwnerAccount;
  final bool isSki;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final actionLabel = isAdmin && !isSki
        ? 'Publish route to map and feed'
        : isAdmin && isSki
        ? 'Publish ski tour to map'
        : 'Submit for community review';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PacificTerrainColors.navy, PacificTerrainColors.navySoft],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAdmin ? 'READY TO PUBLISH' : 'READY FOR REVIEW',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: PacificTerrainColors.sand,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAdmin
                ? 'Your administrator account can publish this directly.'
                : 'A complete submission will be checked before it appears publicly.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          if (isOwnerAccount && !isAdmin && !isSki) ...[
            const SizedBox(height: 10),
            const Text(
              'Administrator mode is not enabled for this account.',
              style: TextStyle(color: PacificTerrainColors.sand),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              onPressed: submitting ? null : onSubmit,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_outward),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequiredPictureUpload extends StatelessWidget {
  const _RequiredPictureUpload({
    required this.photos,
    required this.onPressed,
    required this.onRemove,
  });

  final List<PickedUploadImage> photos;
  final VoidCallback? onPressed;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pictures (at least one required)',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (var index = 0; index < photos.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            photos[index].bytes,
                            height: 70,
                            width: 92,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            index == 0
                                ? '${photos[index].fileName} · main image'
                                : photos[index].fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove picture',
                          onPressed: onRemove == null
                              ? null
                              : () => onRemove!(index),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(photos.isEmpty ? 'Upload pictures' : 'Add another'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.numeric = false,
    this.decimal = false,
    this.lines = 1,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final bool numeric;
  final bool decimal;
  final int lines;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        maxLines: lines,
        keyboardType: numeric || decimal
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return 'Required';
          if (numeric && parseWholeNumberWithUnits(text) == null) {
            return 'Enter a number, such as 4 or 4m';
          }
          if (decimal && parseNumberWithUnits(text) == null) {
            return 'Enter a number';
          }
          return null;
        },
      ),
    );
  }
}

class _ExistingLocationField extends StatelessWidget {
  const _ExistingLocationField({
    super.key,
    required this.label,
    required this.value,
    required this.emptyLabel,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String emptyLabel;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: options.containsKey(value) ? value : '',
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem(value: '', child: Text(emptyLabel)),
          for (final entry in options.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _MenuField extends StatelessWidget {
  const _MenuField({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final item in values)
            DropdownMenuItem(
              value: item,
              child: Text(item == 'top_rope' ? 'Top Rope' : item),
            ),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}
