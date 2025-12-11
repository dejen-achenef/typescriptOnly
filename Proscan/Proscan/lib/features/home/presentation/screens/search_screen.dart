import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:thyscan/core/services/recent_searches_service.dart';
import 'package:thyscan/features/home/controllers/search_provider.dart';
import 'package:thyscan/features/home/presentation/widgets/advanced_search_filters.dart';
import 'package:thyscan/features/home/presentation/widgets/cached_thumbnail.dart';
import 'package:thyscan/features/home/presentation/widgets/search_autocomplete.dart';
import 'package:thyscan/features/home/presentation/widgets/search_result_highlighter.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<ToolItem> _toolResults = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Advanced filters state
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int? _minPages;
  int? _maxPages;
  bool _showAdvancedFilters = false;

  // Available tools
  final List<ToolItem> _allTools = [
    ToolItem(
      name: 'Scan Document',
      icon: Icons.document_scanner_rounded,
      description: 'Scan a new document',
      route: '/camerascreen',
      color: Colors.blue,
    ),
    ToolItem(
      name: 'Extract Text',
      icon: Icons.text_fields_rounded,
      description: 'Extract text from image',
      route: '/camerascreen',
      color: Colors.green,
    ),
    ToolItem(
      name: 'Translate',
      icon: Icons.translate_rounded,
      description: 'Translate text',
      route: '/translationeditorscreen',
      color: Colors.purple,
    ),
    ToolItem(
      name: 'ID Scanner',
      icon: Icons.badge_rounded,
      description: 'Scan ID cards',
      route: '/camerascreen',
      color: Colors.orange,
    ),
    ToolItem(
      name: 'Receipt Scanner',
      icon: Icons.receipt_long_rounded,
      description: 'Scan receipts',
      route: '/camerascreen',
      color: Colors.teal,
    ),
    ToolItem(
      name: 'Barcode Scanner',
      icon: Icons.qr_code_scanner_rounded,
      description: 'Scan barcodes and QR codes',
      route: '/camerascreen',
      color: Colors.indigo,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _searchFocus.requestFocus();
    _searchController.addListener(_onSearchChanged);
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    // Update search query provider (debouncing handled by provider)
    ref.read(searchQueryProvider.notifier).state = query;
    // Reset page when query changes
    ref.read(searchPageProvider.notifier).state = 0;

    // Add to recent searches when user finishes typing (after debounce)
    if (query.trim().isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_searchController.text == query) {
          RecentSearchesService.instance.addSearch(query);
        }
      });
    }

    // Search tools locally (tools are not documents)
    if (query.isEmpty) {
      _toolResults = [];
    } else {
      final queryLower = query.toLowerCase();
      _toolResults = _allTools.where((tool) {
        return tool.name.toLowerCase().contains(queryLower) ||
            tool.description.toLowerCase().contains(queryLower);
      }).toList();
    }
  }

  void _onSuggestionTap(String suggestion) {
    _searchController.text = suggestion;
    ref.read(searchQueryProvider.notifier).state = suggestion;
    ref.read(searchPageProvider.notifier).state = 0;
    RecentSearchesService.instance.addSearch(suggestion);
    _searchFocus.unfocus();
  }

  void _onRecentSearchTap(String search) {
    _searchController.text = search;
    ref.read(searchQueryProvider.notifier).state = search;
    ref.read(searchPageProvider.notifier).state = 0;
    RecentSearchesService.instance.addSearch(search);
    _searchFocus.unfocus();
  }

  void _onRecentSearchRemove(String search) {
    RecentSearchesService.instance.removeSearch(search);
  }

  void _openDocument(DocumentModel doc) {
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

  void _openTool(ToolItem tool) {
    context.push(tool.route);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(searchPageProvider.notifier).state = 0;
    _toolResults = [];
    _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final searchQuery = ref.watch(searchQueryProvider);
    final searchResultsAsync = ref.watch(currentSearchResultsProvider);
    final isSearching = ref.watch(isSearchingProvider);
    final hasQuery = searchQuery.isNotEmpty;
    final hasResults =
        searchResultsAsync.hasValue &&
        (searchResultsAsync.value!.items.isNotEmpty || _toolResults.isNotEmpty);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Premium Search Header
            _buildPremiumSearchHeader(theme, colorScheme),

            // Autocomplete suggestions
            if (hasQuery)
              SearchAutocomplete(
                query: searchQuery,
                onSuggestionTap: _onSuggestionTap,
                onSuggestionRemove: (_) {},
              ),

            // Search results
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: !hasQuery
                    ? _buildPremiumEmptyState(colorScheme)
                    : isSearching
                    ? _buildPremiumLoadingState(colorScheme)
                    : hasResults
                    ? _buildPremiumSearchResults(
                        colorScheme,
                        searchResultsAsync.value!,
                        searchQuery,
                      )
                    : _buildPremiumNoResults(colorScheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumSearchHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Back button and title
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.6),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Search',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Premium Search Bar
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.4),
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
                  size: 26,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search documents, tools, features...',
                      hintStyle: GoogleFonts.inter(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (ref.watch(searchQueryProvider).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: _clearSearch,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumEmptyState(ColorScheme colorScheme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recent Searches Section
            RecentSearchesWidget(
              onSearchTap: _onRecentSearchTap,
              onSearchRemove: _onRecentSearchRemove,
            ),
            const SizedBox(height: 24),

            // Advanced Filters Toggle
            _buildAdvancedFiltersToggle(colorScheme),

            if (_showAdvancedFilters) ...[
              const SizedBox(height: 16),
              AdvancedSearchFilters(
                dateFrom: _dateFrom,
                dateTo: _dateTo,
                minPages: _minPages,
                maxPages: _maxPages,
                onDateFromChanged: (date) {
                  setState(() => _dateFrom = date);
                  // Trigger search with new filters
                  ref.read(searchQueryProvider.notifier).state = ref.read(
                    searchQueryProvider,
                  );
                },
                onDateToChanged: (date) {
                  setState(() => _dateTo = date);
                  ref.read(searchQueryProvider.notifier).state = ref.read(
                    searchQueryProvider,
                  );
                },
                onMinPagesChanged: (pages) {
                  setState(() => _minPages = pages);
                  ref.read(searchQueryProvider.notifier).state = ref.read(
                    searchQueryProvider,
                  );
                },
                onMaxPagesChanged: (pages) {
                  setState(() => _maxPages = pages);
                  ref.read(searchQueryProvider.notifier).state = ref.read(
                    searchQueryProvider,
                  );
                },
                onClearFilters: () {
                  setState(() {
                    _dateFrom = null;
                    _dateTo = null;
                    _minPages = null;
                    _maxPages = null;
                  });
                  ref.read(searchQueryProvider.notifier).state = ref.read(
                    searchQueryProvider,
                  );
                },
              ),
            ],

            const SizedBox(height: 24),
            _buildPremiumRecentSearchesPlaceholder(colorScheme),

            const SizedBox(height: 40),

            // Quick Actions Section
            _buildPremiumSectionTitle('Quick Actions', colorScheme),
            const SizedBox(height: 20),
            _buildPremiumQuickActionsGrid(colorScheme),

            const SizedBox(height: 40),

            // All Tools Section
            _buildPremiumSectionTitle('All Tools', colorScheme),
            const SizedBox(height: 20),
            ..._allTools.map(
              (tool) => _buildPremiumToolSuggestion(tool, colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumSectionTitle(String title, ColorScheme colorScheme) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: colorScheme.onSurface,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildPremiumRecentSearchesPlaceholder(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withOpacity(0.03),
            colorScheme.primary.withOpacity(0.01),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_rounded,
              size: 40,
              color: colorScheme.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Start your search',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find documents, tools, and features quickly\nby typing in the search bar above',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumQuickActionsGrid(ColorScheme colorScheme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.4,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        final tool = _allTools[index];
        return _buildPremiumQuickActionCard(tool, colorScheme);
      },
    );
  }

  Widget _buildPremiumQuickActionCard(ToolItem tool, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () => _openTool(tool),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tool.color.withOpacity(0.12),
              tool.color.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tool.color.withOpacity(0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tool.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tool.icon, color: tool.color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.name,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tool.description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumToolSuggestion(ToolItem tool, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
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
      child: ListTile(
        onTap: () => _openTool(tool),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tool.color.withOpacity(0.18),
                tool.color.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tool.color.withOpacity(0.2), width: 1.5),
          ),
          child: Icon(tool.icon, color: tool.color, size: 24),
        ),
        title: Text(
          tool.name,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          tool.description,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildPremiumNoResults(ColorScheme colorScheme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 60,
                  color: colorScheme.primary.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'No results found',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Try searching with different keywords\nor check your spelling',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _clearSearch,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Clear Search',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumLoadingState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'Searching...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFiltersToggle(ColorScheme colorScheme) {
    return InkWell(
      onTap: () {
        setState(() => _showAdvancedFilters = !_showAdvancedFilters);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 20, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Advanced Filters',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            Icon(
              _showAdvancedFilters
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumSearchResults(
    ColorScheme colorScheme,
    PaginatedDocuments searchResults,
    String query,
  ) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Tools section
          if (_toolResults.isNotEmpty) ...[
            _buildPremiumResultsSectionHeader(
              'Tools',
              _toolResults.length,
              colorScheme,
            ),
            const SizedBox(height: 20),
            ..._toolResults.map(
              (tool) => _buildPremiumToolResult(tool, colorScheme),
            ),
            const SizedBox(height: 32),
          ],

          // Documents section
          if (searchResults.items.isNotEmpty) ...[
            _buildPremiumResultsSectionHeader(
              'Documents',
              searchResults.totalItems,
              colorScheme,
            ),
            const SizedBox(height: 20),
            ...searchResults.items.map(
              (doc) => _buildPremiumDocumentResult(doc, colorScheme, query),
            ),

            // Load more button if there are more results
            if (searchResults.hasMore) ...[
              const SizedBox(height: 24),
              _buildLoadMoreButton(colorScheme),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton(ColorScheme colorScheme) {
    return Center(
      child: FilledButton.icon(
        onPressed: () {
          // Load next page
          final currentPage = ref.read(searchPageProvider);
          ref.read(searchPageProvider.notifier).state = currentPage + 1;
        },
        icon: const Icon(Icons.expand_more_rounded),
        label: const Text('Load More'),
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPremiumResultsSectionHeader(
    String title,
    int count,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            count.toString(),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumToolResult(ToolItem tool, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
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
      child: ListTile(
        onTap: () => _openTool(tool),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tool.color.withOpacity(0.18),
                tool.color.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tool.color.withOpacity(0.2), width: 1.5),
          ),
          child: Icon(tool.icon, color: tool.color, size: 26),
        ),
        title: Text(
          tool.name,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          tool.description,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildPremiumDocumentResult(
    DocumentModel doc,
    ColorScheme colorScheme,
    String query,
  ) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
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
      child: ListTile(
        onTap: () => _openDocument(doc),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 64,
            height: 64,
            color: colorScheme.surfaceVariant,
            child:
                doc.thumbnailPath.isNotEmpty &&
                    File(doc.thumbnailPath).existsSync()
                ? CachedThumbnail(
                    path: doc.thumbnailPath,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary.withOpacity(0.12),
                            colorScheme.primary.withOpacity(0.06),
                          ],
                        ),
                      ),
                      child: Icon(
                        doc.format == 'pdf'
                            ? Icons.picture_as_pdf_rounded
                            : Icons.description_rounded,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary.withOpacity(0.12),
                          colorScheme.primary.withOpacity(0.06),
                        ],
                      ),
                    ),
                    child: Icon(
                      doc.format == 'pdf'
                          ? Icons.picture_as_pdf_rounded
                          : Icons.description_rounded,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                  ),
          ),
        ),
        title: SearchResultHighlighter(
          text: doc.title,
          query: query,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    doc.format.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  '${doc.pageCount} page${doc.pageCount == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  dateFormat.format(doc.createdAt),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }
}

class ToolItem {
  final String name;
  final IconData icon;
  final String description;
  final String route;
  final Color color;

  ToolItem({
    required this.name,
    required this.icon,
    required this.description,
    required this.route,
    required this.color,
  });
}
