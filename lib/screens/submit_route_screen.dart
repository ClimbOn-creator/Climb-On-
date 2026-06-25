import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/database_service.dart';
import '../state/activity_mode_state.dart';

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
  final photoUrl = TextEditingController();
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
      photoUrl,
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
    final showTitleBar = MediaQuery.sizeOf(context).width >= 1024;
    final mode = ref.watch(activityModeProvider);
    final isSki = mode == ActivityMode.ski;

    return Scaffold(
      appBar: showTitleBar
          ? AppBar(title: Text(isSki ? 'Add ski tour' : 'Add climb'))
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  isSki ? 'Add a ski tour' : 'Add a climb',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _Field(controller: submitterName, label: 'Your name'),
                if (isSki) ..._skiFields() else ..._climbFields(),
                _Field(
                  controller: latitude,
                  label: isSki ? 'Tour high point latitude' : 'GPS latitude',
                  decimal: true,
                ),
                _Field(
                  controller: longitude,
                  label: isSki ? 'Tour high point longitude' : 'GPS longitude',
                  decimal: true,
                ),
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
                ],
                _Field(controller: photoUrl, label: 'Picture URL'),
                _Field(
                  controller: description,
                  label: isSki ? 'Tour description' : 'Route description',
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
                _Field(controller: gearNotes, label: 'Gear notes', lines: 2),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: submitting ? null : submit,
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: const Text('Submit for review'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _climbFields() {
    return [
      _Field(controller: cragName, label: 'Crag name'),
      _Field(controller: wallName, label: 'Wall or sector name'),
      _Field(controller: routeName, label: 'Route name'),
      _Field(controller: grade, label: 'Grade'),
      _MenuField(
        label: 'Route type',
        value: routeType,
        values: const ['sport', 'trad', 'boulder', 'mixed', 'ice'],
        onChanged: (value) => setState(() => routeType = value),
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

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => submitting = true);
    try {
      final mode = ref.read(activityModeProvider);
      if (mode == ActivityMode.ski) {
        await const DatabaseService().submitSkiRoute({
          'submitter_name': submitterName.text.trim(),
          'route_name': routeName.text.trim(),
          'area': skiArea.text.trim(),
          'region': region.text.trim(),
          'difficulty': skiDifficulty,
          'distance_km': double.parse(distanceKm.text.trim()),
          'elevation_gain_meters': int.parse(elevationGain.text.trim()),
          'aspect': aspect,
          'avalanche_terrain': avalancheTerrain,
          'season': season.text.trim(),
          'latitude': double.parse(latitude.text.trim()),
          'longitude': double.parse(longitude.text.trim()),
          'trailhead_latitude': double.parse(trailheadLatitude.text.trim()),
          'trailhead_longitude': double.parse(trailheadLongitude.text.trim()),
          'image_url': photoUrl.text.trim(),
          'description': description.text.trim(),
          'approach_notes': approachNotes.text.trim(),
          'descent_notes': descentNotes.text.trim(),
          'danger_info': dangerInfo.text.trim(),
        });
      } else {
        await const DatabaseService().submitRoute({
          'submitter_name': submitterName.text.trim(),
          'crag_name': cragName.text.trim(),
          'wall_name': wallName.text.trim(),
          'route_name': routeName.text.trim(),
          'grade': grade.text.trim(),
          'route_type': routeType,
          'pitch_type': pitchType,
          'angle': angle,
          'bolts': int.parse(bolts.text.trim()),
          'height_meters': int.parse(heightMeters.text.trim()),
          'route_length': int.parse(routeLength.text.trim()),
          'rope_length': int.parse(ropeLength.text.trim()),
          'top_rope': topRope,
          'latitude': double.parse(latitude.text.trim()),
          'longitude': double.parse(longitude.text.trim()),
          'photo_url': photoUrl.text.trim(),
          'description': description.text.trim(),
          'approach_notes': approachNotes.text.trim(),
          'descent_notes': descentNotes.text.trim(),
          'danger_info': dangerInfo.text.trim(),
          'gear_notes': gearNotes.text.trim(),
        });
      }
      if (!mounted) return;
      formKey.currentState!.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mode == ActivityMode.ski
                ? 'Ski tour submitted for review'
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
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.numeric = false,
    this.decimal = false,
    this.lines = 1,
  });

  final TextEditingController controller;
  final String label;
  final bool numeric;
  final bool decimal;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: lines,
        keyboardType: numeric || decimal
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return 'Required';
          if (numeric && int.tryParse(text) == null) return 'Enter a number';
          if (decimal && double.tryParse(text) == null) return 'Enter a number';
          return null;
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
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}
