import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thyscan/features/home/controllers/home_state_provider.dart';
import 'package:thyscan/features/home/controllers/filtered_documents_provider.dart';
import 'package:thyscan/features/home/models/document_filter.dart';
import 'package:thyscan/features/home/presentation/widgets/document_filter_chip.dart';

class RecentScansSection extends ConsumerWidget {
  const RecentScansSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final homeState = ref.watch(homeProvider);
    final homeNotifier = ref.read(homeProvider.notifier);

    return Column(
      children: [
        // Enhanced Header with Premium Styling
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title with icon
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Scans',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your latest document scans',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Enhanced Sort Dropdown
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _buildPremiumSortDropdown(
                  context,
                  homeState.sortCriteria,
                  homeNotifier.setSortCriteria,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Enhanced Filter Chips Section
        Container(
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.only(right: 4, left: 4, bottom: 7),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: DocumentFilters.allFilters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = DocumentFilters.allFilters[index];
              final isSelected = homeState.activeFilterId == filter.id;
              final countAsync = ref.watch(documentCountByFilterProvider(filter.id));

              return countAsync.when(
                data: (count) => DocumentFilterChip(
                  filter: filter,
                  isSelected: isSelected,
                  count: count,
                  onTap: () => homeNotifier.setActiveFilter(filter.id),
                ),
                loading: () => DocumentFilterChip(
                  filter: filter,
                  isSelected: isSelected,
                  count: 0, // Show 0 while loading
                  onTap: () => homeNotifier.setActiveFilter(filter.id),
                ),
                error: (_, __) => DocumentFilterChip(
                  filter: filter,
                  isSelected: isSelected,
                  count: 0, // Show 0 on error
                  onTap: () => homeNotifier.setActiveFilter(filter.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumSortDropdown(
    BuildContext context,
    SortCriteria currentCriteria,
    Function(SortCriteria) onSortChanged,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<SortCriteria>(
      onSelected: onSortChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      surfaceTintColor: colorScheme.surface,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.1),
      itemBuilder: (context) => [
        _buildPremiumMenuItem(
          context,
          SortCriteria.date,
          currentCriteria,
          Icons.calendar_today_rounded,
          'Date scanned',
          'Most recent first',
        ),
        _buildPremiumMenuItem(
          context,
          SortCriteria.size,
          currentCriteria,
          Icons.storage_rounded,
          'File size',
          'Largest files first',
        ),
        _buildPremiumMenuItem(
          context,
          SortCriteria.pages,
          currentCriteria,
          Icons.layers_rounded,
          'Page count',
          'Most pages first',
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_vert_rounded,
              size: 18,
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
            const SizedBox(width: 8),
            Text(
              _getSortLabel(currentCriteria),
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<SortCriteria> _buildPremiumMenuItem(
    BuildContext context,
    SortCriteria criteria,
    SortCriteria currentCriteria,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = criteria == currentCriteria;

    return PopupMenuItem<SortCriteria>(
      value: criteria,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // Icon with selection indicator
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withOpacity(0.1)
                    : colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary.withOpacity(0.3)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 12),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Selection checkmark
            if (isSelected)
              Icon(Icons.check_rounded, size: 18, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  String _getSortLabel(SortCriteria criteria) {
    switch (criteria) {
      case SortCriteria.date:
        return 'Date';
      case SortCriteria.size:
        return 'Size';
      case SortCriteria.pages:
        return 'Pages';
    }
  }
}
