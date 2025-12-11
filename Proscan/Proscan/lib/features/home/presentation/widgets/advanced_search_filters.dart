// features/home/presentation/widgets/advanced_search_filters.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Advanced search filters widget with date range and page count sliders
class AdvancedSearchFilters extends StatefulWidget {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int? minPages;
  final int? maxPages;
  final Function(DateTime?) onDateFromChanged;
  final Function(DateTime?) onDateToChanged;
  final Function(int?) onMinPagesChanged;
  final Function(int?) onMaxPagesChanged;
  final Function() onClearFilters;

  const AdvancedSearchFilters({
    super.key,
    this.dateFrom,
    this.dateTo,
    this.minPages,
    this.maxPages,
    required this.onDateFromChanged,
    required this.onDateToChanged,
    required this.onMinPagesChanged,
    required this.onMaxPagesChanged,
    required this.onClearFilters,
  });

  @override
  State<AdvancedSearchFilters> createState() => _AdvancedSearchFiltersState();
}

class _AdvancedSearchFiltersState extends State<AdvancedSearchFilters> {
  late int _minPagesValue;
  late int _maxPagesValue;
  final int _maxPageCount = 1000;

  @override
  void initState() {
    super.initState();
    _minPagesValue = widget.minPages ?? 0;
    _maxPagesValue = widget.maxPages ?? _maxPageCount;
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (widget.dateFrom ?? DateTime.now().subtract(const Duration(days: 30)))
          : (widget.dateTo ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      if (isFrom) {
        widget.onDateFromChanged(picked);
      } else {
        widget.onDateToChanged(picked);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Advanced Filters',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              if (widget.dateFrom != null ||
                  widget.dateTo != null ||
                  widget.minPages != null ||
                  widget.maxPages != null)
                TextButton(
                  onPressed: widget.onClearFilters,
                  child: Text(
                    'Clear',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Date Range
          Text(
            'Date Range',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDateButton(
                  context,
                  'From',
                  widget.dateFrom,
                  dateFormat,
                  () => _selectDate(context, true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateButton(
                  context,
                  'To',
                  widget.dateTo,
                  dateFormat,
                  () => _selectDate(context, false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Page Count Range
          Text(
            'Page Count',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Min: $_minPagesValue',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Max: $_maxPagesValue',
                  textAlign: TextAlign.end,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          RangeSlider(
            values: RangeValues(
              _minPagesValue.toDouble(),
              _maxPagesValue.toDouble(),
            ),
            min: 0,
            max: _maxPageCount.toDouble(),
            divisions: 100,
            onChanged: (values) {
              setState(() {
                _minPagesValue = values.start.round();
                _maxPagesValue = values.end.round();
              });
              widget.onMinPagesChanged(_minPagesValue == 0 ? null : _minPagesValue);
              widget.onMaxPagesChanged(_maxPagesValue == _maxPageCount ? null : _maxPagesValue);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton(
    BuildContext context,
    String label,
    DateTime? date,
    DateFormat formatter,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date != null ? formatter.format(date) : 'Select date',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: date != null
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

