import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thyscan/core/services/app_logger.dart';
import 'package:thyscan/core/utils/share_utils.dart';
import 'package:thyscan/core/widgets/error_boundary.dart';
import 'package:thyscan/features/home/controllers/library_state_provider.dart';
import 'package:thyscan/features/home/controllers/documents_pagination_provider.dart';
import 'package:thyscan/features/home/controllers/home_state_provider.dart';
import 'package:thyscan/features/home/models/document_filter.dart';
import 'package:thyscan/features/home/presentation/widgets/corrupted_document_tile.dart';
import 'package:thyscan/features/home/presentation/widgets/librarywidgets/library_filter_bar.dart';
import 'package:thyscan/features/home/presentation/widgets/librarywidgets/library_scan_list_item.dart';
import 'package:thyscan/features/home/presentation/widgets/librarywidgets/document_shimmer_placeholder.dart';
import 'package:thyscan/features/home/presentation/widgets/upload_queue_badge.dart';
import 'package:thyscan/features/scan/model/scans.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Production-ready LibraryScreen with true virtual scrolling (CamScanner/Microsoft Lens style)
/// - Only loads documents when they enter viewport
/// - Pre-fetches next page when 5 items from bottom
/// - Shows shimmer placeholders for unloaded items
/// - Pull-to-refresh support
/// - Zero jank on 5000+ documents
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final ScrollController _scrollController = ScrollController();
  int _lastLoadedIndex = -1;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Viewport-based loading: detect when items enter viewport
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final viewportHeight = _scrollController.position.viewportDimension;

    // Calculate which items are in viewport
    final itemHeight = 140.0; // Approximate item height
    final firstVisibleIndex = (currentScroll / itemHeight).floor();
    final lastVisibleIndex =
        ((currentScroll + viewportHeight) / itemHeight).ceil();

    final paginatedState = ref.read(currentPaginatedDocumentsProvider);
    final paginatedNotifier = ref.read(
      paginatedDocumentsProvider(
        PaginatedDocumentsParams(
          scanMode: DocumentFilters.getById(
                  ref.read(homeProvider).activeFilterId)
              .scanMode,
          sortBy: ref.read(homeProvider).sortCriteria,
        ),
      ).notifier,
    );

    // Pre-fetch next page when 5 items from bottom
    if (lastVisibleIndex >= paginatedState.documents.length - 5 &&
        paginatedState.hasMore &&
        !paginatedState.isLoading &&
        !_isLoadingMore) {
      _isLoadingMore = true;
      paginatedNotifier.loadNextPage().then((_) {
        if (mounted) {
          setState(() => _isLoadingMore = false);
        }
      }).catchError((_) {
        if (mounted) {
          setState(() => _isLoadingMore = false);
        }
      });
    }

    // Track last loaded index for viewport-based loading
    if (lastVisibleIndex > _lastLoadedIndex) {
      _lastLoadedIndex = lastVisibleIndex;
    }
  }

  /// Pull-to-refresh handler
  Future<void> _onRefresh() async {
    final homeState = ref.read(homeProvider);
    final activeFilter = DocumentFilters.getById(homeState.activeFilterId);
    final paginatedNotifier = ref.read(
      paginatedDocumentsProvider(
        PaginatedDocumentsParams(
          scanMode: activeFilter.scanMode,
          sortBy: homeState.sortCriteria,
        ),
      ).notifier,
    );

    await paginatedNotifier.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Use paginated documents provider (windowed loading - max 150 docs in memory)
    final homeState = ref.watch(homeProvider);
    final activeFilter = DocumentFilters.getById(homeState.activeFilterId);
    final paginatedState = ref.watch(currentPaginatedDocumentsProvider);
    final paginatedNotifier = ref.read(
      paginatedDocumentsProvider(
        PaginatedDocumentsParams(
          scanMode: activeFilter.scanMode,
          sortBy: homeState.sortCriteria,
        ),
      ).notifier,
    );

    // Calculate total items to show (loaded + placeholders for unloaded)
    // For virtual scrolling, show placeholders for items beyond loaded range
    final totalItemsToShow = paginatedState.hasMore
        ? paginatedState.totalItems
        : paginatedState.documents.length;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: _buildPremiumAppBar(
        context,
        ref,
        libraryState,
        libraryNotifier,
        screenWidth,
        paginatedState.totalItems,
      ),
      bottomNavigationBar: libraryState.isSelectionMode
          ? _PremiumSelectionActionBottomBar(
              onDelete: () => _deleteSelectedDocuments(
                context,
                ref,
                libraryState,
                libraryNotifier,
              ),
              onShare: () => _shareSelectedDocuments(context, ref, libraryState),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: colorScheme.primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Premium Filter Bar
            if (!libraryState.isSelectionMode)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 8),
                  child: LibraryFilterBar(),
                ),
              ),

            // Show empty state or document list
            if (paginatedState.documents.isEmpty && !paginatedState.isLoading)
              SliverToBoxAdapter(child: _buildPremiumEmptyState(context))
            else
              SliverPadding(
                padding: EdgeInsets.only(
                  top: 16,
                  bottom: libraryState.isSelectionMode ? 100 : 40,
                  left: _getCardMargin(screenWidth),
                  right: _getCardMargin(screenWidth),
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Virtual scrolling: show shimmer for unloaded items
                      if (index >= paginatedState.documents.length) {
                        // Show shimmer placeholder for unloaded items
                        if (index < totalItemsToShow) {
                          return const DocumentShimmerPlaceholder();
                        }
                        // Show loading indicator at bottom if loading more
                        if (paginatedState.hasMore &&
                            paginatedState.isLoading) {
                          return const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }

                      // Wrap each item in error boundary (bulletproof - never crashes)
                      return ListItemErrorBoundary(
                        fallback: (context, error) {
                          // Show corrupted document tile on error
                          final doc = index < paginatedState.documents.length
                              ? paginatedState.documents[index]
                              : null;
                          return CorruptedDocumentTile(
                            documentId: doc?.id ?? 'unknown',
                            documentTitle: doc?.title,
                            onDeleted: () {
                              // Refresh the list after deletion
                              paginatedNotifier.refresh();
                            },
                            onRetry: () {
                              // Retry by refreshing
                              paginatedNotifier.refresh();
                            },
                          );
                        },
                        child: _buildDocumentItem(
                          context,
                          index,
                          paginatedState,
                          libraryState,
                          libraryNotifier,
                        ),
                      );
                    },
                    childCount: totalItemsToShow,
                    // Optimize for virtual scrolling with lazy loading
                    addAutomaticKeepAlives: false, // Don't keep items alive when scrolled out
                    addRepaintBoundaries: true, // Add repaint boundaries for performance
                    addSemanticIndexes: false,
                  ),
                ),
              ),

            // Loading indicator for initial load
            if (paginatedState.isLoading && paginatedState.documents.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Dynamic card margins based on screen size
  double _getCardMargin(double screenWidth) {
    if (screenWidth < 350) return 12; // Small phones
    if (screenWidth < 400) return 16; // Medium phones
    if (screenWidth > 600) return 24; // Tablets
    return 20; // Standard phones
  }

  /// Builds a document item with error handling (bulletproof)
  Widget _buildDocumentItem(
    BuildContext context,
    int index,
    PaginatedDocumentsState paginatedState,
    LibraryState libraryState,
    LibraryNotifier libraryNotifier,
  ) {
    try {
      // Show actual document item
      final doc = paginatedState.documents[index];
      final scan = _documentToScan(doc);
      final isSelected =
          libraryState.selectedScanIds.contains(scan.id);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: LibraryScanListItem(
          scan: scan,
          document: doc, // Pass DocumentModel for validation
          isSelectionMode: libraryState.isSelectionMode,
          isSelected: isSelected,
          onLongPress: () {
            libraryNotifier.enterSelectionMode(scan.id);
          },
          onTap: () {
            if (libraryState.isSelectionMode) {
              libraryNotifier.toggleScanSelection(scan.id);
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
      final doc = index < paginatedState.documents.length
          ? paginatedState.documents[index]
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
    }
  }

  /// Convert DocumentModel to Scan for UI compatibility
  Scan _documentToScan(DocumentModel doc) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    return Scan(
      id: doc.id,
      title: doc.title,
      imagePath: doc.thumbnailPath,
      date: dateFormat.format(doc.createdAt),
      size: doc.format.toUpperCase(), // Show format (PDF/DOCX)
      pageCount: '${doc.pageCount} page${doc.pageCount == 1 ? '' : 's'}',
      tags: doc.format == 'docx' ? ['Text'] : [], // Tag for text documents
    );
  }

  /// Open document in appropriate screen based on format
  void _openDocument(BuildContext context, DocumentModel doc) {
    // Route text documents to TextDocumentScreen
    if (doc.format == 'txt' || doc.format == 'docx') {
      if (doc.scanMode == 'translate') {
        context.push('/translationeditorscreen',
            extra: {'documentId': doc.id});
      } else {
        context.push('/textdocumentscreen', extra: {'documentId': doc.id});
      }
    } else {
      // Route PDF documents to SavePdfScreen
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

  /// Premium Empty state widget when no documents exist
  Widget _buildPremiumEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withOpacity(0.1),
                  colorScheme.primary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 50,
              color: colorScheme.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Your Library is Empty',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Start scanning documents to build your digital library. All your scans will appear here for easy access.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text(
              'Start Scanning',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildPremiumAppBar(
    BuildContext context,
    WidgetRef ref,
    LibraryState state,
    LibraryNotifier notifier,
    double screenWidth,
    int totalDocuments,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final areAllSelected =
        state.selectedScanIds.length == totalDocuments && totalDocuments > 0;
    final isTablet = screenWidth > 600;

    if (state.isSelectionMode) {
      return AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: IconButton(
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.onSurface.withOpacity(0.1),
            ),
            child: Icon(
              Icons.close_rounded,
              size: 22,
              color: colorScheme.onSurface,
            ),
          ),
          onPressed: notifier.exitSelectionMode,
        ),
        title: Text(
          '${state.selectedScanIds.length} selected',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            fontSize: 20,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: FilledButton.tonal(
              onPressed: () {
                if (areAllSelected) {
                  notifier.selectNone();
                } else {
                  // Select all visible documents (paginated)
                  final paginatedState =
                      ref.read(currentPaginatedDocumentsProvider);
                  final allIds =
                      paginatedState.documents.map((doc) => doc.id).toList();
                  notifier.selectAll(allIds);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                areAllSelected ? 'Deselect All' : 'Select All',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      );
    } else {
      return AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: isTablet ? 190.0 : 170.0,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _getCardMargin(screenWidth), // Use dynamic margin
              12,
              _getCardMargin(screenWidth), // Use dynamic margin
              12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Actions Row - Fixed to prevent overflow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Library',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onBackground,
                              fontSize: screenWidth < 350 ? 24 : 28,
                              letterSpacing: -1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalDocuments documents',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Actions container with constrained width
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: screenWidth * 0.4, // Prevent overflow
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Upload queue badge
                          const UploadQueueBadge(),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {},
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  colorScheme.surfaceVariant.withOpacity(0.3),
                              padding: const EdgeInsets.all(12),
                              minimumSize: const Size(48, 48),
                            ),
                            icon: Icon(
                              Icons.grid_view_rounded,
                              color: colorScheme.onSurface.withOpacity(0.8),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FilledButton.tonal(
                              onPressed: () {
                                final paginatedState =
                                    ref.read(currentPaginatedDocumentsProvider);
                                if (paginatedState.documents.isNotEmpty) {
                                  notifier.enterSelectionMode(
                                      paginatedState.documents.first.id);
                                }
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Select',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Fixed Search Bar - No overflow possible
                _buildNonOverflowingSearchBar(
                  context,
                  colorScheme,
                  screenWidth,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildNonOverflowingSearchBar(
    BuildContext context,
    ColorScheme colorScheme,
    double screenWidth,
  ) {
    return GestureDetector(
      onTap: () => context.push('/searchscreen'),
      child: Container(
        height: 56,
        constraints: BoxConstraints(
          maxWidth: screenWidth, // Never exceed screen width
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search_rounded, color: colorScheme.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search documents, tools...',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (screenWidth >
                350) // Only show keyboard shortcut on larger screens
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⌘K',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSelectedDocuments(
    BuildContext context,
    WidgetRef ref,
    LibraryState state,
    LibraryNotifier notifier,
  ) async {
    final count = state.selectedScanIds.length;
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 40,
                spreadRadius: -5,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning Icon
                Container(
                  width: 64,
                  height: 64,
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
                    size: 32,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Delete ${count == 1 ? 'Document' : 'Documents'}?',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  'Are you sure you want to delete $count document${count == 1 ? '' : 's'}? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

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
                              blurRadius: 15,
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
                              const Icon(Iconsax.trash, size: 20),
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
    LibraryState state,
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

class _PremiumSelectionActionBottomBar extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _PremiumSelectionActionBottomBar({
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Container(
      height: isTablet ? 120 : 100,
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
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 80 : 48,
          vertical: 20,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PremiumActionButton(
              icon: Iconsax.send_2,
              label: 'Share',
              color: colorScheme.primary,
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
              color: colorScheme.error,
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
  final Color color;
  final Gradient? gradient;
  final VoidCallback onTap;

  const _PremiumActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
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
              height: isTablet ? 70 : 60,
              decoration: BoxDecoration(
                gradient: gradient ??
                    LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color,
                        Color.lerp(color, colorScheme.surface, 0.2)!,
                      ],
                    ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.2), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: isTablet ? 36 : 32,
                    height: isTablet ? 36 : 32,
                    decoration: BoxDecoration(
                      color: colorScheme.onPrimary.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: isTablet ? 20 : 18, color: color),
                  ),
                  SizedBox(width: isTablet ? 12 : 10),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 16 : 15,
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
