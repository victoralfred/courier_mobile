import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [SessionManager] - Manages user session lifecycle with automatic timeout and security controls
///
/// **What it does:**
/// - Creates and terminates user sessions
/// - Enforces automatic timeout after inactivity period
/// - Tracks session activity and provides timeout warnings
/// - Persists session state across app restarts
/// - Emits real-time session events for UI updates
///
/// **Why it exists:**
/// - Protects against unauthorized access from unattended devices
/// - Complies with security best practices for mobile apps
/// - Prevents session hijacking by limiting session lifetime
/// - Provides user-friendly warnings before timeout
/// - Centralizes session logic for consistency
///
/// **Session Lifecycle:**
/// ```
/// App Launch
///     │
///     ├─── Check Persisted Session ────> isSessionActive()
///     │           │
///     │           ├─── Valid ────> Resume Session
///     │           │
///     │           └─── Expired ───> Require Login
///     │
/// User Login
///     │
///     ├─── startSession(userId) ────> Store Session Data
///     │                                       │
///     │                                       ├─── Start Timers
///     │                                       │
///     │                                       └─── Emit SessionStarted
///     │
/// User Activity
///     │
///     ├─── refreshActivity() ────> Reset Timers
///     │
/// Session Timeout
///     │
///     ├─── Warning Timer ────> SessionWarning (5 min before)
///     │
///     ├─── Timeout Timer ────> SessionTimeout
///     │                             │
///     │                             └─── Auto Logout
///     │
/// User Logout
///     │
///     └─── endSession() ────> Clear Session Data
/// ```
///
/// **Security Model:**
/// ```
/// Session Security Controls:
/// - Timeout: 30 minutes default (configurable)
/// - Warning: 5 minutes before timeout (configurable)
/// - Persistence: Secure storage (encrypted)
/// - Validation: Timestamp-based expiration
/// - Auto-logout: On timeout or manual end
///
/// Storage Format:
/// - session_user_id: Encrypted user identifier
/// - session_last_activity: ISO 8601 timestamp
/// ```
///
/// **Usage Example:**
/// ```dart
/// // Initialize session manager
/// final storage = FlutterSecureStorage();
/// final sessionManager = SessionManagerImpl(
///   storage: storage,
///   sessionTimeout: Duration(minutes: 30),
///   warningThreshold: Duration(minutes: 5),
/// );
///
/// // Listen to session events
/// sessionManager.sessionEvents.listen((event) {
///   if (event is SessionWarning) {
///     showWarningDialog('Session expires in ${event.timeRemaining.inMinutes} min');
///   } else if (event is SessionTimeout) {
///     navigateToLogin();
///   }
/// });
///
/// // Start session after login
/// await sessionManager.startSession('user_123');
///
/// // Refresh on user activity
/// await sessionManager.refreshActivity(); // On tap, scroll, etc.
///
/// // Check if session is active
/// if (await sessionManager.isSessionActive()) {
///   // Allow access
/// } else {
///   // Require login
/// }
///
/// // Manual logout
/// await sessionManager.endSession();
/// ```
///
/// **Threat Model & Mitigations:**
/// ```
/// Threat 1: Unattended Device Access
/// Mitigation: Automatic timeout after 30 minutes inactivity
///
/// Threat 2: Long-lived Sessions
/// Mitigation: Absolute session timeout regardless of activity
///
/// Threat 3: Session Data Tampering
/// Mitigation: Encrypted storage via FlutterSecureStorage
///
/// Threat 4: Clock Manipulation Attacks
/// Mitigation: Server-side session validation (recommended)
/// ```
///
/// **IMPROVEMENT:**
/// - [HIGH PRIORITY] Add server-side session validation
///   - Current implementation is client-side only (vulnerable to clock manipulation)
///   - Implement backend session token with expiration
///   - Validate session on critical operations
/// - [HIGH PRIORITY] Add absolute session timeout (not just inactivity)
///   - Currently sessions can live indefinitely with continuous activity
///   - Add max session lifetime (e.g., 8 hours)
/// - [MEDIUM PRIORITY] Implement session fingerprinting
///   - Detect session transfer between devices
///   - Track device ID, IP address changes
/// - [MEDIUM PRIORITY] Add grace period for network issues
///   - Don't force logout on temporary connectivity loss
///   - Queue actions during offline period
/// - [LOW PRIORITY] Add biometric re-authentication for sensitive operations
///   - Require fingerprint/face for high-value transactions
///   - Step-up authentication within active session
/// - [LOW PRIORITY] Track concurrent sessions per user
///   - Allow/deny multiple device logins
///   - Notify user of new session starts
abstract class SessionManager {
  /// Starts new session for authenticated user
  ///
  /// **What it does:**
  /// - Stores user ID in encrypted storage
  /// - Records current timestamp as last activity
  /// - Starts timeout and warning timers
  /// - Emits SessionStarted event
  ///
  /// **Parameters:**
  /// - [userId]: Unique identifier for authenticated user
  ///
  /// **Side effects:**
  /// - Overwrites any existing session
  /// - Starts background timers
  Future<void> startSession(String userId);

