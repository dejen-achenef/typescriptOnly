// features/home/presentation/widgets/tools_section.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thyscan/features/home/presentation/widgets/tool_card.dart';
import 'package:thyscan/features/scan/model/scan_flow_models.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thyscan/features/home/presentation/screens/appmainscreen.dart';

class ToolsSection extends ConsumerWidget {
  const ToolsSection({super.key});

  // Main 7 modes shown on home screen + "More Tools"
  static final List<_ToolData> _mainTools = [
    _ToolData(
      ScanMode.idCard,
      'ID Card',
      icon: Icons.credit_card_rounded,
      color: Color(0xFF8B5CF6),
      description: 'Scan ID cards',
    ),
    _ToolData(
      ScanMode.book,
      'Book Scan',
      badgeText: 'Pro',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFFEC4899),
      description: 'Book pages',
    ),
    _ToolData(
      ScanMode.excel,
      'To Excel',
      badgeText: 'New',
      icon: Icons.table_chart_rounded,
      color: const Color(0xFF10B981),
      description: 'Tables to Excel',
    ),
    _ToolData(
      ScanMode.slides,
      'Slides',
      icon: Icons.slideshow_rounded,
      color: const Color(0xFFF59E0B),
      description: 'Presentations',
    ),
    _ToolData(
      ScanMode.word,
      'To Word',
      icon: Icons.text_snippet_rounded,
      color: const Color(0xFF6366F1),
      description: 'Text to Word',
    ),
    _ToolData(
      ScanMode.translate,
      'Translate',
      icon: Icons.translate_rounded,
      color: const Color(0xFF06B6D4),
      description: 'Translation',
    ),
    _ToolData(
      ScanMode.scanCode,
      'Scan Code',
      icon: Icons.qr_code_rounded,
      color: const Color(0xFF22C55E),
      description: 'QR & Barcodes',
    ),
    _ToolData(
      null,
      'More Tools',
      icon: Icons.apps_rounded,
      color: const Color(0xFF94A3B8),
      description: 'All features',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive calculations
    final isSmallPhone = screenWidth < 350;
    final isTablet = screenWidth > 600;
    final crossAxisCount = isSmallPhone ? 3 : (isTablet ? 6 : 4);
    final horizontalPadding = isSmallPhone ? 16.0 : (isTablet ? 32.0 : 20.0);
    final mainAxisExtent = isSmallPhone ? 95.0 : 105.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tools Grid with optimized spacing
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _mainTools.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              // mainAxisSpacing: 20,
              mainAxisExtent: mainAxisExtent,
            ),
            itemBuilder: (context, index) {
              final tool = _mainTools[index];
              return ToolCard(
                icon: tool.icon ?? Icons.category_rounded,
                label: tool.label,
                badgeText: tool.badgeText,
                accentColor: tool.color,
                description: tool.description,
                onTap: () => _handleTap(context, ref, tool.mode),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main title with icon
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.primary.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Tools',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      fontSize: 20,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quick access to essential scanning features',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Quick stats row
        const SizedBox(height: 20),
        _buildQuickStats(context),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('8', 'Tools', context),
          Container(
            width: 1,
            height: 20,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
          _buildStatItem('AI', 'Powered', context),
          Container(
            width: 1,
            height: 20,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
          _buildStatItem('Fast', 'Access', context),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref, ScanMode? mode) {
    if (mode == null) {
      // Switch to Tools tab (index 1)
      ref.read(screenIndexProvider.notifier).state = 1;
    } else {
      // Open camera locked to the selected mode
      context.push(
        '/camerascreen',
        extra: CameraScreenConfig(
          initialMode: mode,
          restrictToInitialMode: true,
        ),
      );
    }
  }
}

class _ToolData {
  final ScanMode? mode;
  final String label;
  final IconData? icon;
  final String? badgeText;
  final Color color;
  final String description;

  const _ToolData(
    this.mode,
    this.label, {
    this.icon,
    this.badgeText,
    required this.color,
    required this.description,
  });
}
