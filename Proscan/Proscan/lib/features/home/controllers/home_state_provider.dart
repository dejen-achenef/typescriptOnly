import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SortCriteria {
  date,
  size,
  pages,
}

class HomeState {
  final bool isSelectionMode;
  final Set<String> selectedScanIds;
  final SortCriteria sortCriteria;
  final String activeFilterId;

  const HomeState({
    this.isSelectionMode = false,
    this.selectedScanIds = const {},
    this.sortCriteria = SortCriteria.date,
    this.activeFilterId = 'all',
  });

  HomeState copyWith({
    bool? isSelectionMode,
    Set<String>? selectedScanIds,
    SortCriteria? sortCriteria,
    String? activeFilterId,
  }) {
    return HomeState(
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedScanIds: selectedScanIds ?? this.selectedScanIds,
      sortCriteria: sortCriteria ?? this.sortCriteria,
      activeFilterId: activeFilterId ?? this.activeFilterId,
    );
  }
}

// 2. CREATE THE NOTIFIER
class HomeNotifier extends Notifier<HomeState> {
  @override
  HomeState build() {
    return const HomeState(); // Initial state
  }

  // Enters selection mode and selects the first item
  void enterSelectionMode(String initialScanId) {
    state = state.copyWith(
      isSelectionMode: true,
      selectedScanIds: {initialScanId},
    );
  }

  // Exits selection mode and clears all selections
  void exitSelectionMode() {
    state = state.copyWith(isSelectionMode: false, selectedScanIds: {});
  }

  // Toggles the selection status of a single scan
  void toggleScanSelection(String scanId) {
    if (!state.isSelectionMode) return; // Safety check

    final newSet = Set<String>.from(state.selectedScanIds);
    if (newSet.contains(scanId)) {
      newSet.remove(scanId);
    } else {
      newSet.add(scanId);
    }

    // If the last item is deselected, exit selection mode automatically
    if (newSet.isEmpty) {
      exitSelectionMode();
    } else {
      state = state.copyWith(selectedScanIds: newSet);
    }
  }

  // TODO: Implement select all logic if needed
  void selectAll(List<String> allScanIds) {
    state = state.copyWith(selectedScanIds: allScanIds.toSet());
  }

  void setSortCriteria(SortCriteria criteria) {
    state = state.copyWith(sortCriteria: criteria);
  }

  void setActiveFilter(String filterId) {
    state = state.copyWith(activeFilterId: filterId);
  }
}

// 3. CREATE THE PROVIDER
final homeProvider = NotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);
