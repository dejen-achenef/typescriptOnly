// features/scan/presentation/widgets/barcode_result_sheet.dart
import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thyscan/core/utils/share_utils.dart';
import 'package:thyscan/features/scan/core/services/barcode_scanner_service.dart';
import 'package:thyscan/features/scan/core/utils/url_utils.dart';

/// Bottom sheet widget for displaying barcode scan results
class BarcodeResultSheet extends StatelessWidget {
  final BarcodeData barcodeData;
  final VoidCallback onDismiss;

  const BarcodeResultSheet({
    super.key,
    required this.barcodeData,
    required this.onDismiss,
  });

  String _getDataTypeLabel(BarcodeDataType type) {
    switch (type) {
      case BarcodeDataType.url:
        return 'Website';
      case BarcodeDataType.email:
        return 'Email';
      case BarcodeDataType.phone:
        return 'Phone Number';
      case BarcodeDataType.contact:
        return 'Contact';
      case BarcodeDataType.text:
        return 'Text';
    }
  }

  IconData _getDataTypeIcon(BarcodeDataType type) {
    switch (type) {
      case BarcodeDataType.url:
        return Icons.language_rounded;
      case BarcodeDataType.email:
        return Icons.email_rounded;
      case BarcodeDataType.phone:
        return Icons.phone_rounded;
      case BarcodeDataType.contact:
        return Icons.contact_page_rounded;
      case BarcodeDataType.text:
        return Icons.text_fields_rounded;
    }
  }

  String _truncateText(String text, {int maxLength = 100}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    try {
      await FlutterClipboard.copy(barcodeData.rawValue);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareContent(BuildContext context) async {
    try {
      await ShareUtils.shareText(
        barcodeData.rawValue,
        subject: 'Scanned ${_getDataTypeLabel(barcodeData.dataType)}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openUrl(BuildContext context) async {
    try {
      final success = await UrlUtils.launchUrl(barcodeData.rawValue);
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open URL'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUrl = barcodeData.dataType == BarcodeDataType.url;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getDataTypeIcon(barcodeData.dataType),
                      color: cs.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getDataTypeLabel(barcodeData.dataType),
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code detected',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: cs.onSurface),
                    onPressed: onDismiss,
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: SelectableText(
                  barcodeData.rawValue,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: cs.onSurface,
                    height: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Open URL button (only for URLs)
                  if (isUrl)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openUrl(context),
                        icon: const Icon(Icons.open_in_browser_rounded),
                        label: const Text('Open in Browser'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),

                  if (isUrl) const SizedBox(height: 12),

                  // Copy and Share buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(context),
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copy'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _shareContent(context),
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

