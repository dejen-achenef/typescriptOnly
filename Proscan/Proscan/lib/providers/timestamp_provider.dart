import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'
    show StateNotifier, StateNotifierProvider;
import 'package:thyscan/services/timestamp_service.dart';

/// Simple provider exposing the [TimestampService].
final timestampServiceProvider = Provider<TimestampService>((ref) {
  return TimestampService();
});

/// Notifier managing timestamp image processing and exposing a loading state.
class TimestampController extends StateNotifier<bool> {
  TimestampController(this._service) : super(false);

  final TimestampService _service;

  /// Returns `true` when processing is in progress.
  bool get isProcessing => state;

  /// Adds a timestamp overlay to [bytes], updating [state] while processing.
  Future<Uint8List> addTimestamp(Uint8List bytes) async {
    state = true;
    try {
      return await _service.addTimestampToImage(bytes);
    } finally {
      state = false;
    }
  }
}

/// Riverpod provider exposing the [TimestampController] and its loading state.
///
/// The state (`bool`) represents whether timestamp processing is currently
/// running; use the notifier to trigger processing.
final timestampControllerProvider =
    StateNotifierProvider<TimestampController, bool>((ref) {
      final service = ref.read(timestampServiceProvider);
      return TimestampController(service);
    });
