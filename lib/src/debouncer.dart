import 'dart:async' show FutureOr, Timer, Completer;

typedef Debounceable<S extends Object?, T> = FutureOr<S> Function(T parameter);

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
    } on Exception catch (error) {
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
  DebounceTimer get current {
    if (_innerTimer == null) {
      _innerTimer = DebounceTimer(duration: duration);
      return _innerTimer!;
    } else {
      return _innerTimer!;
    }
  }

  /// Returns a new [DebounceTimer] instance.
  DebounceTimer get fresh {
    _innerTimer = DebounceTimer(duration: duration);
    return _innerTimer!;
  }

  /// Cancels the current [DebounceTimer] instance.
  void dispose() {
    _innerTimer?.cancel();
  }

  /// Cancels the current [DebounceTimer] instance.
  void cancel() {
    _innerTimer?.cancel();
  }
}

/// Returns a new function that is a debounced version of the given function.
///
/// This means that the original function will be called only after no calls
/// have been made for the given Duration.

// A wrapper around Timer used for debouncing.
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
    if (_timer.isActive) _timer.cancel();
    if (!_completer.isCompleted) {
      _completer.completeError(const DebounceCancelException());
    }
  }
}

// An exception indicating that the timer was canceled.
class DebounceCancelException implements Exception {
  const DebounceCancelException();
}