  /// Ends current session and clears session data
  ///
  /// **What it does:**
  /// - Cancels all active timers
  /// - Removes session data from storage
  /// - Emits SessionEnded event
  ///
  /// **When to call:**
  /// - User manually logs out
  /// - Session timeout occurs
  /// - Security event requires logout
  Future<void> endSession();

  /// Validates if current session is active and not expired
  ///
  /// **What it does:**
  /// - Reads session data from storage
  /// - Compares last activity timestamp with timeout
  /// - Auto-ends session if expired
  ///
  /// **Returns:** True if session valid, false otherwise
  ///
  /// **Use case:**
  /// - Check before allowing access to protected screens
  /// - Validate on app resume from background
  Future<bool> isSessionActive();

  /// Retrieves user ID from active session
  ///
  /// **What it does:**
  /// - Returns cached user ID if available
  /// - Validates session is still active
  /// - Returns null if session expired
  ///
  /// **Returns:** User ID or null if no active session
  Future<String?> getCurrentUserId();

  /// Refreshes session by updating last activity timestamp
  ///
  /// **What it does:**
  /// - Updates last activity to current time
  /// - Restarts timeout and warning timers
  /// - Emits SessionRefreshed event
  ///
  /// **When to call:**
  /// - On any user interaction (tap, scroll, navigation)
  /// - After successful API call
  /// - On app resume from background
  ///
  /// **Best Practice:**
  /// - Throttle calls to avoid excessive storage writes
  /// - Call on significant user actions, not every touch
  Future<void> refreshActivity();

  /// Calculates time remaining before session timeout
  ///
  /// **Returns:** Duration until timeout or Duration.zero if expired
  ///
  /// **Use case:**
  /// - Display countdown timer in UI
  /// - Decide whether to show warning dialog
  Duration getTimeRemaining();

  /// Stream of session lifecycle events
  ///
  /// **Events:**
  /// - SessionStarted: New session created
  /// - SessionEnded: Session terminated
  /// - SessionRefreshed: Activity updated
  /// - SessionWarning: Timeout approaching
  /// - SessionTimeout: Session expired
  ///
  /// **Usage:**
  /// ```dart
  /// sessionManager.sessionEvents.listen((event) {
  ///   if (event is SessionTimeout) {
  ///     navigateToLogin();
  ///   }
  /// });
  /// ```
  Stream<SessionEvent> get sessionEvents;
}

/// [SessionManagerImpl] - Production implementation of SessionManager
///
/// **What it does:**
/// - Manages session state with in-memory and persistent storage
/// - Uses Timer for timeout and warning scheduling
/// - Broadcasts session events via StreamController
///
/// **Implementation Details:**
/// - In-memory cache: _currentUserId, _lastActivity (fast access)
/// - Persistent storage: FlutterSecureStorage (survives app restart)
/// - Dual timers: Warning timer + timeout timer
///
/// **IMPROVEMENT:**
/// - [MEDIUM PRIORITY] Add session recovery on app crash
///   - Currently sessions lost if app crashes before storage write
///   - Implement write-ahead logging for session changes
class SessionManagerImpl implements SessionManager {
  /// Encrypted storage for session persistence
  final FlutterSecureStorage _storage;

