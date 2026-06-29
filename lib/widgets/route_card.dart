import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/wall.dart';
import '../services/database_service.dart';
import '../state/admin_state.dart';
import '../state/catalog_state.dart';
import '../state/climb_log_state.dart';
import 'admin_route_editor.dart';

class RouteCard extends ConsumerStatefulWidget {
  const RouteCard({
    super.key,
    required this.route,
    this.expanded = false,
    this.onTap,
  });

  final ClimbRoute route;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  ConsumerState<RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends ConsumerState<RouteCard> {
  final commentController = TextEditingController();
  final gradeController = TextEditingController();
  final photoCaptionController = TextEditingController();
  bool uploadingPhoto = false;
  String? dangerOverride;
  String? imageOverride;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(climbLogProvider).loadPhotosFor(widget.route));
    unawaited(ref.read(climbLogProvider).loadCommentsFor(widget.route));
  }

  @override
  void didUpdateWidget(covariant RouteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.id != widget.route.id) {
      unawaited(ref.read(climbLogProvider).loadPhotosFor(widget.route));
      unawaited(ref.read(climbLogProvider).loadCommentsFor(widget.route));
    }
  }

  @override
  void dispose() {
    commentController.dispose();
    gradeController.dispose();
    photoCaptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final climbLog = ref.watch(climbLogProvider);
    final catalog = ref.watch(catalogProvider).valueOrNull ?? const <Crag>[];
    final routeWall = _findWall(catalog);
    final isAdmin = ref.watch(isMapAdminProvider).valueOrNull == true;

    return AnimatedBuilder(
      animation: climbLog,
      builder: (context, _) {
        final completed = climbLog.isCompleted(widget.route);
        final gradeOpinions = climbLog.gradeOpinionsFor(widget.route);
        final comments = climbLog.commentsFor(widget.route);
        final photos = climbLog.photosFor(widget.route);
        final savedProject = climbLog.isProject(widget.route);

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ExpandableRouteImage(
                    imageUrl: imageOverride ?? widget.route.imageUrl,
                    title: widget.route.name,
                    height: widget.expanded ? 320 : 220,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.route.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        widget.route.grade,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Community rating ${widget.route.rating}/5',
                        ),
                      ),
                      if (completed)
                        Chip(
                          avatar: const Icon(Icons.check_circle, size: 16),
                          label: const Text('Completed'),
                          backgroundColor: const Color(0xFFBCE7F7),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in _routeTags())
                        Chip(
                          avatar: Icon(tag.icon, size: 16),
                          label: Text(tag.label),
                          backgroundColor: tag.color,
                          side: BorderSide(
                            color: tag.color.withValues(alpha: 0.9),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Completed route'),
                    value: completed,
                    onChanged: (_) => climbLog.toggleRoute(widget.route),
                  ),
                  _RouteActions(
                    completed: completed,
                    savedProject: savedProject,
                    commentsCount: comments.length,
                    onCompleted: () => climbLog.toggleRoute(widget.route),
                    onGradeOpinion: () => _showGradeDialog(climbLog),
                    onComment: () => _showCommentDialog(climbLog),
                    onPhoto: uploadingPhoto
                        ? null
                        : isAdmin
                        ? _pickAndReplaceMainPicture
                        : () => _pickAndUploadPhoto(climbLog),
                    photoActionLabel: isAdmin
                        ? 'Replace top picture'
                        : 'Add picture ${photos.length}',
                    onProject: () => climbLog.toggleProject(widget.route),
                    onShare: _shareRoute,
                  ),
                  if (widget.expanded && isAdmin && routeWall != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _openAdminEditor(routeWall),
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Edit every route detail'),
                    ),
                  ],
                  if (widget.expanded) ...[
                    const Divider(),
                    _InfoSection(
                      title: 'Trailhead',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ExpandableRouteImage(
                            imageUrl: widget.route.trailheadImageUrl,
                            title: '${widget.route.name} trailhead',
                            height: 180,
                          ),
                          const SizedBox(height: 10),
                          Text(widget.route.approachNotes),
                        ],
                      ),
                    ),
                    _InfoSection(
                      title: 'Danger Info',
                      child: _AlertText(
                        text: dangerOverride ?? widget.route.dangerInfo,
                        color: Theme.of(context).colorScheme.error,
                        icon: Icons.warning_amber,
                        onEdit:
                            const DatabaseService().currentUserId ==
                                widget.route.createdBy
                            ? _editRouteWarning
                            : null,
                      ),
                    ),
                    _InfoSection(
                      title: 'Gear Notes',
                      child: _AlertText(
                        text: widget.route.gearNotes,
                        color: Theme.of(context).colorScheme.secondary,
                        icon: Icons.construction,
                      ),
                    ),
                    _InfoSection(
                      title: 'Descent',
                      child: _AlertText(
                        text: widget.route.descentNotes,
                        color: Theme.of(context).colorScheme.tertiary,
                        icon: Icons.south,
                      ),
                    ),
                    _InfoSection(
                      title: 'Recent Ascents',
                      child: Column(
                        children: widget.route.recentAscents.isEmpty
                            ? const [
                                ListTile(title: Text('No recent ascents yet.')),
                              ]
                            : widget.route.recentAscents
                                  .map(
                                    (ascent) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.done_all),
                                      title: Text(ascent),
                                    ),
                                  )
                                  .toList(),
                      ),
                    ),
                    _InfoSection(
                      title: 'Your Activity',
                      child: Column(
                        children: [
                          _AttributeRow(
                            label: 'Project',
                            value: savedProject ? 'Saved' : 'Not saved',
                          ),
                          _AttributeRow(
                            label: 'Grade opinion',
                            value: gradeOpinions.isEmpty
                                ? 'Not added'
                                : gradeOpinions.first.suggestedGrade,
                          ),
                        ],
                      ),
                    ),
                    if (photos.isNotEmpty)
                      _InfoSection(
                        title: 'Route Pictures',
                        child: Column(
                          children: [
                            for (final photo in photos)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _RoutePhoto(
                                  photo: photo,
                                  routeName: widget.route.name,
                                  canDelete: climbLog.canDeletePhoto(photo),
                                  onDelete: () =>
                                      _confirmDeletePhoto(climbLog, photo),
                                ),
                              ),
                          ],
                        ),
                      ),
                    _InfoSection(
                      title: 'Route Attributes',
                      child: Column(
                        children: [
                          _AttributeRow(
                            label: 'Type',
                            value: widget.route.typeLabel,
                          ),
                          _AttributeRow(
                            label: 'Pitch style',
                            value: widget.route.pitchLabel,
                          ),
                          _AttributeRow(
                            label: 'Angle',
                            value: widget.route.angle,
                          ),
                          _AttributeRow(
                            label: 'Bolts',
                            value: widget.route.bolts > 0
                                ? '${widget.route.bolts}'
                                : 'Not listed',
                          ),
                          _AttributeRow(
                            label: 'Route length',
                            value: widget.route.routeLength > 0
                                ? '${widget.route.routeLength}m'
                                : 'Not listed',
                          ),
                          _AttributeRow(
                            label: 'Height',
                            value: widget.route.heightMeters > 0
                                ? '${widget.route.heightMeters}m'
                                : 'Not listed',
                          ),
                          _AttributeRow(
                            label: 'Rope',
                            value: '${widget.route.ropeLength}m',
                          ),
                          _AttributeRow(
                            label: 'Top rope',
                            value: widget.route.topRope ? 'Yes' : 'No',
                          ),
                          _AttributeRow(
                            label: 'GPS',
                            value: widget.route.location == null
                                ? 'Not listed'
                                : '${widget.route.location!.latitude.toStringAsFixed(5)}, ${widget.route.location!.longitude.toStringAsFixed(5)}',
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Description'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(widget.route.description),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('Comments (${comments.length})'),
                    children: [
                      if (comments.isEmpty)
                        const ListTile(title: Text('No comments yet.')),
                      ...comments.map(
                        (comment) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundImage: comment.authorAvatarUrl.isEmpty
                                ? null
                                : NetworkImage(comment.authorAvatarUrl),
                            child: comment.authorAvatarUrl.isEmpty
                                ? const Icon(Icons.person_outline)
                                : null,
                          ),
                          title: Text(_commentAuthor(comment)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(comment.body),
                              const SizedBox(height: 3),
                              Text(
                                _commentTime(comment.createdAt),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                          onTap: comment.userId.isEmpty
                              ? null
                              : () => _showCommenterProfile(comment),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: commentController,
                                decoration: const InputDecoration(
                                  hintText: 'Add a comment',
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Post comment',
                              icon: const Icon(Icons.send),
                              onPressed: () => _postComment(climbLog),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareRoute() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            '${widget.route.name} (${widget.route.grade})\n${widget.route.description}',
      ),
    );
  }

  Wall? _findWall(List<Crag> crags) {
    for (final crag in crags) {
      for (final wall in crag.walls) {
        if (wall.routes.any((route) => route.id == widget.route.id)) {
          return wall;
        }
      }
    }
    return null;
  }

  Future<void> _openAdminEditor(Wall wall) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.94,
        child: AdminRouteEditor(wall: wall, route: widget.route),
      ),
    );
    if (saved != true || !mounted) return;
    final refreshed = await ref.refresh(catalogProvider.future);
    for (final crag in refreshed) {
      for (final refreshedWall in crag.walls) {
        for (final route in refreshedWall.routes) {
          if (route.id == widget.route.id) {
            ref.read(focusedRouteProvider.notifier).state = route;
          }
        }
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Route and feed updated.')));
  }

  Future<void> _editRouteWarning() async {
    final controller = TextEditingController(
      text: dangerOverride ?? widget.route.dangerInfo,
    );
    final warning = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit route warning'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Safety warning'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (warning == null || warning.isEmpty || !mounted) return;
    try {
      await const DatabaseService().updateCreatorRouteWarning(
        routeId: widget.route.id,
        warning: warning,
      );
      if (!mounted) return;
      setState(() => dangerOverride = warning);
      ref.invalidate(catalogProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update warning: $error')),
      );
    }
  }

  List<_RouteTag> _routeTags() {
    final route = widget.route;
    final tags = <_RouteTag>[
      _RouteTag(
        label: route.typeLabel,
        icon: Icons.terrain_outlined,
        color: const Color(0xFFD5E9D8),
      ),
      _RouteTag(
        label: route.pitchLabel,
        icon: Icons.layers_outlined,
        color: const Color(0xFFD8E8F4),
      ),
      _RouteTag(
        label: route.angle,
        icon: Icons.architecture_outlined,
        color: const Color(0xFFF3D8CB),
      ),
      if (route.bolts > 0)
        _RouteTag(
          label: '${route.bolts} bolts',
          icon: Icons.hardware,
          color: const Color(0xFFFFE3A6),
        ),
      if (route.routeLength > 0)
        _RouteTag(
          label: '${route.routeLength}m route',
          icon: Icons.straighten,
          color: const Color(0xFFDDEBCF),
        ),
      if (route.heightMeters > 0)
        _RouteTag(
          label: '${route.heightMeters}m tall',
          icon: Icons.height,
          color: const Color(0xFFD6E5EF),
        ),
      if (route.ropeLength > 0)
        _RouteTag(
          label: '${route.ropeLength}m rope',
          icon: Icons.cable,
          color: const Color(0xFFE6DCEF),
        ),
      if (route.type != ClimbRouteType.boulder)
        _RouteTag(
          label: route.topRope ? 'Top rope access' : 'Lead only',
          icon: route.topRope ? Icons.vertical_align_top : Icons.trending_up,
          color: const Color(0xFFF1DCC7),
        ),
    ];

    final seen = <String>{};
    return tags
        .where((tag) {
          final label = tag.label.trim().toLowerCase();
          return label.isNotEmpty && seen.add(label);
        })
        .toList(growable: false);
  }

  Future<void> _showGradeDialog(ClimbLogState climbLog) async {
    gradeController.text = widget.route.grade;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Grade opinion'),
          content: TextField(
            controller: gradeController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Suggested grade',
              prefixIcon: Icon(Icons.grade),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                climbLog.addGradeOpinion(widget.route, gradeController.text);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCommentDialog(ClimbLogState climbLog) async {
    if (!climbLog.canComment) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to comment.')));
      return;
    }
    commentController.text = '';
    final comment = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add comment'),
          content: TextField(
            controller: commentController,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'What should others know?',
              prefixIcon: Icon(Icons.comment),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, commentController.text.trim()),
              child: const Text('Post'),
            ),
          ],
        );
      },
    );
    if (comment == null || comment.isEmpty || !mounted) return;
    commentController.text = comment;
    await _postComment(climbLog);
  }

  Future<void> _postComment(ClimbLogState climbLog) async {
    if (!climbLog.canComment) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to comment.')));
      return;
    }
    final comment = commentController.text.trim();
    if (comment.isEmpty) return;
    try {
      await climbLog.addComment(widget.route, comment);
      commentController.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not post comment: $error')));
    }
  }

  String _commentAuthor(LocalRouteComment comment) {
    if (comment.authorUsername.isNotEmpty) {
      return '@${comment.authorUsername}';
    }
    if (comment.authorDisplayName.isNotEmpty) return comment.authorDisplayName;
    return 'Climber';
  }

  String _commentTime(DateTime createdAt) {
    final local = createdAt.toLocal();
    final elapsed = DateTime.now().difference(local);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final exact =
        '${months[local.month - 1]} ${local.day}, ${local.year} at $hour:$minute $period';
    if (!elapsed.isNegative && elapsed.inMinutes < 1) {
      return 'Just now · $exact';
    }
    if (!elapsed.isNegative && elapsed.inHours < 1) {
      return '${elapsed.inMinutes}m ago · $exact';
    }
    if (!elapsed.isNegative && elapsed.inHours < 24) {
      return '${elapsed.inHours}h ago · $exact';
    }
    return exact;
  }

  void _showCommenterProfile(LocalRouteComment comment) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundImage: comment.authorAvatarUrl.isEmpty
                    ? null
                    : NetworkImage(comment.authorAvatarUrl),
                child: comment.authorAvatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 36)
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                _commentAuthor(comment),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (comment.authorDisplayName.isNotEmpty &&
                  comment.authorUsername.isNotEmpty)
                Text(comment.authorDisplayName),
              if (comment.authorHomeArea.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(comment.authorHomeArea),
              ],
              if (comment.authorBio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(comment.authorBio, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(ClimbLogState climbLog) async {
    if (!climbLog.canUploadPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to add a route picture.')),
      );
      return;
    }

    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 2400,
      );
      if (image == null || !mounted) return;

      final caption = await _askForPhotoCaption();
      if (caption == null || !mounted) return;

      setState(() => uploadingPhoto = true);
      final extension = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : 'jpg';
      await climbLog.uploadPhoto(
        widget.route,
        bytes: await image.readAsBytes(),
        fileName: image.name,
        contentType: _contentType(extension),
        caption: caption,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Picture added to this route.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add picture: $error')));
    } finally {
      if (mounted) setState(() => uploadingPhoto = false);
    }
  }

  Future<void> _pickAndReplaceMainPicture() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 2400,
      );
      if (image == null || !mounted) return;
      setState(() => uploadingPhoto = true);
      final extension = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : 'jpg';
      final imageUrl = await const DatabaseService().adminReplaceRouteImage(
        routeId: widget.route.id,
        imageBytes: await image.readAsBytes(),
        imageName: image.name,
        imageContentType: _contentType(extension),
      );
      if (!mounted) return;
      setState(() => imageOverride = imageUrl);
      ref.invalidate(catalogProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Top route picture replaced.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not replace picture: $error')),
      );
    } finally {
      if (mounted) setState(() => uploadingPhoto = false);
    }
  }

  Future<String?> _askForPhotoCaption() async {
    photoCaptionController.text = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add a caption'),
          content: TextField(
            controller: photoCaptionController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Caption (optional)',
              prefixIcon: Icon(Icons.short_text),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, photoCaptionController.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeletePhoto(
    ClimbLogState climbLog,
    LocalRoutePhoto photo,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove picture?'),
        content: const Text(
          'This removes the picture from the route for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await climbLog.removePhoto(photo);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove picture: $error')),
      );
    }
  }

  String _contentType(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/jpeg',
    };
  }
}

