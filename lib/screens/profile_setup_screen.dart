import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../state/profile_state.dart';
import '../utils/optimized_image_url.dart';
import '../utils/picked_upload_image.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key, this.settingsPage = false});

  final bool settingsPage;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final authService = const AuthService();
  final displayName = TextEditingController();
  final username = TextEditingController();
  final avatarUrl = TextEditingController();
  final homeArea = TextEditingController();
  final bio = TextEditingController();
  bool isPublic = false;
  bool saving = false;
  bool choosingPhoto = false;
  bool initialized = false;
  String originalUsername = '';
  Uint8List? pickedAvatarBytes;
  String pickedAvatarExtension = 'jpg';
  String pickedAvatarContentType = 'image/jpeg';

  @override
  void dispose() {
    displayName.dispose();
    username.dispose();
    avatarUrl.dispose();
    homeArea.dispose();
    bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final user = authService.currentUser;

    profile.whenData((value) {
      if (initialized) return;
      initialized = true;
      if (value == null) {
        displayName.text = user?.userMetadata?['full_name']?.toString() ?? '';
        avatarUrl.text = user?.userMetadata?['avatar_url']?.toString() ?? '';
        username.text = _usernameFromEmail(user?.email ?? '');
        originalUsername = '';
        return;
      }
      displayName.text = value.displayName;
      username.text = value.username;
      originalUsername = value.username.trim().toLowerCase();
      avatarUrl.text = value.avatarUrl ?? '';
      homeArea.text = value.homeArea;
      bio.text = value.bio;
      isPublic = value.isPublic;
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.settingsPage ? 'Edit profile' : 'Profile setup'),
        leading: widget.settingsPage
            ? IconButton(
                tooltip: 'Back to settings',
                onPressed: () => context.go('/settings'),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.settingsPage ? 'Your profile' : 'Set up your profile',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(user?.email ?? 'Sign in to save your profile.'),
              const SizedBox(height: 18),
              if (user == null)
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      await authService.signInWithGoogle(
                        redirectPath: '/profile/setup',
                      );
                    } on AuthException catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error.message)));
                    }
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Continue with Google'),
                )
              else ...[
                Text(
                  'Profile picture',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                _AvatarEditor(
                  imageBytes: pickedAvatarBytes,
                  imageUrl: avatarUrl.text,
                  busy: choosingPhoto,
                  onChoose: _choosePhoto,
                ),
                const SizedBox(height: 18),
                _Field(controller: displayName, label: 'Display name'),
                _Field(controller: username, label: 'Username'),
                _Field(controller: homeArea, label: 'Home area'),
                _Field(controller: bio, label: 'Bio', maxLines: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Public profile'),
                  subtitle: Text(isPublic ? 'Visible to others' : 'Private'),
                  value: isPublic,
                  onChanged: (value) => setState(() => isPublic = value),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: saving ? null : _save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Save profile'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final cleanUsername = username.text.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_]+'),
      '_',
    );
    if (displayName.text.trim().isEmpty || cleanUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name and username are required')),
      );
      return;
    }
    if (cleanUsername.length < 3 || cleanUsername.length > 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username must be 3 to 24 characters')),
      );
      return;
    }

    setState(() => saving = true);
    try {
      if (cleanUsername != originalUsername) {
        final available = await const ProfileService().isUsernameAvailable(
          cleanUsername,
        );
        if (!available) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That username is already reserved')),
          );
          return;
        }
      }
      if (pickedAvatarBytes != null) {
        avatarUrl.text = await const ProfileService().uploadAvatar(
          bytes: pickedAvatarBytes!,
          extension: pickedAvatarExtension,
          contentType: pickedAvatarContentType,
        );
      }
      await const ProfileService().saveProfile(
        displayName: displayName.text,
        username: cleanUsername,
        avatarUrl: avatarUrl.text,
        homeArea: homeArea.text,
        bio: bio.text,
        isPublic: isPublic,
      );
      ref.invalidate(currentProfileProvider);
      originalUsername = cleanUsername;
      username.text = cleanUsername;
      if (!mounted) return;
      context.go(widget.settingsPage ? '/settings' : '/profile');
    } on PostgrestException catch (error) {
      if (!mounted) return;
      final message = error.code == '23505'
          ? 'That username is already reserved'
          : 'Could not save profile: ${error.message}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _choosePhoto() async {
    setState(() => choosingPhoto = true);
    try {
      final photo = await pickUploadImage(imageQuality: 72, maxWidth: 512);
      if (photo == null) return;

      if (!mounted) return;
      setState(() {
        pickedAvatarBytes = photo.bytes;
        pickedAvatarExtension = photo.fileName.contains('.')
            ? photo.fileName.split('.').last.toLowerCase()
            : 'jpg';
        pickedAvatarContentType = photo.contentType;
      });
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open photo: $error')));
    } finally {
      if (mounted) setState(() => choosingPhoto = false);
    }
  }

  String _usernameFromEmail(String email) {
    final name = email.split('@').first;
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
  }
}

class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor({
    required this.imageBytes,
    required this.imageUrl,
    required this.busy,
    required this.onChoose,
  });

  final Uint8List? imageBytes;
  final String imageUrl;
  final bool busy;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object>? image = imageBytes != null
        ? MemoryImage(imageBytes!)
        : imageUrl.trim().isNotEmpty
        ? NetworkImage(optimizedImageUrl(imageUrl, ImageVariant.avatar))
        : null;

    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 54,
                backgroundImage: image,
                child: image == null
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: IconButton.filled(
                  tooltip: 'Change profile picture',
                  onPressed: busy ? null : onChoose,
                  icon: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_camera_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: busy ? null : onChoose,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose profile picture'),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
