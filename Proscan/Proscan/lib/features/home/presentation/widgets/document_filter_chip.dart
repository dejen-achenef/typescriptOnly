import 'package:flutter/material.dart';
import 'package:thyscan/features/home/models/document_filter.dart';

class DocumentFilterChip extends StatelessWidget {
  final DocumentFilter filter;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;

  const DocumentFilterChip({
    super.key,
    required this.filter,
    required this.isSelected,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: FilterChip(
        avatar: Icon(
          filter.icon,
          size: 18,
          color: isSelected ? colorScheme.onPrimary : filter.color,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              filter.label,
              style: TextStyle(
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? colorScheme.onPrimary.withOpacity(0.2)
                      : colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(
          color: isSelected ? filter.color : colorScheme.outline.withOpacity(0.3),
          width: isSelected ? 1.5 : 1,
        ),
        selectedColor: filter.color,
        backgroundColor: colorScheme.surface,
        checkmarkColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: isSelected ? 2 : 0,
        shadowColor: filter.color.withOpacity(0.3),
        showCheckmark: false,
      ),
    );
  }
}
