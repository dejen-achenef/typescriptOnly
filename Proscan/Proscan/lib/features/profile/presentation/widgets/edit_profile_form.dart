// features/profile/presentation/widgets/edit_profile_form.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:thyscan/features/profile/core/services/profile_service.dart';
import 'package:thyscan/features/profile/presentation/providers/profile_provider.dart';

/// Form widget for editing profile.
///
/// Handles:
/// - Full name editing
/// - Avatar image picking (gallery/camera)
/// - Avatar upload
/// - Profile update
///
/// **Usage:**
/// ```dart
/// EditProfileForm(
///   onSaved: () => Navigator.pop(),
/// )
/// ```
class EditProfileForm extends ConsumerStatefulWidget {
  const EditProfileForm({
    super.key,
    this.onSaved,
  });

  /// Callback called when profile is successfully saved.
  final VoidCallback? onSaved;

  @override
  ConsumerState<EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  String? _selectedImagePath;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    // Load current profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profileState = ref.read(profileProvider);
    if (profileState.profile != null) {
      final profile = profileState.profile!;
      _fullNameController.text = profile.fullName ?? '';
      _currentAvatarUrl = profile.avatarUrl;
      if (mounted) setState(() {});
    } else {
      // Wait for profile to load
      ref.listen<ProfileState>(
        profileProvider,
        (previous, next) {
          if (next.profile != null && previous?.profile == null) {
            final profile = next.profile!;
            _fullNameController.text = profile.fullName ?? '';
            _currentAvatarUrl = profile.avatarUrl;
            if (mounted) setState(() {});
          }
        },
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final imagePath = await ProfileService.instance.pickImage(source);
      if (imagePath != null && mounted) {
        setState(() {
          _selectedImagePath = imagePath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final notifier = ref.read(profileProvider.notifier);
    final fullName = _fullNameController.text.trim();

    try {
      // If image was selected, upload it first
      if (_selectedImagePath != null) {
        await notifier.uploadAndUpdateAvatar(_selectedImagePath!);
      }

      // Update profile with new full name
      if (fullName.isNotEmpty) {
        await notifier.updateProfile(fullName: fullName);
      } else if (_selectedImagePath == null) {
        // Only update if we have changes
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No changes to save'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final isLoading = profileState.isLoading || profileState.isUploadingAvatar;
    final hasError = profileState.hasError;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Avatar picker section
          _buildAvatarSection(profileState),
          const SizedBox(height: 24),

          // Full name field
          TextFormField(
            controller: _fullNameController,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: 'Full Name',
              hintText: 'Enter your full name',
              border: const OutlineInputBorder(),
              errorText: hasError ? profileState.error : null,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Full name is required';
              }
              if (value.trim().length < 2) {
                return 'Full name must be at least 2 characters';
              }
              if (value.trim().length > 255) {
                return 'Full name must not exceed 255 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Error message display
          if (hasError && !isLoading)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      profileState.error ?? 'An error occurred',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (isLoading || hasError) ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(ProfileState profileState) {
    final imagePath = _selectedImagePath;
    final avatarUrl = imagePath != null
        ? null
        : (_currentAvatarUrl ?? profileState.profile?.avatarUrl);
    final isLoading = profileState.isUploadingAvatar;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: GestureDetector(
        onTap: isLoading ? null : _showImageSourceDialog,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Avatar circle with border and shadow
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: imagePath != null
                    ? Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      )
                    : (avatarUrl != null
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[300],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey[600],
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey[600],
                            ),
                          )),
              ),
            ),

            // Camera icon overlay (only show when not loading)
            if (!isLoading)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.surface,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),

            // Loading overlay
            if (isLoading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

