// Heartbeat base de données (touch_presence) : pur dart:async, sans Flutter
// ni Supabase en dur (le beat est injecté). Testable avec fake_async.
// Best-effort : un beat raté ne crashe rien et n'arrête pas le timer.
import 'dart:async';

class GameHeartbeat {
  final Future<void> Function() onBeat;
  final Duration interval;
  final DateTime Function() now;

  Timer? _timer;
  bool _inFlight = false;
  bool _disposed = false;
  DateTime? _lastOkAt;
  Object? _lastError;

  GameHeartbeat({
    required this.onBeat,
    this.interval = const Duration(seconds: 15),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  bool get isRunning => _timer != null;
  DateTime? get lastOkAt => _lastOkAt;
  Object? get lastError => _lastError;

  /// Démarre (une fois ; sans effet si déjà actif). Premier beat immédiat.
  void start({bool immediate = true}) {
    if (_disposed || isRunning) return;
    if (immediate) {
      _fire();
    }
    _timer = Timer.periodic(interval, (_) => _fire());
  }

  Future<void> _fire() async {
    if (_inFlight || _disposed) return;
    _inFlight = true;
    try {
      await onBeat();
      _lastOkAt = now();
      _lastError = null;
    } catch (e) {
      _lastError = e;
    } finally {
      _inFlight = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    stop();
  }
}
