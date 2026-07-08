import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/ar_beta_overlay.dart';
import '../models/climb_route.dart';
import '../models/wall.dart';
import '../services/database_service.dart';
import '../utils/climb_grade_search.dart';
import '../utils/number_parser.dart';
import '../utils/optimized_image_url.dart';
import '../utils/picked_upload_image.dart';

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
  late bool arEnabled;
  Uint8List? imageBytes;
  String imageName = '';
  String imageContentType = 'image/jpeg';
  Uint8List? trailheadImageBytes;
  String trailheadImageName = '';
  String trailheadImageContentType = 'image/jpeg';
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
      'arAsset': TextEditingController(text: route?.arScan?.assetUrl ?? ''),
      'arAnchor': TextEditingController(
        text: route?.arScan?.anchorImageUrl ?? '',
      ),
      'arInstructions': TextEditingController(
        text: route?.arScan?.instructions ?? '',
      ),
      'arScale': TextEditingController(
        text: route?.arScan?.scaleHintMeters?.toString() ?? '',
      ),
      'arPriority': TextEditingController(
        text: '${route?.arScan?.displayPriority ?? 100}',
      ),
      'arBetaOverlay': TextEditingController(
        text: route?.arScan?.betaOverlay == null
            ? ''
            : const JsonEncoder.withIndent(
                '  ',
              ).convert(route!.arScan!.betaOverlay!.toJson()),
      ),
    };
    routeType = switch (route?.type) {
      ClimbRouteType.topRope => 'top_rope',
      ClimbRouteType.deepWaterSolo => 'deep_water_solo',
      final type? => type.name,
      null => 'sport',
    };
    pitchType = switch (route?.pitchType) {
      PitchType.multiPitch => 'multi_pitch',
      PitchType.boulder => 'boulder',
      _ => 'single_pitch',
    };
    angle = route?.angle ?? 'Vertical';
    topRope = route?.topRope ?? false;
    arEnabled = route?.arScan?.enabled ?? false;
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
    final existingTrailheadImage = widget.route?.trailheadImageUrl ?? '';
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
              'top_rope',
              'boulder',
              'deep_water_solo',
              'aid',
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
              title: const Text('Can also be top-roped'),
              value: routeType == 'top_rope' || topRope,
              onChanged: routeType == 'top_rope'
                  ? null
                  : (value) => setState(() => topRope = value),
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
            const SizedBox(height: 6),
            Text('AR', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable AR for this route'),
              subtitle: const Text('Stores links only, not large AR files.'),
              value: arEnabled,
              onChanged: saving
                  ? null
                  : (value) => setState(() => arEnabled = value),
            ),
            _optionalField(
              'arAsset',
              'AR asset URL',
              requiredWhen: arEnabled,
              helperText: 'External .usdz for iPhone, .glb/.gltf for Android.',
            ),
            _optionalField(
              'arAnchor',
              'Anchor/reference image URL',
              helperText: 'Optional photo users can line up at the crag.',
            ),
            _optionalField(
              'arInstructions',
              'AR setup notes',
              lines: 3,
              helperText:
                  'Optional notes like where to stand or what to align.',
            ),
            Row(
              children: [
                Expanded(
                  child: _optionalField(
                    'arScale',
                    'Scale hint (m)',
                    decimal: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _optionalField(
                    'arPriority',
                    'AR priority',
                    integer: true,
                    helperText: 'Lower numbers show first.',
                  ),
                ),
              ],
            ),
            _optionalField(
              'arBetaOverlay',
              'Boulder beta overlay JSON',
              lines: 8,
              helperText:
                  'Tiny hold/line data. Use normalized x/y from 0 to 1.',
              jsonObject: true,
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : _insertBetaOverlayTemplate,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Starter beta map'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : _formatBetaOverlayJson,
                    icon: const Icon(Icons.data_object),
                    label: const Text('Format JSON'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Main picture',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (imageBytes != null)
              Image.memory(imageBytes!, height: 210, fit: BoxFit.cover)
            else if (existingImage.isNotEmpty)
              CachedNetworkImage(
                imageUrl: optimizedImageUrl(existingImage, ImageVariant.card),
                height: 210,
                fit: BoxFit.cover,
                memCacheWidth: 900,
              ),
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
            Text(
              'Trailhead picture',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (trailheadImageBytes != null)
              Image.memory(trailheadImageBytes!, height: 210, fit: BoxFit.cover)
            else if (existingTrailheadImage.isNotEmpty)
              CachedNetworkImage(
                imageUrl: optimizedImageUrl(
                  existingTrailheadImage,
                  ImageVariant.card,
                ),
                height: 210,
                fit: BoxFit.cover,
                memCacheWidth: 900,
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: saving ? null : _pickTrailheadImage,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(
                existingTrailheadImage.isEmpty && trailheadImageBytes == null
                    ? 'Upload trailhead picture'
                    : 'Replace trailhead picture',
              ),
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

  Widget _optionalField(
    String key,
    String label, {
    bool integer = false,
    bool decimal = false,
    int lines = 1,
    bool requiredWhen = false,
    String? helperText,
    bool jsonObject = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: fields[key],
        maxLines: lines,
        keyboardType: integer || decimal
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label, helperText: helperText),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (requiredWhen && text.isEmpty) return 'Required when AR is on';
          if (text.isEmpty) return null;
          if (integer && parseWholeNumberWithUnits(text) == null) {
            return 'Enter a number';
          }
          if (decimal && parseNumberWithUnits(text) == null) {
            return 'Enter a number';
          }
          if (jsonObject) {
            try {
              final decoded = jsonDecode(text);
              if (decoded is! Map) return 'Enter a JSON object';
            } catch (_) {
              return 'Enter valid JSON';
            }
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
              child: Text(routeTypeValueLabel(item)),
            ),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }

  Future<void> _pickImage() async {
    final image = await pickUploadImage(imageQuality: 78, maxWidth: 1600);
    if (image == null || !mounted) return;
    setState(() {
      imageBytes = image.bytes;
      imageName = image.fileName;
      imageContentType = image.contentType;
    });
  }

  Future<void> _pickTrailheadImage() async {
    final image = await pickUploadImage(imageQuality: 76, maxWidth: 1400);
    if (image == null || !mounted) return;
    setState(() {
      trailheadImageBytes = image.bytes;
      trailheadImageName = image.fileName;
      trailheadImageContentType = image.contentType;
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
      final routeId = await const DatabaseService().adminSaveCatalogRoute(
        routeId: widget.route?.id,
        wallId: widget.wall.id,
        values: {
          'route_name': fields['name']!.text.trim(),
          'route_grade': normalizeClimbGrade(fields['grade']!.text),
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
          'route_top_rope': routeType == 'top_rope' || topRope,
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
      if (trailheadImageBytes != null) {
        await const DatabaseService().adminReplaceRouteTrailheadImage(
          routeId: routeId,
          imageBytes: trailheadImageBytes!,
          imageName: trailheadImageName,
          imageContentType: trailheadImageContentType,
        );
      }
      if (arEnabled || widget.route?.arScan != null) {
        await const DatabaseService().adminSaveRouteARScan(
          routeId: routeId,
          enabled: arEnabled,
          assetUrl: arEnabled ? fields['arAsset']!.text : '',
          anchorImageUrl: fields['arAnchor']!.text,
          instructions: fields['arInstructions']!.text,
          scaleHintMeters: fields['arScale']!.text.trim().isEmpty
              ? null
              : parseNumberWithUnits(fields['arScale']!.text),
          displayPriority:
              parseWholeNumberWithUnits(fields['arPriority']!.text) ?? 100,
          betaOverlay: _betaOverlayFromField(),
        );
      }
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

  ARBetaOverlay? _betaOverlayFromField() {
    final raw = fields['arBetaOverlay']!.text.trim();
    if (raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final overlay = ARBetaOverlay.fromJson(Map<String, Object?>.from(decoded));
    return overlay.isNotEmpty ? overlay : null;
  }

  void _insertBetaOverlayTemplate() {
    final referenceImageUrl = fields['arAnchor']!.text.trim().isNotEmpty
        ? fields['arAnchor']!.text.trim()
        : widget.route?.imageUrl.trim() ?? '';
    final overlay = ARBetaOverlay(
      referenceImageUrl: referenceImageUrl,
      holds: const [
        ARBetaPoint(
          x: 0.30,
          y: 0.78,
          type: 'start',
          label: 'LH',
          title: 'Left start hold',
          description: 'Add the exact grip, body position, and first pull.',
        ),
        ARBetaPoint(
          x: 0.43,
          y: 0.76,
          type: 'start',
          label: 'RH',
          title: 'Right start hold',
          description: 'Add matching, opposition, or shoulder beta here.',
        ),
        ARBetaPoint(
          x: 0.52,
          y: 0.58,
          type: 'hand',
          label: '2',
          title: 'Crux hand hold',
          description: 'Add micro beta like thumb catch, hip turn, or timing.',
        ),
        ARBetaPoint(
          x: 0.38,
          y: 0.86,
          type: 'foot',
          label: 'F',
          title: 'Key foot',
          description: 'Add edge/smear placement and body tension notes.',
        ),
        ARBetaPoint(
          x: 0.66,
          y: 0.28,
          type: 'finish',
          label: 'Top',
          title: 'Finish hold',
          description: 'Add the top-out or final hold instruction.',
        ),
      ],
      line: const [
        ARBetaPoint(x: 0.36, y: 0.77),
        ARBetaPoint(x: 0.52, y: 0.58),
        ARBetaPoint(x: 0.66, y: 0.28),
      ],
    );
    fields['arBetaOverlay']!.text = const JsonEncoder.withIndent(
      '  ',
    ).convert(overlay.toJson());
  }

  void _formatBetaOverlayJson() {
    final raw = fields['arBetaOverlay']!.text.trim();
    if (raw.isEmpty) {
      _insertBetaOverlayTemplate();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Expected object');
      final overlay = ARBetaOverlay.fromJson(
        Map<String, Object?>.from(decoded),
      );
      fields['arBetaOverlay']!.text = const JsonEncoder.withIndent(
        '  ',
      ).convert(overlay.toJson());
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beta overlay JSON is not valid: $error')),
      );
    }
  }
}
