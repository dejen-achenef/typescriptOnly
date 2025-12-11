import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:thyscan/features/help_and_support/presentation/screens/help_and_support.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _cloudBackup = true;
  bool _notifications = true;

  final String _language = 'English';
  final String _appVersion = 'TryScan v1.0.0';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: scheme.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: scheme.onBackground,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance Section
            _buildSectionHeader('Appearance', scheme),
            const SizedBox(height: 16),
            _buildSettingItem(
              icon: Iconsax.moon,
              title: 'Dark Mode',
              subtitle: 'Switch between light and dark theme',
              trailing: Switch(
                value: _darkMode,
                onChanged: (value) => setState(() => _darkMode = value),
                activeColor: scheme.primary,
              ),
              scheme: scheme,
            ),
            const SizedBox(height: 8),

            // Account & Data Section
            _buildSectionHeader('Account & Data', scheme),
            const SizedBox(height: 16),
            _buildSettingItem(
              icon: Iconsax.cloud_add,
              title: 'Cloud Backup',
              subtitle: 'Automatically back up your documents',
              trailing: Switch(
                value: _cloudBackup,
                onChanged: (value) => setState(() => _cloudBackup = value),
                activeColor: scheme.primary,
              ),
              scheme: scheme,
            ),
            const SizedBox(height: 8),
            _buildSettingItem(
              icon: Iconsax.cloud_change,
              title: 'Sync Settings',
              subtitle: 'Manage document sync preferences',
              trailing: Icon(
                Iconsax.arrow_right_3,
                color: scheme.onSurface.withValues(alpha: 0.5),
                size: 20,
              ),
              scheme: scheme,
              onTap: () => context.push('/sync-settings'),
            ),
            const SizedBox(height: 24),

            // Preferences Section
            _buildSectionHeader('Preferences', scheme),
            const SizedBox(height: 16),
            _buildSettingItem(
              icon: Iconsax.global,
              title: 'Language',
              subtitle: _language,
              trailing: Icon(
                Iconsax.arrow_right_3,
                color: scheme.onSurface.withValues(alpha: 0.5),
                size: 20,
              ),
              scheme: scheme,
              onTap: () => _showLanguageOptions(),
            ),
            const SizedBox(height: 8),
            _buildSettingItem(
              icon: Iconsax.notification,
              title: 'Notifications',
              subtitle: 'Manage your notification preferences',
              trailing: Switch(
                value: _notifications,
                onChanged: (value) => setState(() => _notifications = value),
                activeColor: scheme.primary,
              ),
              scheme: scheme,
            ),
            const SizedBox(height: 24),

            // About Section
            _buildSectionHeader('About', scheme),
            const SizedBox(height: 16),
            _buildSettingItem(
              icon: Iconsax.shield_tick,
              title: 'Privacy Policy',
              subtitle: 'Learn about our privacy practices',
              trailing: Icon(
                Iconsax.arrow_right_3,
                color: scheme.onSurface.withValues(alpha: 0.5),
                size: 20,
              ),
              scheme: scheme,
              onTap: () => _openPrivacyPolicy(),
            ),
            const SizedBox(height: 8),
            _buildSettingItem(
              icon: Iconsax.message_question,
              title: 'Help & Support',
              subtitle: 'Get help and contact support',
              trailing: Icon(
                Iconsax.arrow_right_3,
                color: scheme.onSurface.withValues(alpha: 0.5),
                size: 20,
              ),
              scheme: scheme,
              onTap: () => _openHelpSupport(),
            ),
            const SizedBox(height: 40),

            // App Version
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _appVersion,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required ColorScheme scheme,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: scheme.outline.withValues(alpha: 0.1), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary.withValues(alpha: 0.1),
                        scheme.primaryContainer.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: scheme.primary, size: 22),
                ),
                const SizedBox(width: 16),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Trailing Widget
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select Language',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            _buildLanguageOption('English', true),
            _buildLanguageOption('Spanish', false),
            _buildLanguageOption('French', false),
            _buildLanguageOption('German', false),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language, bool isSelected) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? scheme.primary.withValues(alpha: 0.1) : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? scheme.primary : scheme.outline.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: Icon(
          isSelected ? Iconsax.tick_circle : Iconsax.global,
          color: isSelected
              ? scheme.primary
              : scheme.onSurface.withValues(alpha: 0.5),
          size: 22,
        ),
        title: Text(
          language,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, size: 16, color: scheme.onPrimary),
              )
            : null,
        onTap: () {
          Navigator.pop(context);
          // Handle language change
        },
      ),
    );
  }

  void _openPrivacyPolicy() {
    // Navigate to privacy policy
  }

  void _openHelpSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HelpSupportScreen(),
      ),
    );
  }
}
