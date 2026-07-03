import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/wall.dart';
import '../services/database_service.dart';
import '../state/admin_state.dart';
import '../state/catalog_state.dart';
import '../state/climb_log_state.dart';
import '../state/social_state.dart';
import '../theme/climb_on_theme.dart';
import '../utils/picked_upload_image.dart';
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
  String? gearOverride;
  String? descentOverride;
  String? imageOverride;
  String? trailheadImageOverride;

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
    final canEditFieldNotes =
        isAdmin ||
        const DatabaseService().currentUserId == widget.route.createdBy;
    final social = ref.watch(socialProvider);

    return AnimatedBuilder(
      animation: climbLog,
      builder: (context, _) {
        final completed = climbLog.isCompleted(widget.route);
        final gradeOpinions = climbLog.gradeOpinionsFor(widget.route);
        final comments = climbLog.commentsFor(widget.route);
        final photos = climbLog.photosFor(widget.route);
        final savedProject = climbLog.isProject(widget.route);
        final friendSends = social.friendSends
            .where((send) => send.routeId == widget.route.id)
            .toList(growable: false);
        final ownSends = climbLog.sends
            .where((send) => send.routeId == widget.route.id)
            .toList(growable: false);

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
                  if (isAdmin) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: uploadingPhoto
                          ? null
                          : _pickAndReplaceMainPicture,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Replace top picture'),
                    ),
                  ],
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
                          avatar: const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: PacificTerrainColors.navy,
                          ),
                          label: const Text('Completed'),
                          backgroundColor: const Color(0xFFBCE7F7),
                          labelStyle: const TextStyle(
                            color: PacificTerrainColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
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
                          avatar: Icon(
                            tag.icon,
                            size: 16,
                            color: PacificTerrainColors.navy,
                          ),
                          label: Text(tag.label),
                          backgroundColor: tag.color,
                          labelStyle: const TextStyle(
                            color: PacificTerrainColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                          side: BorderSide(
                            color: tag.color.withValues(alpha: 0.9),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _RouteActions(
                    completed: completed,
                    savedProject: savedProject,
                    onCompleted: () => climbLog.toggleRoute(widget.route),
                    onGradeOpinion: () => _showGradeDialog(climbLog),
                    onComment: () => _showCommentDialog(climbLog),
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
                    _FadeExpandableText(
                      title: 'Description',
                      text: widget.route.description,
                    ),
                    _ExpandableComments(
                      comments: comments,
                      controller: commentController,
                      onPost: () => _postComment(climbLog),
                      authorFor: _commentAuthor,
                      timeFor: _commentTime,
                      onProfileTap: _showCommenterProfile,
                    ),
                    _InfoSection(
                      title: 'Trailhead',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ExpandableRouteImage(
                            imageUrl:
                                trailheadImageOverride ??
                                widget.route.trailheadImageUrl,
                            title: '${widget.route.name} trailhead',
                            height: 180,
                          ),
                          if (isAdmin) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: uploadingPhoto
                                  ? null
                                  : _pickAndReplaceTrailheadPicture,
                              icon: const Icon(Icons.add_photo_alternate),
                              label: const Text('Replace trailhead picture'),
                            ),
                          ],
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
                        onEdit: canEditFieldNotes
                            ? () => _editRouteNote(_RouteNote.danger)
                            : null,
                      ),
                    ),
                    _InfoSection(
                      title: 'Gear Notes',
                      child: _AlertText(
                        text: gearOverride ?? widget.route.gearNotes,
                        color: Theme.of(context).colorScheme.secondary,
                        icon: Icons.construction,
                        onEdit: canEditFieldNotes
                            ? () => _editRouteNote(_RouteNote.gear)
                            : null,
                      ),
                    ),
                    _InfoSection(
                      title: 'Descent',
                      child: _AlertText(
                        text: descentOverride ?? widget.route.descentNotes,
                        color: Theme.of(context).colorScheme.tertiary,
                        icon: Icons.south,
                        onEdit: canEditFieldNotes
                            ? () => _editRouteNote(_RouteNote.descent)
                            : null,
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
                      title: 'Recent Sends',
                      child: Column(
                        children: friendSends.isEmpty && ownSends.isEmpty
                            ? const [
                                ListTile(title: Text('No recent sends yet.')),
                              ]
                            : [
                                for (final send in ownSends)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.person_outline),
                                    ),
                                    title: Text(
                                      'You · ${send.grade} · ${send.style}',
                                    ),
                                    subtitle: Text(_commentTime(send.sentAt)),
                                  ),
                                for (final send in friendSends)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundImage:
                                          send.user.avatarUrl.isEmpty
                                          ? null
                                          : NetworkImage(send.user.avatarUrl),
                                      child: send.user.avatarUrl.isEmpty
                                          ? const Icon(Icons.person_outline)
                                          : null,
                                    ),
                                    title: Text(
                                      '${send.user.username.isEmpty ? send.user.displayName : '@${send.user.username}'} · ${send.grade} · ${send.style}',
                                    ),
                                    subtitle: Text(_commentTime(send.sentAt)),
                                  ),
                              ],
                      ),
                    ),
                    _InfoSection(
                      title: 'Your Activity',
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Completed route'),
                            value: completed,
                            onChanged: (_) =>
                                climbLog.toggleRoute(widget.route),
                          ),
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
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: uploadingPhoto
                            ? null
                            : () => _pickAndUploadPhoto(climbLog),
                        icon: uploadingPhoto
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          uploadingPhoto
                              ? 'Adding picture'
                              : 'Add recent picture',
                        ),
                      ),
                    ),
                  ],
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

  Future<void> _editRouteNote(_RouteNote note) async {
    final currentDanger = dangerOverride ?? widget.route.dangerInfo;
    final currentGear = gearOverride ?? widget.route.gearNotes;
    final currentDescent = descentOverride ?? widget.route.descentNotes;
    final controller = TextEditingController(
      text: switch (note) {
        _RouteNote.danger => currentDanger,
        _RouteNote.gear => currentGear,
        _RouteNote.descent => currentDescent,
      },
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(note.dialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(labelText: note.fieldLabel),
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
    if (value == null || !mounted) return;
    try {
      await const DatabaseService().updateCreatorRouteFieldNotes(
        routeId: widget.route.id,
        dangerInfo: note == _RouteNote.danger ? value : currentDanger,
        gearNotes: note == _RouteNote.gear ? value : currentGear,
        descentNotes: note == _RouteNote.descent ? value : currentDescent,
      );
      if (!mounted) return;
      setState(() {
        switch (note) {
          case _RouteNote.danger:
            dangerOverride = value;
          case _RouteNote.gear:
            gearOverride = value;
          case _RouteNote.descent:
            descentOverride = value;
        }
      });
      ref.invalidate(catalogProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update route notes: $error')),
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
      if (route.ropeLength > 0)
        _RouteTag(
          label: '${route.ropeLength}m rope',
          icon: Icons.cable,
          color: const Color(0xFFE6DCEF),
        ),
      if (route.topRope && route.type != ClimbRouteType.topRope)
        _RouteTag(
          label: 'Top rope access',
          icon: Icons.vertical_align_top,
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
      final image = await pickUploadImage();
      if (image == null || !mounted) return;

      final caption = await _askForPhotoCaption();
      if (caption == null || !mounted) return;

      setState(() => uploadingPhoto = true);
      await climbLog.uploadPhoto(
        widget.route,
        bytes: image.bytes,
        fileName: image.fileName,
        contentType: image.contentType,
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
      final image = await pickUploadImage();
      if (image == null || !mounted) return;
      setState(() => uploadingPhoto = true);
      final imageUrl = await const DatabaseService().adminReplaceRouteImage(
        routeId: widget.route.id,
        imageBytes: image.bytes,
        imageName: image.fileName,
        imageContentType: image.contentType,
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

  Future<void> _pickAndReplaceTrailheadPicture() async {
    try {
      final image = await pickUploadImage();
      if (image == null || !mounted) return;
      setState(() => uploadingPhoto = true);
      final imageUrl = await const DatabaseService()
          .adminReplaceRouteTrailheadImage(
            routeId: widget.route.id,
            imageBytes: image.bytes,
            imageName: image.fileName,
            imageContentType: image.contentType,
          );
      if (!mounted) return;
      setState(() => trailheadImageOverride = imageUrl);
      ref.invalidate(catalogProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trailhead picture replaced.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not replace trailhead picture: $error')),
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
}

class _FadeExpandableText extends StatefulWidget {
  const _FadeExpandableText({required this.title, required this.text});

  final String title;
  final String text;

  @override
  State<_FadeExpandableText> createState() => _FadeExpandableTextState();
}

class _FadeExpandableTextState extends State<_FadeExpandableText> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final canExpand =
        widget.text.length > 180 || '\n'.allMatches(widget.text).length > 2;
    final text = AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: Text(
        widget.text,
        key: ValueKey(expanded),
        maxLines: expanded || !canExpand ? null : 3,
        overflow: expanded || !canExpand ? null : TextOverflow.clip,
      ),
    );

    return _InfoSection(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canExpand && !expanded)
            ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 0.58, 1],
              ).createShader(bounds),
              child: text,
            )
          else
            text,
          if (canExpand)
            TextButton(
              onPressed: () => setState(() => expanded = !expanded),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Text(expanded ? 'Show less' : 'Read more'),
            ),
        ],
      ),
    );
  }
}

class _ExpandableComments extends StatefulWidget {
  const _ExpandableComments({
    required this.comments,
    required this.controller,
    required this.onPost,
    required this.authorFor,
    required this.timeFor,
    required this.onProfileTap,
  });

  final List<LocalRouteComment> comments;
  final TextEditingController controller;
  final VoidCallback onPost;
  final String Function(LocalRouteComment comment) authorFor;
  final String Function(DateTime createdAt) timeFor;
  final ValueChanged<LocalRouteComment> onProfileTap;

  @override
  State<_ExpandableComments> createState() => _ExpandableCommentsState();
}

class _ExpandableCommentsState extends State<_ExpandableComments> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    const previewCount = 3;
    final hasMore = widget.comments.length > previewCount;
    final visible = expanded
        ? widget.comments
        : widget.comments.take(previewCount).toList(growable: false);

    return _InfoSection(
      title: 'Comments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.comments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('No comments yet.'),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: Column(
              key: ValueKey(expanded),
              children: [
                for (var index = 0; index < visible.length; index++)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: expanded || !hasMore
                        ? 1
                        : switch (index) {
                            0 => 1,
                            1 => 0.68,
                            _ => 0.34,
                          },
                    child: _CommentTile(
                      comment: visible[index],
                      author: widget.authorFor(visible[index]),
                      time: widget.timeFor(visible[index].createdAt),
                      onTap: visible[index].userId.isEmpty
                          ? null
                          : () => widget.onProfileTap(visible[index]),
                    ),
                  ),
              ],
            ),
          ),
          if (hasMore)
            TextButton(
              onPressed: () => setState(() => expanded = !expanded),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Text(expanded ? 'Show less' : 'Read more'),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment',
                    prefixIcon: Icon(Icons.chat_bubble_outline),
                  ),
                ),
              ),
              IconButton.filled(
                tooltip: 'Post comment',
                icon: const Icon(Icons.send),
                onPressed: widget.onPost,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.author,
    required this.time,
    required this.onTap,
  });

  final LocalRouteComment comment;
  final String author;
  final String time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage: comment.authorAvatarUrl.isEmpty
            ? null
            : NetworkImage(comment.authorAvatarUrl),
        child: comment.authorAvatarUrl.isEmpty
            ? const Icon(Icons.person_outline)
            : null,
      ),
      title: Text(author),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comment.body),
          const SizedBox(height: 3),
          Text(time, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _RouteActions extends StatelessWidget {
  const _RouteActions({
    required this.completed,
    required this.savedProject,
    required this.onCompleted,
    required this.onGradeOpinion,
    required this.onComment,
    required this.onProject,
    required this.onShare,
  });

  final bool completed;
  final bool savedProject;
  final VoidCallback onCompleted;
  final VoidCallback onGradeOpinion;
  final VoidCallback onComment;
  final VoidCallback onProject;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          avatar: Icon(
            completed ? Icons.check_circle : Icons.done,
            size: 18,
            color: PacificTerrainColors.navy,
          ),
          label: Text(completed ? 'Sent' : 'Mark sent'),
          backgroundColor: const Color(0xFFCDE8D2),
          labelStyle: const TextStyle(
            color: PacificTerrainColors.navy,
            fontWeight: FontWeight.w700,
          ),
          onPressed: onCompleted,
        ),
        ActionChip(
          avatar: const Icon(
            Icons.grade,
            size: 18,
            color: PacificTerrainColors.navy,
          ),
          label: const Text('Grade'),
          backgroundColor: const Color(0xFFD3E7F5),
          labelStyle: const TextStyle(
            color: PacificTerrainColors.navy,
            fontWeight: FontWeight.w700,
          ),
          onPressed: onGradeOpinion,
        ),
        ActionChip(
          avatar: const Icon(
            Icons.comment,
            size: 18,
            color: PacificTerrainColors.navy,
          ),
          label: const Text('Comment'),
          backgroundColor: const Color(0xFFF3D7CA),
          labelStyle: const TextStyle(
            color: PacificTerrainColors.navy,
            fontWeight: FontWeight.w700,
          ),
          onPressed: onComment,
        ),
        ActionChip(
          avatar: Icon(
            savedProject ? Icons.bookmark : Icons.bookmark_border,
            size: 18,
            color: PacificTerrainColors.navy,
          ),
          label: Text(savedProject ? 'Project' : 'Save'),
          backgroundColor: const Color(0xFFFFE2A3),
          labelStyle: const TextStyle(
            color: PacificTerrainColors.navy,
            fontWeight: FontWeight.w700,
          ),
          onPressed: onProject,
        ),
        ActionChip(
          avatar: const Icon(
            Icons.ios_share,
            size: 18,
            color: PacificTerrainColors.navy,
          ),
          label: const Text('Share'),
          backgroundColor: const Color(0xFFD1E9E7),
          labelStyle: const TextStyle(
            color: PacificTerrainColors.navy,
            fontWeight: FontWeight.w700,
          ),
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

enum _RouteNote { danger, gear, descent }

extension on _RouteNote {
  String get dialogTitle => switch (this) {
    _RouteNote.danger => 'Edit danger info',
    _RouteNote.gear => 'Edit gear notes',
    _RouteNote.descent => 'Edit descent notes',
  };

  String get fieldLabel => switch (this) {
    _RouteNote.danger => 'Danger info',
    _RouteNote.gear => 'Gear notes',
    _RouteNote.descent => 'Descent notes',
  };
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
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => const Icon(Icons.broken_image),
                ),
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
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) =>
                          const Icon(Icons.broken_image, color: Colors.white),
                    ),
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
