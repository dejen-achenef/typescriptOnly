import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thyscan/providers/auth_provider.dart';

class ProfileGuestScreen extends ConsumerWidget {
  const ProfileGuestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Responsive scale (keeps sizing consistent across phones)
    final width = MediaQuery.of(context).size.width;
    final scale = (width / 375).clamp(0.9, 1.15);
    
    final authController = ref.read(authControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 24 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Auth card
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16 * scale,
                  vertical: scale * 10,
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 16 * scale),
                    _CircleIcon(
                      bg: cs.primary.withValues(alpha: 0.12),
                      icon: Icons.sync_lock_rounded,
                      iconColor: cs.primary,
                      size: 56 * scale,
                      iconSize: 28 * scale,
                    ),
                    SizedBox(height: 16 * scale),
                    Text(
                      'Sign in to back up and sync',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18 * scale,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 6 * scale),
                    Text(
                      'Access your scans on any device.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    SizedBox(height: 16 * scale),

                    // Buttons
                    _AuthButton.tonal(
                      label: 'Continue with Google',
                      onPressed: () async {
                        try {
                          await authController.signInWithGoogle();
                          // Navigation handled automatically via auth state change
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sign in failed: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      leading: Icon(
                        Icons.g_mobiledata_rounded,
                        color: cs.primary,
                        size: 28 * scale,
                      ),
                      height: 48 * scale,
                      tone: cs.primary.withValues(alpha: 0.1),
                    ),
                    SizedBox(height: 10 * scale),
                    _AuthButton.tonal(
                      label: 'Continue with Email',
                      onPressed: () {
                        context.push('/login');
                      },
                      leading: Icon(
                        Icons.mail_outline_rounded,
                        color: cs.primary,
                        size: 22 * scale,
                      ),
                      height: 48 * scale,
                      tone: cs.primary.withValues(alpha: 0.1),
                    ),
                    SizedBox(height: 4 * scale),
                  ],
                ),
              ),

              SizedBox(height: 16 * scale),

              // Preferences section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                child: Text(
                  'PREFERENCES',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              SizedBox(height: 10 * scale),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                child: _CardContainer(
                  child: Column(
                    children: [
                      _SettingsTile(
                        iconBg: theme.colorScheme.surfaceVariant.withOpacity(
                          0.6,
                        ),
                        icon: Icons.palette_outlined,
                        title: 'Theme',
                        trailingText: 'System',
                        onTap: () {
                          // TODO: Theme settings
                        },
                      ),
                      SizedBox(height: scale * 4),
                      _SettingsTile(
                        iconBg: theme.colorScheme.surfaceVariant.withOpacity(
                          0.6,
                        ),
                        icon: Icons.apps_rounded,
                        title: 'App Icon',
                        onTap: () {
                          // TODO: App Icon settings
                        },
                      ),
                      SizedBox(height: scale * 4),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 25 * scale),

              // Help & Legal
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                child: Text(
                  'HELP & LEGAL',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              SizedBox(height: 8 * scale),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                child: _CardContainer(
                  child: Column(
                    children: [
                      _SettingsTile(
                        iconBg: theme.colorScheme.surfaceVariant.withOpacity(
                          0.6,
                        ),
                        icon: Icons.help_outline_rounded,
                        title: 'Help Center',
                        onTap: () {
                          context.push('/helpandsupport');
                        },
                      ),

                      SizedBox(height: 8 * scale),
                      _SettingsTile(
                        iconBg: theme.colorScheme.surfaceVariant.withOpacity(
                          0.6,
                        ),
                        icon: Icons.mail_outline_rounded,
                        title: 'Contact Us',
                        onTap: () {
                          context.push('/helpandsupport');
                        },
                      ),
                      SizedBox(height: 8 * scale),
                      _SettingsTile(
                        iconBg: theme.colorScheme.surfaceVariant.withOpacity(
                          0.6,
                        ),
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        onTap: () {
                          // TODO: Open privacy policy
                        },
                      ),
                      SizedBox(height: 8 * scale),
                      _SettingsTile(
                        iconBg: theme.colorScheme.surfaceVariant.withOpacity(
                          0.6,
                        ),
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        onTap: () {
                          // TODO: Open terms of service
                        },
                      ),
                      SizedBox(height: 20 * scale),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 30 * scale),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;
  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final Color bg;
  final Color iconColor;
  final double size;
  final double iconSize;
  final IconData icon;
  const _CircleIcon({
    required this.bg,
    required this.iconColor,
    required this.size,
    required this.iconSize,
    this.icon = Icons.check,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, color: iconColor, size: iconSize),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final Widget leading;
  final VoidCallback onPressed;
  final bool filled;
  final Color? tone;
  final double height;

  const _AuthButton._({
    required this.label,
    required this.leading,
    required this.onPressed,
    required this.filled,
    this.tone,
    required this.height,
  });

  factory _AuthButton.filled({
    required String label,
    required Widget leading,
    required VoidCallback onPressed,
    required double height,
  }) {
    return _AuthButton._(
      label: label,
      leading: leading,
      onPressed: onPressed,
      filled: true,
      height: height,
    );
  }

  factory _AuthButton.tonal({
    required String label,
    required Widget leading,
    required VoidCallback onPressed,
    required double height,
    required Color tone,
  }) {
    return _AuthButton._(
      label: label,
      leading: leading,
      onPressed: onPressed,
      filled: false,
      tone: tone,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bg = filled ? cs.primary : (tone ?? cs.primary.withOpacity(0.1));
    final fg = filled ? Colors.white : cs.primary;

    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String? trailingText;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.onTap,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurface.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}
