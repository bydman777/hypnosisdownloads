import 'package:flutter/foundation.dart';

/// Tracks whether the driving-safety warning has already been acknowledged
/// during the current app session.
///
/// The warning is shown the first time audio starts playing in a session and
/// is then suppressed until the app is restarted (session-scoped memory only —
/// it is intentionally never persisted to disk).
class DrivingSafetyWarningService {
  DrivingSafetyWarningService._();

  static final DrivingSafetyWarningService instance =
      DrivingSafetyWarningService._();

  bool _acknowledgedThisSession = false;

  /// Whether the user has already seen/acknowledged the warning this session.
  bool get acknowledgedThisSession => _acknowledgedThisSession;

  /// Marks the warning as acknowledged for the remainder of the session.
  void markAcknowledged() => _acknowledgedThisSession = true;

  /// Resets the session flag. Exposed for tests.
  @visibleForTesting
  void reset() => _acknowledgedThisSession = false;
}
