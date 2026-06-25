import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/climb_route.dart';
import '../state/climb_log_state.dart';

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
  final attemptController = TextEditingController();
  final gradeController = TextEditingController();
  final photoUrlController = TextEditingController();
  final photoCaptionController = TextEditingController();

  @override
  void dispose() {
    commentController.dispose();
    attemptController.dispose();
    gradeController.dispose();
    photoUrlController.dispose();
    photoCaptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final climbLog = ref.watch(climbLogProvider);

    return AnimatedBuilder(
      animation: climbLog,
      builder: (context, _) {
        final completed = climbLog.isCompleted(widget.route);
        final attempts = climbLog.attemptsFor(widget.route);
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
                    imageUrl: widget.route.imageUrl,
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
                      Chip(label: Text(widget.route.typeLabel)),
                      Chip(label: Text(widget.route.pitchLabel)),
                      Chip(label: Text(widget.route.angle)),
                      if (widget.route.bolts > 0)
                        Chip(label: Text('${widget.route.bolts} bolts')),
                      if (widget.route.routeLength > 0)
                        Chip(label: Text('${widget.route.routeLength}m')),
                      if (widget.route.heightMeters > 0)
                        Chip(label: Text('${widget.route.heightMeters}m tall')),
                      Chip(label: Text('${widget.route.ropeLength}m rope')),
                      Chip(
                        label: Text(
                          widget.route.topRope
                              ? 'Top rope access'
                              : 'Lead only',
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
                    attemptsCount: attempts.length,
                    commentsCount: comments.length,
                    photosCount: photos.length,
                    onCompleted: () => climbLog.toggleRoute(widget.route),
                    onAttempt: () => _showAttemptDialog(climbLog),
                    onGradeOpinion: () => _showGradeDialog(climbLog),
                    onComment: () => _showCommentDialog(climbLog),
                    onPhoto: () => _showPhotoDialog(climbLog),
                    onProject: () => climbLog.toggleProject(widget.route),
                    onShare: _shareRoute,
                  ),
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
                        text: widget.route.dangerInfo,
                        color: Theme.of(context).colorScheme.error,
                        icon: Icons.warning_amber,
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
                            label: 'Attempts',
                            value: '${attempts.length}',
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
                    if (photos.isNotEmpty)
                      _InfoSection(
                        title: 'Your Photos',
                        child: Column(
                          children: [
                            for (final photo in photos)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ExpandableRouteImage(
                                  imageUrl: photo.url,
                                  title: photo.caption.isEmpty
                                      ? widget.route.name
                                      : photo.caption,
                                  height: 160,
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
                        (comment) => ListTile(title: Text(comment.body)),
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
                              onPressed: () {
                                climbLog.addComment(
                                  widget.route,
                                  commentController.text,
                                );
                                commentController.clear();
                              },
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

  Future<void> _showAttemptDialog(ClimbLogState climbLog) async {
    attemptController.text = '';
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add attempt'),
          content: TextField(
            controller: attemptController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Session note',
              prefixIcon: Icon(Icons.edit_note),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                climbLog.addAttempt(
                  widget.route,
                  note: attemptController.text.trim().isEmpty
                      ? 'Worked the route'
                      : attemptController.text,
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
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
    commentController.text = '';
    await showDialog<void>(
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
              onPressed: () {
                climbLog.addComment(widget.route, commentController.text);
                Navigator.pop(context);
              },
              child: const Text('Post'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPhotoDialog(ClimbLogState climbLog) async {
    photoUrlController.text = widget.route.imageUrl;
    photoCaptionController.text = '';
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add photo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: photoUrlController,
                decoration: const InputDecoration(
                  hintText: 'Photo URL',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: photoCaptionController,
                decoration: const InputDecoration(
                  hintText: 'Caption',
                  prefixIcon: Icon(Icons.short_text),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                climbLog.addPhoto(
                  widget.route,
                  url: photoUrlController.text,
                  caption: photoCaptionController.text,
                );
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class _RouteActions extends StatelessWidget {
  const _RouteActions({
    required this.completed,
    required this.savedProject,
    required this.attemptsCount,
    required this.commentsCount,
    required this.photosCount,
    required this.onCompleted,
    required this.onAttempt,
    required this.onGradeOpinion,
    required this.onComment,
    required this.onPhoto,
    required this.onProject,
    required this.onShare,
  });

  final bool completed;
  final bool savedProject;
  final int attemptsCount;
  final int commentsCount;
  final int photosCount;
  final VoidCallback onCompleted;
  final VoidCallback onAttempt;
  final VoidCallback onGradeOpinion;
  final VoidCallback onComment;
  final VoidCallback onPhoto;
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
          onPressed: onCompleted,
        ),
        ActionChip(
          avatar: const Icon(Icons.add_task, size: 18),
          label: Text('Attempt $attemptsCount'),
          onPressed: onAttempt,
        ),
        ActionChip(
          avatar: const Icon(Icons.grade, size: 18),
          label: const Text('Grade'),
          onPressed: onGradeOpinion,
        ),
        ActionChip(
          avatar: const Icon(Icons.comment, size: 18),
          label: Text('Comment $commentsCount'),
          onPressed: onComment,
        ),
        ActionChip(
          avatar: const Icon(Icons.photo_camera, size: 18),
          label: Text('Photo $photosCount'),
          onPressed: onPhoto,
        ),
        ActionChip(
          avatar: Icon(
            savedProject ? Icons.bookmark : Icons.bookmark_border,
            size: 18,
          ),
          label: Text(savedProject ? 'Project' : 'Save'),
          onPressed: onProject,
        ),
        ActionChip(
          avatar: const Icon(Icons.ios_share, size: 18),
          label: const Text('Share'),
          onPressed: onShare,
        ),
      ],
    );
  }
}

class _AlertText extends StatelessWidget {
  const _AlertText({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;

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