class _RouteActions extends StatelessWidget {
  const _RouteActions({
    required this.completed,
    required this.savedProject,
    required this.commentsCount,
    required this.onCompleted,
    required this.onGradeOpinion,
    required this.onComment,
    required this.onPhoto,
    required this.photoActionLabel,
    required this.onProject,
    required this.onShare,
  });

  final bool completed;
  final bool savedProject;
  final int commentsCount;
  final VoidCallback onCompleted;
  final VoidCallback onGradeOpinion;
  final VoidCallback onComment;
  final VoidCallback? onPhoto;
  final String photoActionLabel;
  final VoidCallback onProject;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          avatar: Icon(completed ? Icons.check_circle : Icons.done, size: 18),
          label: Text(completed ? 'Sent' : 'Mark sent'),
          backgroundColor: const Color(0xFFCDE8D2),
          onPressed: onCompleted,
        ),
        ActionChip(
          avatar: const Icon(Icons.grade, size: 18),
          label: const Text('Grade'),
          backgroundColor: const Color(0xFFD3E7F5),
          onPressed: onGradeOpinion,
        ),
        ActionChip(
          avatar: const Icon(Icons.comment, size: 18),
          label: Text('Comment $commentsCount'),
          backgroundColor: const Color(0xFFF3D7CA),
          onPressed: onComment,
        ),
        ActionChip(
          avatar: onPhoto == null
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: Text(onPhoto == null ? 'Updating picture' : photoActionLabel),
          backgroundColor: const Color(0xFFE5DCF0),
          onPressed: onPhoto,
        ),
        ActionChip(
          avatar: Icon(
            savedProject ? Icons.bookmark : Icons.bookmark_border,
            size: 18,
          ),
          label: Text(savedProject ? 'Project' : 'Save'),
          backgroundColor: const Color(0xFFFFE2A3),
          onPressed: onProject,
        ),
        ActionChip(
          avatar: const Icon(Icons.ios_share, size: 18),
          label: const Text('Share'),
          backgroundColor: const Color(0xFFD1E9E7),
          onPressed: onShare,
        ),
      ],
    );
  }
}

