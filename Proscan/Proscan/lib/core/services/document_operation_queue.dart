import 'dart:async';
import 'dart:collection';

class DocumentOperationQueue {
  DocumentOperationQueue._();
  static final DocumentOperationQueue instance = DocumentOperationQueue._();

  final _queue = Queue<_QueuedOperation<dynamic>>();
  bool _isProcessing = false;

  Future<T> enqueue<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _queue.add(_QueuedOperation<T>(operation, completer));
    _processQueue();
    return completer.future;
  }

  void _processQueue() {
    if (_isProcessing) return;
    if (_queue.isEmpty) return;
    _isProcessing = true;

    scheduleMicrotask(() async {
      while (_queue.isNotEmpty) {
        final op = _queue.removeFirst();
        try {
          final value = await op.operation();
          op.completer.complete(value);
        } catch (e, stack) {
          op.completer.completeError(e, stack);
        }
      }
      _isProcessing = false;
    });
  }
}

class _QueuedOperation<T> {
  _QueuedOperation(this.operation, this.completer);

  final Future<T> Function() operation;
  final Completer<T> completer;
}
