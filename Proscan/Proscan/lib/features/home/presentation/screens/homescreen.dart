import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thyscan/core/utils/share_utils.dart';
import 'package:thyscan/core/theme/constants/app_design.dart';
import 'package:thyscan/features/home/presentation/widgets/premium_modal.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/widgets/error_boundary.dart';
import 'package:thyscan/features/home/controllers/home_state_provider.dart';
import 'package:thyscan/features/home/controllers/documents_pagination_provider.dart';
import 'package:thyscan/features/home/presentation/screens/recent_scans_section.dart';
import 'package:thyscan/features/home/presentation/widgets/corrupted_document_tile.dart';
import 'package:thyscan/features/home/presentation/widgets/scan_list_item.dart';
import 'package:thyscan/features/home/presentation/widgets/sync_status_indicator.dart';
import 'package:thyscan/features/home/presentation/widgets/tools_section.dart';
import 'package:thyscan/features/home/presentation/widgets/upload_queue_badge.dart';
import 'package:thyscan/features/scan/model/scans.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';
import 'package:thyscan/providers/greeting_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);
    final homeNotifier = ref.read(homeProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use paginated documents provider (windowed loading - max 150 docs in memory)
    // For home screen, only show first 8 recent documents
    final paginatedState = ref.watch(currentPaginatedDocumentsProvider);
    final recentDocs = paginatedState.documents.take(8).toList();

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: _buildPremiumAppBar(context, homeState, homeNotifier, ref),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header Spacing
          if (!homeState.isSelectionMode)
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Welcome Section
          if (!homeState.isSelectionMode)
            SliverToBoxAdapter(
              child: _buildWelcomeSection(context, colorScheme),
            ),

          // Tools Section
          if (!homeState.isSelectionMode)
            const SliverToBoxAdapter(child: ToolsSection()),

          // Recent Scans Section
          if (!homeState.isSelectionMode)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 40, bottom: 16),
                child: RecentScansSection(),
              ),
            ),

          // Show empty state or document list
          if (recentDocs.isEmpty && !homeState.isSelectionMode)
            SliverToBoxAdapter(child: _buildPremiumEmptyState(context))
          else if (recentDocs.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  // Wrap each item in error boundary (bulletproof - never crashes)
                  return ListItemErrorBoundary(
                    fallback: (context, error) {
                      // Show corrupted document tile on error
                      final doc = index < recentDocs.length
                          ? recentDocs[index]
                          : null;
                      return CorruptedDocumentTile(
                        documentId: doc?.id ?? 'unknown',
                        documentTitle: doc?.title,
                        onDeleted: () {
                          // Refresh will be handled by parent
                        },
                        onRetry: () {
                          // Retry will be handled by parent
                        },
                      );
                    },
                    child: _buildDocumentItem(
                      context,
                      index,
                      recentDocs,
                      homeState,
                      homeNotifier,
                    ),
                  );
                }, childCount: recentDocs.length),
              ),
            ),

          // Bottom padding
          SliverToBoxAdapter(
            child: SizedBox(height: homeState.isSelectionMode ? 120 : 60),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, ref, homeState, homeNotifier),
    );
  }

  /// Premium Welcome Section with Dynamic Greeting (CamScanner-style)
  /// Updates automatically when time crosses boundaries or user logs in/out
  Widget _buildWelcomeSection(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dynamic greeting with fade animation
          _DynamicGreetingText(colorScheme: colorScheme),
          const SizedBox(height: 4),
          Text(
            'Ready to scan some documents?',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colorScheme.onBackground.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Convert DocumentModel to Scan for UI compatibility
  Scan _documentToScan(DocumentModel doc) {
    final dateFormat = DateFormat('MMM dd');
    return Scan(
      id: doc.id,
      title: doc.title,
      imagePath: doc.thumbnailPath,
      date: dateFormat.format(doc.createdAt),
      size: doc.format.toUpperCase(),
      pageCount: '${doc.pageCount} page${doc.pageCount == 1 ? '' : 's'}',
      tags: doc.format == 'docx' ? ['Text'] : [],
      scanMode: doc.scanMode,
    );
  }

  /// Builds a document item with error handling (bulletproof)
  Widget _buildDocumentItem(
    BuildContext context,
    int index,
    List<DocumentModel> recentDocs,
    HomeState homeState,
    HomeNotifier homeNotifier,
  ) {
    try {
      final doc = recentDocs[index];
      final scan = _documentToScan(doc);
      final isSelected = homeState.selectedScanIds.contains(scan.id);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: ScanListItem(
          scan: scan,
          document: doc, // Pass DocumentModel for validation
          isSelectionMode: homeState.isSelectionMode,
          isSelected: isSelected,
          onLongPress: () {
            homeNotifier.enterSelectionMode(scan.id);
          },
          onTap: () {
            if (homeState.isSelectionMode) {
              homeNotifier.toggleScanSelection(scan.id);
            } else {
              _openDocument(context, doc);
            }
          },
          onEdit: () => _openDocument(context, doc),
          onDelete: () => _deleteDocument(context, doc),
          onShare: () => _shareDocument(context, doc),
        ),
      );
    } catch (e, stack) {
      // This should never be reached due to error boundary,
      // but provides extra safety
      AppLogger.error(
        'Error building document item (caught in builder)',
        error: e,
        stack: stack,
        data: {'index': index},
      );

      // Return corrupted tile as fallback
      final doc = index < recentDocs.length ? recentDocs[index] : null;
      return CorruptedDocumentTile(
        documentId: doc?.id ?? 'unknown',
        documentTitle: doc?.title,
        onDeleted: () {
          // Refresh will be handled by parent
        },
        onRetry: () {
          // Retry will be handled by parent
        },
      );
    }
  }

  /// Open document in appropriate screen based on format
  void _openDocument(BuildContext context, DocumentModel doc) {
    if (doc.format == 'txt' || doc.format == 'docx') {
      context.push('/textdocumentscreen', extra: {'documentId': doc.id});
    } else {
      context.push(
        '/savepdfscreen',
        extra: {
          'imagePaths': doc.pageImagePaths.isNotEmpty
              ? doc.pageImagePaths
              : [doc.thumbnailPath],
          'pdfFileName': doc.title,
          'documentId': doc.id,
          'scanMode': doc.scanMode,
          'colorProfile': doc.colorProfile,
        },
      );
    }
  }

  /// Delete document from Hive and internal storage
  Future<void> _deleteDocument(BuildContext context, DocumentModel doc) async {
    try {
      await DocumentService.instance.deleteDocument(doc.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${doc.title} deleted'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  /// Share document PDF
  Future<void> _shareDocument(BuildContext context, DocumentModel doc) async {
    try {
      await ShareUtils.shareFiles(
        [XFile(doc.filePath)],
        subject: doc.title,
        text: 'Check out this scanned document!',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  /// Premium Empty State
  Widget _buildPremiumEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withOpacity(0.05),
            colorScheme.primary.withOpacity(0.02),
          ],
        ),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.document_scanner_rounded,
              size: 48,
              color: colorScheme.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No scans yet',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start scanning documents to see them here.\nYour recent scans will appear in this section.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.push('/camerascreen'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              'Start Scanning',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Premium App Bar
  PreferredSizeWidget _buildPremiumAppBar(
    BuildContext context,
    HomeState state,
    HomeNotifier notifier,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (state.isSelectionMode) {
      // Use paginated provider for real-time updates
      final paginatedState = ref.watch(currentPaginatedDocumentsProvider);
      final recentDocs = paginatedState.documents.take(8).toList();
      final areAllSelected = state.selectedScanIds.length == recentDocs.length;

      return AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: IconButton(
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close_rounded,
              size: 20,
              color: colorScheme.onSurface,
            ),
          ),
          onPressed: notifier.exitSelectionMode,
        ),
        title: Text(
          '${state.selectedScanIds.length} selected',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: () {
                if (areAllSelected) {
                  notifier.exitSelectionMode();
                } else {
                  final paginatedState =
                      ref.read(currentPaginatedDocumentsProvider);
                  final recentDocs = paginatedState.documents.take(8).toList();
                  final allIds = recentDocs.map((doc) => doc.id).toList();
                  notifier.selectAll(allIds);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                areAllSelected ? 'Deselect All' : 'Select All',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 100,
        title: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/searchscreen'),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 20),
                        Icon(
                          Icons.search_rounded,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Search documents...',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Global sync status indicator
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: GlobalSyncStatusIndicator(),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  gradient: AppDesign.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const PremiumModal(),
                    );
                  },
                  icon: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                  ),
                  iconSize: 26,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget? _buildBottomBar(
    BuildContext context,
    WidgetRef ref,
    HomeState state,
    HomeNotifier notifier,
  ) {
    if (state.isSelectionMode) {
      return _PremiumSelectionActionBar(
        onDelete: () => _deleteSelectedDocuments(context, ref, state, notifier),
        onShare: () => _shareSelectedDocuments(context, ref, state),
      );
    }
    return null;
  }

  Future<void> _deleteSelectedDocuments(
    BuildContext context,
    WidgetRef ref,
    HomeState state,
    HomeNotifier notifier,
  ) async {
    final count = state.selectedScanIds.length;
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surface.withOpacity(0.98),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.errorContainer.withOpacity(0.2),
                      theme.colorScheme.error.withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.warning_2,
                  size: 36,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Delete ${count == 1 ? 'Document' : 'Documents'}?',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                'Are you sure you want to delete $count document${count == 1 ? '' : 's'}? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.outline.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.error.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.trash, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        for (final id in state.selectedScanIds) {
          await DocumentService.instance.deleteDocument(id);
        }
        notifier.exitSelectionMode();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count documents deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting documents: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _shareSelectedDocuments(
    BuildContext context,
    WidgetRef ref,
    HomeState state,
  ) async {
    try {
      // Get selected documents from paginated state
      final paginatedState = ref.read(currentPaginatedDocumentsProvider);
      final selectedDocs = paginatedState.documents
          .where((doc) => state.selectedScanIds.contains(doc.id))
          .toList();

      if (selectedDocs.isEmpty) return;

      final files = selectedDocs.map((doc) => XFile(doc.filePath)).toList();

      await ShareUtils.shareFiles(
        files,
        text: 'Check out these scanned documents!',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing documents: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Premium Selection Action Bar
class _PremiumSelectionActionBar extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _PremiumSelectionActionBar({
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colorScheme.surface.withOpacity(0.98), colorScheme.surface],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 40,
            spreadRadius: -5,
            offset: const Offset(0, -12),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PremiumActionButton(
              icon: Iconsax.send_2,
              label: 'Share',
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorScheme.primary, colorScheme.primaryContainer],
              ),
              onTap: onShare,
            ),
            Container(
              width: 1,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.outline.withOpacity(0.1),
                    colorScheme.outline.withOpacity(0.3),
                    colorScheme.outline.withOpacity(0.1),
                  ],
                ),
              ),
            ),
            _PremiumActionButton(
              icon: Iconsax.trash,
              label: 'Delete',
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.error,
                  Color.lerp(colorScheme.error, Colors.orange, 0.3)!,
                ],
              ),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  const _PremiumActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: gradient.colors.first.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorScheme.onPrimary.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: gradient.colors.first),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dynamic greeting text widget with smooth fade animation
/// Updates automatically when greeting changes (time boundaries or login/logout)
class _DynamicGreetingText extends ConsumerStatefulWidget {
  final ColorScheme colorScheme;

  const _DynamicGreetingText({required this.colorScheme});

  @override
  ConsumerState<_DynamicGreetingText> createState() =>
      _DynamicGreetingTextState();
}

class _DynamicGreetingTextState extends ConsumerState<_DynamicGreetingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _currentGreeting = '';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch greeting stream for automatic updates
    final greetingAsync = ref.watch(greetingProvider);

    return greetingAsync.when(
      data: (greeting) {
        // If greeting changed, animate fade out/in
        if (greeting != _currentGreeting && _currentGreeting.isNotEmpty) {
          _fadeController.forward(from: 0.0);
          _currentGreeting = greeting;
        } else if (_currentGreeting.isEmpty) {
          // Initial load
          _currentGreeting = greeting;
        }

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            _currentGreeting,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: widget.colorScheme.onBackground,
              letterSpacing: -0.8,
            ),
          ),
        );
      },
      loading: () {
        // Show initial greeting while loading
        final initialGreeting = ref.read(currentGreetingProvider);
        if (_currentGreeting.isEmpty) {
          _currentGreeting = initialGreeting;
        }
        return Text(
          _currentGreeting,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: widget.colorScheme.onBackground,
            letterSpacing: -0.8,
          ),
        );
      },
      error: (error, stack) {
        // Fallback to current greeting on error
        final fallbackGreeting = ref.read(currentGreetingProvider);
        return Text(
          fallbackGreeting,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: widget.colorScheme.onBackground,
            letterSpacing: -0.8,
          ),
        );
      },
    );
  }
}
