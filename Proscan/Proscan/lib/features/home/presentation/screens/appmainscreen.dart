// lib/features/home/presentation/screens/app_main_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:thyscan/core/theme/constants/theme.dart';
import 'package:thyscan/features/help_and_support/presentation/screens/help_and_support.dart';
import 'package:thyscan/features/help_and_support/presentation/screens/how_to_scan_and_crop.dart';
import 'package:thyscan/features/home/controllers/home_state_provider.dart';
import 'package:thyscan/features/home/controllers/library_state_provider.dart';

import 'package:thyscan/features/home/presentation/screens/homescreen.dart';
import 'package:thyscan/features/home/presentation/screens/tools_screen.dart';
import 'package:thyscan/features/home/presentation/screens/library.dart';
import 'package:thyscan/features/home/presentation/screens/profile.dart';
import 'package:thyscan/features/profile/presentation/screens/edit_profile.dart';
import 'package:thyscan/features/profile/presentation/screens/free_user.dart';
import 'package:thyscan/features/profile/presentation/screens/guest_mode.dart';
import 'package:thyscan/features/profile/presentation/screens/premium_user.dart';

class AppMainScreen extends ConsumerWidget {
  const AppMainScreen({super.key});

  static final List<_NavItem> _navItems = [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.widgets_outlined, Icons.widgets_rounded, 'Tools'),
    _NavItem(null, null, ''), // FAB placeholder
    _NavItem(Icons.folder_outlined, Icons.folder_rounded, 'Library'),
    _NavItem(Icons.person_outlined, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int currentIndex = ref.watch(screenIndexProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // WATCH BOTH SCREEN STATES
    final isHomeSelectionMode = ref.watch(homeProvider).isSelectionMode;
    final isLibrarySelectionMode = ref.watch(libraryProvider).isSelectionMode;

    // THE FIX: Combine the conditions
    final bool hideMainNavigation =
        (isHomeSelectionMode && currentIndex == 0) ||
        (isLibrarySelectionMode && currentIndex == 3);

    final List<Widget> screens = [
      const HomeScreen(),
      const ToolsScreen(),
      const Placeholder(),
      const LibraryScreen(),
      const ProfileScreen(), // Uses conditional rendering (guest/pro)
    ];

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFFAFBFF),
      body: IndexedStack(index: currentIndex, children: screens),

      floatingActionButton:
          hideMainNavigation // Use the new combined boolean
          ? null
          : _buildModernFAB(context, isDark),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar:
          hideMainNavigation // Use the new combined boolean
          ? null
          : _buildModernBottomNavBar(context, currentIndex, ref, isDark),
    );
  }

  Widget _buildModernFAB(BuildContext context, bool isDark) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Color(0xFF7C3AED), Color(0xFF6366F1)]
              : [Color(0xFF8B5CF6), Color(0xFF6366F1)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(isDark ? 0.4 : 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () => context.push('/camerascreen'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(
          Icons.camera_alt_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildModernBottomNavBar(
    BuildContext context,
    int currentIndex,
    WidgetRef ref,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navItems.asMap().entries.map((e) {
              final int idx = e.key;
              final _NavItem item = e.value;

              if (idx == 2) {
                return const SizedBox(width: 48); // Space for FAB
              }

              return _buildNavItem(
                context: context,
                index: idx,
                currentIndex: currentIndex,
                item: item,
                ref: ref,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required int currentIndex,
    required _NavItem item,
    required WidgetRef ref,
  }) {
    final bool isSelected = currentIndex == index;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: InkWell(
        onTap: () => ref.read(screenIndexProvider.notifier).state = index,
        customBorder: const CircleBorder(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? item.selected : item.unselected,
              size: 24,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.5),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData? unselected;
  final IconData? selected;
  final String label;
  const _NavItem(this.unselected, this.selected, this.label);
}

final screenIndexProvider = StateProvider<int>((ref) => 0);
