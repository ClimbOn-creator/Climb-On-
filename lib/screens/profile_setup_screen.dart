import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../state/profile_state.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

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
  bool initialized = false;

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
        return;
      }
      displayName.text = value.displayName;
      username.text = value.username;
      avatarUrl.text = value.avatarUrl ?? '';
      homeArea.text = value.homeArea;
      bio.text = value.bio;
      isPublic = value.isPublic;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Profile setup')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Set up your profile',
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
                _Field(controller: displayName, label: 'Display name'),
                _Field(controller: username, label: 'Username'),
                _Field(controller: avatarUrl, label: 'Profile picture URL'),
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
    if (displayName.text.trim().isEmpty || username.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name and username are required')),
      );
      return;
    }

    setState(() => saving = true);
    try {
      await const ProfileService().saveProfile(
        displayName: displayName.text,
        username: username.text,
        avatarUrl: avatarUrl.text,
        homeArea: homeArea.text,
        bio: bio.text,
        isPublic: isPublic,
      );
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      context.go('/profile');
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _usernameFromEmail(String email) {
    final name = email.split('@').first;
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
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
