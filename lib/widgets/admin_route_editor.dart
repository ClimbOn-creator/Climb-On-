import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/climb_route.dart';
import '../models/wall.dart';
import '../services/database_service.dart';
import '../utils/number_parser.dart';

class AdminRouteEditor extends StatefulWidget {
  const AdminRouteEditor({super.key, required this.wall, this.route});

  final Wall wall;
  final ClimbRoute? route;

  @override
  State<AdminRouteEditor> createState() => _AdminRouteEditorState();
}

class _AdminRouteEditorState extends State<AdminRouteEditor> {
  final formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  late String routeType;
  late String pitchType;
  late String angle;
  late bool topRope;
  Uint8List? imageBytes;
  String imageName = '';
  String imageContentType = 'image/jpeg';
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final route = widget.route;
    fields = {
      'name': TextEditingController(text: route?.name ?? ''),
      'grade': TextEditingController(text: route?.grade ?? ''),
      'rating': TextEditingController(text: '${route?.rating ?? 0}'),
      'height': TextEditingController(text: '${route?.heightMeters ?? 0}'),
      'bolts': TextEditingController(text: '${route?.bolts ?? 0}'),
      'gear': TextEditingController(text: route?.gearNotes ?? ''),
      'length': TextEditingController(text: '${route?.routeLength ?? 0}'),
      'rope': TextEditingController(text: '${route?.ropeLength ?? 60}'),
      'lat': TextEditingController(
        text:
            route?.location?.latitude.toStringAsFixed(6) ??
            widget.wall.location.latitude.toStringAsFixed(6),
      ),
      'lng': TextEditingController(
        text:
            route?.location?.longitude.toStringAsFixed(6) ??
            widget.wall.location.longitude.toStringAsFixed(6),
      ),
      'description': TextEditingController(text: route?.description ?? ''),
      'approach': TextEditingController(text: route?.approachNotes ?? ''),
      'descent': TextEditingController(text: route?.descentNotes ?? ''),
      'danger': TextEditingController(text: route?.dangerInfo ?? ''),
    };
    routeType = route?.type.name ?? 'sport';
    pitchType = switch (route?.pitchType) {
      PitchType.multiPitch => 'multi_pitch',
      PitchType.boulder => 'boulder',
      _ => 'single_pitch',
    };
    angle = route?.angle ?? 'Vertical';
    topRope = route?.topRope ?? false;
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingImage = widget.route?.imageUrl ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.route == null
              ? 'Add route to ${widget.wall.name}'
              : 'Edit route',
        ),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field('name', 'Route name'),
            _field('grade', 'Grade'),
            Row(
              children: [
                Expanded(
                  child: _field('rating', 'Rating (0–5)', decimal: true),
                ),
                const SizedBox(width: 12),
                Expanded(child: _field('bolts', 'Bolts', integer: true)),
              ],
            ),
            _menu('Route type', routeType, const [
              'sport',
              'trad',
              'boulder',
              'ice',
              'mixed',
            ], (value) => setState(() => routeType = value)),
            _menu('Pitch type', pitchType, const [
              'single_pitch',
              'multi_pitch',
              'boulder',
            ], (value) => setState(() => pitchType = value)),
            _menu('Wall angle', angle, const [
              'Slab',
              'Low angle',
              'Vertical',
              'Slightly overhung',
              'Overhung',
              'Roof',
              'Arete',
            ], (value) => setState(() => angle = value)),
            Row(
              children: [
                Expanded(child: _field('height', 'Height (m)', integer: true)),
                const SizedBox(width: 12),
                Expanded(
                  child: _field('length', 'Route length (m)', integer: true),
                ),
              ],
            ),
            _field('rope', 'Rope length (m)', integer: true),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Top-rope access'),
              value: topRope,
              onChanged: (value) => setState(() => topRope = value),
            ),
            Row(
              children: [
                Expanded(child: _field('lat', 'Latitude', decimal: true)),
                const SizedBox(width: 12),
                Expanded(child: _field('lng', 'Longitude', decimal: true)),
              ],
            ),
            _field('description', 'Description', lines: 3),
            _field('approach', 'Approach notes', lines: 3),
            _field('descent', 'Descent notes', lines: 2),
            _field('danger', 'Safety warning', lines: 3),
            _field('gear', 'Gear notes', lines: 2),
            const SizedBox(height: 4),
            Text(
              'Main picture',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (imageBytes != null)
              Image.memory(imageBytes!, height: 210, fit: BoxFit.cover)
            else if (existingImage.isNotEmpty)
              Image.network(existingImage, height: 210, fit: BoxFit.cover),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: saving ? null : _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                existingImage.isEmpty && imageBytes == null
                    ? 'Upload required picture'
                    : 'Replace picture',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'More community pictures can be added from the route page.',
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(
                widget.route == null ? 'Create route' : 'Save every change',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String key,
    String label, {
    bool integer = false,
    bool decimal = false,
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: fields[key],
        maxLines: lines,
        keyboardType: integer || decimal
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return 'Required';
          if (integer && parseWholeNumberWithUnits(text) == null) {
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

  Widget _menu(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final item in values)
            DropdownMenuItem(
              value: item,
              child: Text(item.replaceAll('_', ' ')),
            ),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2400,
    );
    if (image == null || !mounted) return;
    final extension = image.name.contains('.')
        ? image.name.split('.').last.toLowerCase()
        : 'jpg';
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      imageBytes = bytes;
      imageName = image.name;
      imageContentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' || 'heif' => 'image/heic',
        _ => 'image/jpeg',
      };
    });
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    if (widget.route == null && imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload a main picture for the new route.'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await const DatabaseService().adminSaveCatalogRoute(
        routeId: widget.route?.id,
        wallId: widget.wall.id,
        values: {
          'route_name': fields['name']!.text.trim(),
          'route_grade': fields['grade']!.text.trim(),
          'route_rating': parseNumberWithUnits(fields['rating']!.text)!,
          'route_type_value': routeType,
          'pitch_type_value': pitchType,
          'route_angle': angle,
          'route_height': parseWholeNumberWithUnits(fields['height']!.text)!,
          'route_bolts': parseWholeNumberWithUnits(fields['bolts']!.text)!,
          'route_gear_notes': fields['gear']!.text.trim(),
          'route_length_value': parseWholeNumberWithUnits(
            fields['length']!.text,
          )!,
          'route_rope_length': parseWholeNumberWithUnits(fields['rope']!.text)!,
          'route_top_rope': topRope,
          'route_lat': parseNumberWithUnits(fields['lat']!.text)!,
          'route_lng': parseNumberWithUnits(fields['lng']!.text)!,
          'route_description': fields['description']!.text.trim(),
          'route_approach_notes': fields['approach']!.text.trim(),
          'route_descent_notes': fields['descent']!.text.trim(),
          'route_danger_info': fields['danger']!.text.trim(),
          'route_image_url': widget.route?.imageUrl ?? '',
        },
        imageBytes: imageBytes,
        imageName: imageName,
        imageContentType: imageContentType,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save route: $error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
