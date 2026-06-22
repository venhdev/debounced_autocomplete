import 'dart:async' show FutureOr, Timer, Completer;

typedef Debounceable<S, T> = FutureOr<S> Function(T parameter);

/// Returns a new function that is a debounced version of the given function.
///
/// The wrapped function is invoked only after no calls have been made for
/// the controller's configured [Duration]; earlier pending calls are
/// cancelled and resolve to `null` without invoking the wrapped function.
/// Any error thrown by the wrapped function is rethrown to the caller of
/// the debounced wrapper.
Debounceable<S, T> debounceFunction<S, T>(
  Debounceable<S, T> function, {
  required DebounceController controller,
}) {
  DebounceTimer? timer;

  return (T parameter) async {
    if (timer != null && !timer!.isCompleted) {
      timer!.cancel();
    }
    timer = controller.fresh;
    try {
      await timer!.future;
    } catch (error) {
      if (error is DebounceCancelException) {
        return Future.value(null);
      }
      rethrow;
    }
    return function(parameter);
  };
}

class DebounceController {
  DebounceController({this.duration = const Duration(milliseconds: 1000)});

  final Duration duration;
  DebounceTimer? _innerTimer;

  /// Returns the current [DebounceTimer] instance.
  DebounceTimer get current => _innerTimer ??= DebounceTimer(duration: duration);

  /// Returns a new [DebounceTimer] instance.
  DebounceTimer get fresh {
    _innerTimer = DebounceTimer(duration: duration);
    return _innerTimer!;
  }

  /// Cancels the current [DebounceTimer] instance.
  void dispose() => cancel();

  /// Cancels the current [DebounceTimer] instance, if any.
  ///
  /// After [cancel], the next call to [current] lazily constructs a fresh
  /// timer. Without this, callers would receive a dead [DebounceTimer]
  /// whose [DebounceTimer.future] is already completed with a
  /// [DebounceCancelException], silently swallowing the next wrapped call.
  void cancel() {
    _innerTimer?.cancel();
    _innerTimer = null;
  }
}

/// A wrapper around [Timer] used for debouncing.
///
/// Exposes a [Future] that completes when the underlying timer fires,
/// and a [cancel] method that completes the future with a
/// [DebounceCancelException].
class DebounceTimer {
  DebounceTimer({required Duration duration}) {
    _timer = Timer(duration, _onComplete);
  }

  late final Timer _timer;
  final Completer<void> _completer = Completer<void>();

  void _onComplete() {
    _completer.complete();
  }

  Future<void> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void cancel() {
    // Order matters: cancel the underlying Timer first so its natural
    // callback can't later call `_completer.complete()` on an
    // already-error-completed future. `Timer.cancel` is a no-op on
    // completed timers, so no `isActive` guard is needed.
    _timer.cancel();
    if (!_completer.isCompleted) {
      _completer.completeError(const DebounceCancelException());
    }
  }
}

/// An exception indicating that the timer was canceled.
class DebounceCancelException implements Exception {
  const DebounceCancelException();
}