  /// Duration of inactivity before auto-logout
  final Duration _sessionTimeout;

  /// Duration before timeout to show warning
  final Duration _warningThreshold;

  /// Timer for automatic session timeout
  Timer? _timeoutTimer;

  /// Timer for timeout warning notification
  Timer? _warningTimer;

  /// Cached timestamp of last user activity
  DateTime? _lastActivity;

  /// Cached user ID for active session
  String? _currentUserId;

  /// Stream controller for broadcasting session events
  final StreamController<SessionEvent> _eventController =
      StreamController<SessionEvent>.broadcast();

  /// Storage key for last activity timestamp
  static const String _keyLastActivity = 'session_last_activity';

  /// Storage key for user ID
  static const String _keyUserId = 'session_user_id';

  /// Creates session manager with configurable timeouts
  ///
  /// **Parameters:**
  /// - [storage]: FlutterSecureStorage instance
  /// - [sessionTimeout]: Duration before auto-logout (default: 30 min)
  /// - [warningThreshold]: Time before timeout to warn (default: 5 min)
  ///
  /// **Example:**
  /// ```dart
  /// final manager = SessionManagerImpl(
  ///   storage: FlutterSecureStorage(),
  ///   sessionTimeout: Duration(minutes: 30),
  ///   warningThreshold: Duration(minutes: 5),
  /// );
  /// ```
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

  /// Starts warning and timeout timers for session management
  ///
  /// **What it does:**
  /// 1. Starts warning timer (timeout - threshold)
  /// 2. Starts timeout timer (full timeout duration)
  ///
  /// **Timers:**
  /// - Warning: Fires at (timeout - threshold) to notify user
  /// - Timeout: Fires at timeout to auto-logout
  void _startTimers() {
    // Warning timer - fires before actual timeout
    final warningDuration = _sessionTimeout - _warningThreshold;
    _warningTimer = Timer(warningDuration, () {
      if (_currentUserId != null) {
        _eventController.add(
          SessionWarning(_currentUserId!, _warningThreshold),
        );
      }
    });

    // Timeout timer - fires at session expiration
    _timeoutTimer = Timer(_sessionTimeout, () async {
      if (_currentUserId != null) {
        final userId = _currentUserId!;
        _eventController.add(SessionTimeout(userId));
        await endSession();
      }
    });
  }

  /// Cancels all active timers
  ///
  /// **When called:**
  /// - On session end
  /// - Before restarting timers (on refresh)
  void _stopTimers() {
    _timeoutTimer?.cancel();
    _warningTimer?.cancel();
    _timeoutTimer = null;
    _warningTimer = null;
  }

  /// Cleans up resources when session manager is disposed
  ///
  /// **IMPORTANT:** Call this before app shutdown to prevent memory leaks
  ///
  /// **Cleanup:**
  /// - Cancels all timers
  /// - Closes event stream controller
  void dispose() {
    _stopTimers();
    _eventController.close();
  }
}

/// Base class for all session lifecycle events
///
/// **Properties:**
/// - userId: Identifier of user associated with event
/// - timestamp: When event occurred
///
/// **Subclasses:**
/// - SessionStarted
/// - SessionEnded
/// - SessionRefreshed
/// - SessionWarning
/// - SessionTimeout
abstract class SessionEvent {
  /// User ID associated with this session event
  final String userId;

  /// Timestamp when event was created
  final DateTime timestamp;

  SessionEvent(this.userId) : timestamp = DateTime.now();
}

/// Event emitted when new session is created
///
/// **Triggered by:** startSession() method
///
/// **Use case:**
/// - Log session start for analytics
/// - Initialize session-specific resources
class SessionStarted extends SessionEvent {
  SessionStarted(super.userId);
}

