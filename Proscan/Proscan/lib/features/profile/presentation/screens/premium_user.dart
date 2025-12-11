import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:thyscan/features/help_and_support/presentation/screens/help_and_support.dart';
import 'package:thyscan/features/settings/presentation/view/settings.dart';
import 'package:thyscan/features/profile/presentation/screens/edit_profile.dart';
import 'package:thyscan/providers/auth_provider.dart';
import 'package:thyscan/core/models/app_user.dart';

class ProUserProfileScreen extends ConsumerStatefulWidget {
  const ProUserProfileScreen({super.key});

  @override
  ConsumerState<ProUserProfileScreen> createState() =>
      _ProUserProfileScreenState();
}

class _ProUserProfileScreenState extends ConsumerState<ProUserProfileScreen> {
  bool appLock = false;
  bool cloudBackup = true;
  bool wifiOnly = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final w = MediaQuery.of(context).size.width;
    final scale = (w / 375).clamp(0.9, 1.15);

    // Get actual user data from auth state
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: cs.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Profile Header
            SliverToBoxAdapter(
              child: _ProfessionalHeader(user: user, scale: scale),
            ),

            // Account & Security
            _buildSection(
              title: 'Account & Security',
              scale: scale,
              children: [
                _ProfessionalTile(
                  icon: Iconsax.edit_2,
                  title: 'Edit Profile',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfileScreen(),
                    ),
                  ),
                ),
                _ProfessionalToggleTile(
                  icon: Iconsax.lock_1,
                  title: 'App Lock',
                  value: appLock,
                  onChanged: (v) => setState(() => appLock = v),
                ),
                _ProfessionalTile(
                  icon: Iconsax.key,
                  title: 'Change Password',
                  onTap: () {},
                ),
                _ProfessionalTile(
                  icon: Iconsax.shield_tick,
                  title: 'Two-step verification',
                  onTap: () {},
                ),
              ],
            ),

            // Subscriptions
            _buildSection(
              title: 'Subscriptions',
              scale: scale,
              children: [
                _ProfessionalTile(
                  icon: Iconsax.crown_1,
                  title: 'ThyScan Pro',
                  subtitle: 'Active • Renews Oct 23, 2024',
                  onTap: () {},
                ),
                _ProfessionalTile(
                  icon: Iconsax.refresh,
                  title: 'Restore Purchases',
                  onTap: () {},
                ),
                _ProfessionalTile(
                  icon: Iconsax.gift,
                  title: 'Redeem Code',
                  onTap: () {},
                ),
              ],
            ),

            // Preferences
            _buildSection(
              title: 'Preferences',
              scale: scale,
              children: [
                _ProfessionalTile(
                  icon: Iconsax.sun_1,
                  title: 'Theme',
                  trailingText: 'System',
                  onTap: () {},
                ),
                _ProfessionalTile(
                  icon: Iconsax.document_text,
                  title: 'Default file name',
                  onTap: () {},
                ),
                _ProfessionalTile(
                  icon: Iconsax.rulerpen,
                  title: 'Paper size',
                  onTap: () {},
                ),
                _ProfessionalTile(
                  icon: Iconsax.translate,
                  title: 'OCR languages',
                  onTap: () {},
                ),
                _ProfessionalTile(
                  icon: Iconsax.notification,
                  title: 'Notifications',
                  onTap: () {},
                ),
              ],
            ),

            // Backup & Sync
            _buildSection(
              title: 'Backup & Sync',
              scale: scale,
              children: [
                _ProfessionalToggleTile(
                  icon: Iconsax.cloud_add,
                  title: 'Cloud backup',
                  value: cloudBackup,
                  onChanged: (v) => setState(() => cloudBackup = v),
                ),
                _ProfessionalTile(
                  icon: Iconsax.cloud_plus,
                  title: 'Back up now',
                  subtitle: 'Last backup: 1 day ago',
                  onTap: () {},
                ),
                _ProfessionalToggleTile(
                  icon: Iconsax.wifi_square,
                  title: 'Wi‑Fi only',
                  value: wifiOnly,
                  onChanged: (v) => setState(() => wifiOnly = v),
                ),
              ],
            ),

            // Help & Legal
            _buildSection(
              title: 'Help & Legal',
              scale: scale,
              children: [
                _ProfessionalTile(
                  icon: Iconsax.info_circle,
                  title: 'Help & Guide',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HelpSupportScreen(),
                    ),
                  ),
                ),
                _ProfessionalTile(
                  icon: Iconsax.message_question,
                  title: 'Contact Support',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HelpSupportScreen(),
                    ),
                  ),
                ),
                _ProfessionalTile(
                  icon: Iconsax.star_1,
                  title: 'Rate the App',
                  onTap: () {},
                ),
                _ProfessionalTile(
                  icon: Iconsax.shield_security,
                  title: 'Privacy Policy',
                  onTap: () {},
                ),
                _ProfessionalTile(
                  icon: Iconsax.document_text_1,
                  title: 'Terms of Service',
                  onTap: () {},
                ),
              ],
            ),

            // Sign Out Button
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20 * scale,
                  right: 20 * scale,
                  top: 24 * scale,
                  bottom: 40 * scale,
                ),
                child: Column(
                  children: [
                    Divider(color: cs.outline.withOpacity(0.1)),
                    SizedBox(height: 16 * scale),
                    _ProfessionalSignOutButton(
                      scale: scale,
                      onPressed: () => _handleSignOut(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildSection({
    required String title,
    required double scale,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 24 * scale),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20 * scale),
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13 * scale,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withOpacity(0.6),
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(height: 8 * scale),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16 * scale),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withOpacity(0.08), width: 1),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(authControllerProvider.notifier).signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Signed out successfully'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/* ------------------------------ PROFESSIONAL UI COMPONENTS ------------------------------ */

class _ProfessionalHeader extends StatelessWidget {
  final AppUser? user;
  final double scale;

  const _ProfessionalHeader({required this.user, required this.scale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: EdgeInsets.all(16 * scale),
      child: Column(
        children: [
          // Top bar with settings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile',
                style: GoogleFonts.inter(
                  fontSize: 28 * scale,
                  fontWeight: FontWeight.w700,
                  color: cs.onBackground,
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
                icon: Icon(
                  Iconsax.setting_2,
                  color: cs.onSurface.withOpacity(0.6),
                  size: 24 * scale,
                ),
              ),
            ],
          ),
          SizedBox(height: 32 * scale),

          // Profile card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24 * scale),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outline.withOpacity(0.08), width: 1),
            ),
            child: Column(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 80 * scale,
                      height: 80 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.surfaceVariant,
                        border: Border.all(
                          color: cs.outline.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: user?.photoUrl != null
                          ? ClipOval(
                              child: Image.network(
                                user!.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                      Iconsax.user,
                                      size: 32 * scale,
                                      color: cs.onSurfaceVariant,
                                    ),
                              ),
                            )
                          : Icon(
                              Iconsax.user,
                              size: 32 * scale,
                              color: cs.onSurfaceVariant,
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28 * scale,
                        height: 28 * scale,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 2),
                        ),
                        child: Icon(
                          Iconsax.edit_2,
                          size: 14 * scale,
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20 * scale),

                // Name and Pro badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user?.name ?? 'User',
                      style: GoogleFonts.inter(
                        fontSize: 18 * scale,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    SizedBox(width: 8 * scale),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8 * scale,
                        vertical: 2 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: cs.primary.withOpacity(0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        'PRO',
                        style: GoogleFonts.inter(
                          fontSize: 10 * scale,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4 * scale),

                // Email
                Text(
                  user?.email ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 14 * scale,
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                ),
                SizedBox(height: 20 * scale),

                // Storage usage
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Storage',
                          style: GoogleFonts.inter(
                            fontSize: 13 * scale,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface.withOpacity(0.8),
                          ),
                        ),
                        Text(
                          '62%',
                          style: GoogleFonts.inter(
                            fontSize: 13 * scale,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8 * scale),
                    Container(
                      height: 4 * scale,
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.62,
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      '256 MB of 512 MB used',
                      style: GoogleFonts.inter(
                        fontSize: 12 * scale,
                        color: cs.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfessionalTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback onTap;

  const _ProfessionalTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cs.outline.withOpacity(0.08), width: 1),
            ),
          ),
          child: Row(
            children: [
              // Icon
              Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.7)),
              SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Trailing
              if (trailingText != null)
                Text(
                  trailingText!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                ),
              SizedBox(width: 8),
              Icon(
                Iconsax.arrow_right_3,
                size: 18,
                color: cs.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfessionalToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ProfessionalToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cs.outline.withOpacity(0.08), width: 1),
            ),
          ),
          child: Row(
            children: [
              // Icon
              Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.7)),
              SizedBox(width: 16),

              // Title
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),

              // Switch
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeColor: cs.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfessionalSignOutButton extends StatelessWidget {
  final double scale;
  final VoidCallback onPressed;

  const _ProfessionalSignOutButton({
    required this.scale,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16 * scale),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: cs.outline.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.logout_1,
              size: 18 * scale,
              color: cs.onSurface.withOpacity(0.7),
            ),
            SizedBox(width: 8 * scale),
            Text(
              'Sign Out',
              style: GoogleFonts.inter(
                fontSize: 15 * scale,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
