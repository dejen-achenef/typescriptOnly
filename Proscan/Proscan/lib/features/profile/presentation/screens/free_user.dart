import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FreeUserProfileScreen extends StatefulWidget {
  const FreeUserProfileScreen({super.key});

  @override
  State<FreeUserProfileScreen> createState() => _FreeUserProfileScreenState();
}

class _FreeUserProfileScreenState extends State<FreeUserProfileScreen> {
  // Local UI state (replace with providers later)
  bool appLock = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Responsive scale
    final w = MediaQuery.of(context).size.width;
    final scale = (w / 375).clamp(0.9, 1.15);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 24 * scale),
          child: Column(
            children: [
              SizedBox(height: scale * 10),
              // Header (avatar, name, email, Upgrade link)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16 * scale,
                    16 * scale,
                    16 * scale,
                    16 * scale,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 28 * scale,
                        backgroundColor: cs.surfaceVariant.withValues(alpha: 0.8),
                        child: Icon(
                          Icons.person_rounded,
                          size: 30 * scale,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      SizedBox(height: 12 * scale),
                      Text(
                        'Jessica Miller',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6 * scale),
                      Text(
                        'j.mill@example.com',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 
                            0.7,
                          ),
                        ),
                      ),
                      SizedBox(height: 6 * scale),
                      TextButton(
                        onPressed: () {
                          // TODO: Navigate to paywall / upgrade flow
                        },
                        child: const Text('Upgrade to Pro'),
                      ),
                      // NOTE: No backup status/progress for free users
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16 * scale),

              // Account & Security
              _SectionTitle('Account & Security', scale: scale),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                child: _Card(
                  child: Column(
                    children: [
                      _Tile(
                        icon: Icons.edit_outlined,
                        title: 'Edit Profile',
                        onTap: () {},
                      ),
                      _ToggleTile(
                        icon: Icons.lock_outline,
                        title: 'App Lock',
                        value: appLock,
                        onChanged: (v) => setState(() => appLock = v),
                      ),
                      _Tile(
                        icon: Icons.password_outlined,
                        title: 'Change Password',
                        onTap: () {},
                      ),
                      _Tile(
                        icon: Icons.verified_user_outlined,
                        title: 'Two-step verification',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 25 * scale),

              // Subscriptions (free -> upgrade CTA + restore/redeem)
              _SectionTitle('Subscriptions', scale: scale),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                child: _Card(
                  child: Column(
                    children: [
                      _Tile(
                        icon: Icons.workspace_premium_outlined,
                        title: 'ThyScan Pro',
                        subtitle: 'Upgrade to unlock all features',
                        onTap: () {
                          // TODO: Paywall / upgrade
                        },
                      ),
                      _Tile(
                        icon: Icons.settings_backup_restore_outlined,
                        title: 'Restore Purchases',
                        onTap: () {
                          // TODO: Restore
                        },
                      ),
                      _Tile(
                        icon: Icons.redeem_outlined,
                        title: 'Redeem Code',
                        onTap: () {
                          // TODO: Redeem
                        },
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 25 * scale),

              // Preferences
              _SectionTitle('Preferences', scale: scale),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                child: _Card(
                  child: Column(
                    children: [
                      _Tile(
                        icon: Icons.brightness_6_outlined,
                        title: 'Theme',
                        trailingText: 'System',
                        onTap: () {},
                      ),
                      _Tile(
                        icon: Icons.title_outlined,
                        title: 'Default file name',
                        onTap: () {},
                      ),
                      _Tile(
                        icon: CupertinoIcons.doc_on_clipboard,
                        title: 'Paper size',
                        onTap: () {},
                      ),
                      _Tile(
                        icon: Icons.translate_outlined,
                        title: 'OCR languages',
                        onTap: () {},
                      ),
                      _Tile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifications',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 25 * scale),

              // Help & Legal
              _SectionTitle('Help & Legal', scale: scale),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                child: _Card(
                  child: Column(
                    children: [
                      _Tile(
                        icon: Icons.help_outline_rounded,
                        title: 'FAQ',
                        onTap: () {},
                      ),
                      _Tile(
                        icon: Icons.support_agent_outlined,
                        title: 'Contact Support',
                        onTap: () {},
                      ),
                      _Tile(
                        icon: Icons.star_border_rounded,
                        title: 'Rate the App',
                        onTap: () {},
                      ),
                      _Tile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        onTap: () {},
                      ),
                      _Tile(
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16 * scale),

              // Sign out
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                child: InkWell(
                  onTap: () {
                    // TODO: Sign out
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 10 * scale,
                      horizontal: 8 * scale,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: theme.colorScheme.error,
                        ),
                        SizedBox(width: 8 * scale),
                        Text(
                          'Sign Out',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 8 * scale),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------------------ UI Helpers ----------------------------- */

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.25 : 0.06,
            ),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final double scale;
  const _SectionTitle(this.text, {required this.scale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16 * scale,
        right: 16 * scale,
        bottom: 8 * scale,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withOpacity(0.65),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback onTap;

  const _Tile({
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

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                size: 20,
                color: cs.onSurface.withOpacity(0.85),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(
                          0.65,
                        ),
                      ),
                    ),
                  ],
                ],
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

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(0.6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.85)),
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
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: cs.primary,
          ),
        ],
      ),
    );
  }
}