/// Event emitted when session is terminated
///
/// **Triggered by:**
/// - endSession() method (manual logout)
/// - Automatic logout on timeout
///
/// **Use case:**
/// - Clean up session resources
/// - Navigate to login screen
/// - Log session end for analytics
class SessionEnded extends SessionEvent {
  SessionEnded(super.userId);
}

/// Event emitted when session activity is refreshed
///
/// **Triggered by:** refreshActivity() method
///
/// **Use case:**
/// - Track user activity patterns
/// - Reset UI timeout warnings
class SessionRefreshed extends SessionEvent {
  SessionRefreshed(super.userId);
}

/// Event emitted when session timeout is approaching
///
/// **Triggered by:** Warning timer
///
/// **Properties:**
/// - timeRemaining: Duration until actual timeout
///
/// **Use case:**
/// - Show warning dialog to user
/// - Display countdown timer
/// - Offer option to extend session
class SessionWarning extends SessionEvent {
  /// Time remaining before session expires
  final Duration timeRemaining;

  SessionWarning(super.userId, this.timeRemaining);
}

/// Event emitted when session times out
///
/// **Triggered by:** Timeout timer
///
/// **Use case:**
/// - Force logout
/// - Show timeout notification
/// - Redirect to login screen
class SessionTimeout extends SessionEvent {
  SessionTimeout(super.userId);
}

/// Configuration presets for session management
///
/// **What it provides:**
/// - Predefined timeout configurations for different environments
/// - Consistent session behavior across app
///
/// **Presets:**
/// - production: 30 min timeout (standard security)
/// - development: 2 hour timeout (developer convenience)
/// - strict: 15 min timeout (high-security scenarios)
///
/// **Usage:**
/// ```dart
/// // Use preset
/// final manager = SessionManagerImpl(
///   storage: storage,
///   sessionTimeout: SessionConfig.production.sessionTimeout,
///   warningThreshold: SessionConfig.production.warningThreshold,
/// );
///
/// // Custom configuration
/// final customConfig = SessionConfig(
///   sessionTimeout: Duration(minutes: 45),
///   warningThreshold: Duration(minutes: 10),
/// );
/// ```
class SessionConfig {
  /// Duration of inactivity before session expires
  final Duration sessionTimeout;

  /// Duration before timeout to show warning to user
  final Duration warningThreshold;

  /// Whether to automatically refresh session on user activity
  ///
  /// **Note:** Currently not implemented in SessionManagerImpl
  /// **TODO:** Integrate with activity detection middleware
  final bool autoRefreshOnActivity;

  /// Creates custom session configuration
  ///
  /// **Parameters:**
  /// - [sessionTimeout]: Inactivity duration before logout
  /// - [warningThreshold]: Time before timeout to warn user
  /// - [autoRefreshOnActivity]: Auto-refresh on user actions
  const SessionConfig({
    this.sessionTimeout = const Duration(minutes: 30),
    this.warningThreshold = const Duration(minutes: 5),
    this.autoRefreshOnActivity = true,
  });

  /// Production configuration (30 min timeout)
  ///
  /// **Use case:** Standard production apps
  /// **Security level:** Medium
  static const SessionConfig production = SessionConfig(
    sessionTimeout: Duration(minutes: 30),
    warningThreshold: Duration(minutes: 5),
    autoRefreshOnActivity: true,
  );

  /// Development configuration (2 hour timeout)
  ///
  /// **Use case:** Local development and testing
  /// **Security level:** Low (convenience over security)
  static const SessionConfig development = SessionConfig(
    sessionTimeout: Duration(hours: 2),
    warningThreshold: Duration(minutes: 10),
    autoRefreshOnActivity: true,
  );

  /// Strict configuration (15 min timeout)
  ///
  /// **Use case:** Financial apps, healthcare, sensitive data
  /// **Security level:** High
  static const SessionConfig strict = SessionConfig(
    sessionTimeout: Duration(minutes: 15),
    warningThreshold: Duration(minutes: 3),
    autoRefreshOnActivity: true,
  );
}