class _RoutePhoto extends StatelessWidget {
  const _RoutePhoto({
    required this.photo,
    required this.routeName,
    required this.canDelete,
    required this.onDelete,
  });

  final LocalRoutePhoto photo;
  final String routeName;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _ExpandableRouteImage(
          imageUrl: photo.url,
          title: photo.caption.isEmpty ? routeName : photo.caption,
          height: 180,
        ),
        if (canDelete)
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(
              tooltip: 'Remove your picture',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.68),
                foregroundColor: Colors.white,
              ),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
      ],
    );
  }
}

class _RouteTag {
  const _RouteTag({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class _AlertText extends StatelessWidget {
  const _AlertText({
    required this.text,
    required this.color,
    required this.icon,
    this.onEdit,
  });

  final String text;
  final Color color;
  final IconData icon;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
            if (onEdit != null)
              IconButton(
                tooltip: 'Edit warning',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableRouteImage extends StatelessWidget {
  const _ExpandableRouteImage({
    required this.imageUrl,
    required this.title,
    required this.height,
  });

  final String imageUrl;
  final String title;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: const Color(0xFFE8E5D9),
        child: InkWell(
          onTap: () => _openImage(context),
          child: Stack(
            children: [
              SizedBox(
                height: height,
                width: double.infinity,
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.open_in_full,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    child: Image.network(imageUrl, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 12,
                  right: 72,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 4,
                  child: IconButton(
                    tooltip: 'Close image',
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _AttributeRow extends StatelessWidget {
  const _AttributeRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}
