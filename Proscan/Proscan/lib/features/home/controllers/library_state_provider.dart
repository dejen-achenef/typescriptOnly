import 'package:flutter_riverpod/flutter_riverpod.dart';

// Define the state for the Library screen
class LibraryState {
  final bool isSelectionMode;
  final Set<String> selectedScanIds;

  const LibraryState({
    this.isSelectionMode = false,
    this.selectedScanIds = const {},
  });

  LibraryState copyWith({
    bool? isSelectionMode,
    Set<String>? selectedScanIds,
  }) {
    return LibraryState(
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedScanIds: selectedScanIds ?? this.selectedScanIds,
    );
  }
}

// Create the Notifier
class LibraryNotifier extends Notifier<LibraryState> {
  @override
  LibraryState build() {
    return const LibraryState(); // Initial state is not in selection mode
  }

  void enterSelectionMode(String initialScanId) {
    state = state.copyWith(
      isSelectionMode: true,
      selectedScanIds: {initialScanId},
    );
  }

  void exitSelectionMode() {
    state = state.copyWith(isSelectionMode: false, selectedScanIds: {});
  }

  void toggleScanSelection(String scanId) {
    if (!state.isSelectionMode) return;

    final newSet = Set<String>.from(state.selectedScanIds);
    if (newSet.contains(scanId)) {
      newSet.remove(scanId);
    } else {
      newSet.add(scanId);
    }

    if (newSet.isEmpty) {
      exitSelectionMode();
    } else {
      state = state.copyWith(selectedScanIds: newSet);
    }
  }

  void selectAll(List<String> allScanIds) {
    state = state.copyWith(selectedScanIds: allScanIds.toSet());
  }

  void selectNone() {
    state = state.copyWith(selectedScanIds: {});
  }
}

// Create the final provider
final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(
  LibraryNotifier.new,
);
