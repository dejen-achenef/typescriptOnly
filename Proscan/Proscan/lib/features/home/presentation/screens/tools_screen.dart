import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thyscan/features/home/presentation/widgets/tool_card.dart';
import 'package:thyscan/features/scan/model/scan_flow_models.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  // Organized by categories
  static final List<ToolCategory> _toolCategories = [
    ToolCategory(
      title: 'Document Scanning',
      tools: [
        _ToolData(
          ScanMode.idCard,
          'ID Card',
          icon: Icons.credit_card_rounded,
          color: const Color(0xFF8B5CF6),
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
          ScanMode.document,
          'Document',
          icon: Icons.description_rounded,
          color: const Color(0xFF3B82F6),
          description: 'Documents',
        ),
      ],
    ),
    ToolCategory(
      title: 'Text & Office',
      tools: [
        _ToolData(
          ScanMode.excel,
          'To Excel',
          badgeText: 'New',
          icon: Icons.table_chart_rounded,
          color: const Color(0xFF10B981),
          description: 'Tables to Excel',
        ),
        _ToolData(
          ScanMode.word,
          'To Word',
          icon: Icons.text_snippet_rounded,
          color: const Color(0xFF2563EB),
          description: 'Text to Word',
        ),
        _ToolData(
          ScanMode.slides,
          'Slides',
          icon: Icons.slideshow_rounded,
          color: const Color(0xFFF59E0B),
          description: 'Presentations',
        ),
      ],
    ),
    ToolCategory(
      title: 'Smart Features',
      tools: [
        _ToolData(
          ScanMode.translate,
          'Translate',
          icon: Icons.translate_rounded,
          color: const Color(0xFF06B6D4),
          description: 'Translation',
        ),
        _ToolData(
          ScanMode.extractText,
          'Extract Text',
          icon: Icons.text_fields_rounded,
          color: const Color(0xFF8B5CF6),
          description: 'Text recognition',
        ),
        _ToolData(
          ScanMode.question,
          'Q&A Scan',
          icon: Icons.quiz_rounded,
          color: const Color(0xFFEC4899),
          description: 'Answer questions',
        ),
        _ToolData(
          null,
          'More Tools',
          icon: Icons.apps_rounded,
          color: const Color(0xFF64748B),
          description: 'All features',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: 20),
          // physics: const BouncingScrollPhysics(),
          child: _buildToolsContent(context),
        ),
      ),
    );
  }

  Widget _buildToolsContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive calculations
    final isSmallPhone = screenWidth < 350;
    final isTablet = screenWidth > 600;
    final crossAxisCount = isSmallPhone ? 3 : (isTablet ? 6 : 4);
    final horizontalPadding = isSmallPhone ? 20.0 : (isTablet ? 40.0 : 28.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Header Section
          _buildPremiumHeader(context, cs),

          const SizedBox(height: 40),

          // Categories with enhanced spacing
          Column(
            children: _toolCategories.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              return _buildCategorySection(
                context,
                category,
                crossAxisCount,
                isLast: index == _toolCategories.length - 1,
              );
            }).toList(),
          ),

          // Bottom spacing for comfortable scrolling
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main title with gradient
          Text(
            'Smart Tools',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              foreground: Paint()
                ..shader = const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
              fontSize: 36,
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ),

          const SizedBox(height: 15),

          // Description with improved typography
          Text(
            'Discover our complete suite of AI-powered scanning tools designed to transform your documents into digital assets.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant.withOpacity(0.8),
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 24),

          // Stats or feature highlights
          _buildFeatureHighlights(context),
        ],
      ),
    );
  }

  Widget _buildFeatureHighlights(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('12+', 'Tools', Icons.auto_awesome_rounded, context),
          _buildStatItem('AI', 'Powered', Icons.psychology_rounded, context),
          _buildStatItem('100%', 'Secure', Icons.verified_rounded, context),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    IconData icon,
    BuildContext context,
  ) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    ToolCategory category,
    int crossAxisCount, {
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Category Header with improved spacing
          Padding(
            padding: const EdgeInsets.only(bottom: 28, left: 4),
            child: Row(
              children: [
                // Gradient accent line
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    category.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 22,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tools Grid with optimized spacing
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: category.tools.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 20,
              mainAxisSpacing: 24,
              mainAxisExtent: 140, // Optimized height for better spacing
            ),
            itemBuilder: (context, index) {
              final tool = category.tools[index];
              return ToolCard(
                icon: tool.icon ?? Icons.category_rounded,
                label: tool.label,
                badgeText: tool.badgeText,
                accentColor: tool.color,
                description: tool.description,
                onTap: () => _handleTap(context, tool.mode),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context, ScanMode? mode) {
    if (mode == null) {
      context.push('/toolscreen');
    } else {
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

class ToolCategory {
  final String title;
  final List<_ToolData> tools;

  const ToolCategory({required this.title, required this.tools});
}
