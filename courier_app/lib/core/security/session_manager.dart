import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing user sessions with timeout
/// Handles session lifecycle, timeout, and automatic logout
abstract class SessionManager {
  /// Start a new session
  Future<void> startSession(String userId);

  /// End the current session
  Future<void> endSession();

  /// Check if session is active
  Future<bool> isSessionActive();

  /// Get current session user ID
  Future<String?> getCurrentUserId();

  /// Refresh session activity (reset timeout)
  Future<void> refreshActivity();

  /// Get time remaining until session expires
  Duration getTimeRemaining();

  /// Listen to session timeout events
  Stream<SessionEvent> get sessionEvents;
}

/// Implementation of SessionManager
class SessionManagerImpl implements SessionManager {
  final FlutterSecureStorage _storage;
  final Duration _sessionTimeout;
  final Duration _warningThreshold;

  Timer? _timeoutTimer;
  Timer? _warningTimer;
  DateTime? _lastActivity;
  String? _currentUserId;

  final StreamController<SessionEvent> _eventController =
      StreamController<SessionEvent>.broadcast();

  static const String _keyLastActivity = 'session_last_activity';
  static const String _keyUserId = 'session_user_id';

  SessionManagerImpl({
    required FlutterSecureStorage storage,
    Duration? sessionTimeout,
    Duration? warningThreshold,
  })  : _storage = storage,
        _sessionTimeout = sessionTimeout ?? const Duration(minutes: 30),
        _warningThreshold = warningThreshold ?? const Duration(minutes: 5);

  @override
  Future<void> startSession(String userId) async {
    _currentUserId = userId;
    _lastActivity = DateTime.now();

    await _storage.write(key: _keyUserId, value: userId);
    await _storage.write(
      key: _keyLastActivity,
      value: _lastActivity!.toIso8601String(),
    );

    _startTimers();
    _eventController.add(SessionStarted(userId));
  }

  @override
  Future<void> endSession() async {
    _stopTimers();

    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyLastActivity);

    final userId = _currentUserId;
    _currentUserId = null;
    _lastActivity = null;

    if (userId != null) {
      _eventController.add(SessionEnded(userId));
    }
  }

  @override
  Future<bool> isSessionActive() async {
    final userId = await _storage.read(key: _keyUserId);
    if (userId == null) return false;

    final lastActivityStr = await _storage.read(key: _keyLastActivity);
    if (lastActivityStr == null) return false;

    try {
      final lastActivity = DateTime.parse(lastActivityStr);
      final elapsed = DateTime.now().difference(lastActivity);

      if (elapsed > _sessionTimeout) {
        await endSession();
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String?> getCurrentUserId() async {
    if (_currentUserId != null) return _currentUserId;

    final isActive = await isSessionActive();
    if (!isActive) return null;

    _currentUserId = await _storage.read(key: _keyUserId);
    return _currentUserId;
  }

  @override
  Future<void> refreshActivity() async {
    if (_currentUserId == null) return;

    _lastActivity = DateTime.now();
    await _storage.write(
      key: _keyLastActivity,
      value: _lastActivity!.toIso8601String(),
    );

    // Restart timers
    _stopTimers();
    _startTimers();

    _eventController.add(SessionRefreshed(_currentUserId!));
  }

  @override
  Duration getTimeRemaining() {
    if (_lastActivity == null) return Duration.zero;

    final elapsed = DateTime.now().difference(_lastActivity!);
    final remaining = _sessionTimeout - elapsed;

    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  Stream<SessionEvent> get sessionEvents => _eventController.stream;

  void _startTimers() {
    // Warning timer
    final warningDuration = _sessionTimeout - _warningThreshold;
    _warningTimer = Timer(warningDuration, () {
      if (_currentUserId != null) {
        _eventController.add(
          SessionWarning(_currentUserId!, _warningThreshold),
        );
      }
    });

    // Timeout timer
    _timeoutTimer = Timer(_sessionTimeout, () async {
      if (_currentUserId != null) {
        final userId = _currentUserId!;
        _eventController.add(SessionTimeout(userId));
        await endSession();
      }
    });
  }

  void _stopTimers() {
    _timeoutTimer?.cancel();
    _warningTimer?.cancel();
    _timeoutTimer = null;
    _warningTimer = null;
  }

  void dispose() {
    _stopTimers();
    _eventController.close();
  }
}

/// Base class for session events
abstract class SessionEvent {
  final String userId;
  final DateTime timestamp;

  SessionEvent(this.userId) : timestamp = DateTime.now();
}

/// Session started event
class SessionStarted extends SessionEvent {
  SessionStarted(super.userId);
}

/// Session ended event
class SessionEnded extends SessionEvent {
  SessionEnded(super.userId);
}

/// Session refreshed event
class SessionRefreshed extends SessionEvent {
  SessionRefreshed(super.userId);
}

/// Session timeout warning event
class SessionWarning extends SessionEvent {
  final Duration timeRemaining;

  SessionWarning(super.userId, this.timeRemaining);
}

/// Session timeout event
class SessionTimeout extends SessionEvent {
  SessionTimeout(super.userId);
}

/// Configuration for session management
class SessionConfig {
  /// Duration before session expires
  final Duration sessionTimeout;

  /// Duration before timeout to show warning
  final Duration warningThreshold;

  /// Whether to auto-refresh on user activity
  final bool autoRefreshOnActivity;

  const SessionConfig({
    this.sessionTimeout = const Duration(minutes: 30),
    this.warningThreshold = const Duration(minutes: 5),
    this.autoRefreshOnActivity = true,
  });

  /// Production configuration (30 min timeout)
  static const SessionConfig production = SessionConfig(
    sessionTimeout: Duration(minutes: 30),
    warningThreshold: Duration(minutes: 5),
    autoRefreshOnActivity: true,
  );

  /// Development configuration (longer timeout)
  static const SessionConfig development = SessionConfig(
    sessionTimeout: Duration(hours: 2),
    warningThreshold: Duration(minutes: 10),
    autoRefreshOnActivity: true,
  );

  /// Strict configuration (15 min timeout)
  static const SessionConfig strict = SessionConfig(
    sessionTimeout: Duration(minutes: 15),
    warningThreshold: Duration(minutes: 3),
    autoRefreshOnActivity: true,
  );
}
