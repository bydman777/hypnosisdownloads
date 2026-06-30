import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A single named segment of a hypnosis session, e.g. "Hypnotic Induction".
@immutable
class SessionSegment {
  const SessionSegment({required this.name, required this.startInSec});

  factory SessionSegment.fromJson(Map<String, dynamic> json) => SessionSegment(
        name: json['name'] as String,
        startInSec: (json['startInSec'] as num).toInt(),
      );

  final String name;
  final int startInSec;

  Duration get start => Duration(seconds: startInSec);
}

/// Loads and queries the bundled session timings (`assets/hd_sessions.json`).
///
/// The JSON maps an MP3 [filename] to the list of its segments. Only the
/// segment start times are used by the Skip Intro and Sleep Mode features.
///
/// Lookups are resilient: an exact match is tried first, then a
/// trimmed + case-insensitive fallback. No fuzzy/separator matching is done,
/// to avoid false matches. Unknown filenames or missing segments return null
/// (never throw) so callers can simply hide the feature.
class SessionTimingsService {
  SessionTimingsService({
    AssetBundle? bundle,
    this.assetPath = 'assets/hd_sessions.json',
  }) : _bundle = bundle ?? rootBundle;

  /// Shared instance used throughout the app.
  static final SessionTimingsService instance = SessionTimingsService();

  static const String hypnoticInductionSegment = 'Hypnotic Induction';
  static const String reorientationSegment = 'Reorientation';

  final AssetBundle _bundle;
  final String assetPath;

  /// Exact (trimmed) filename -> segments.
  final Map<String, List<SessionSegment>> _byFilename = {};

  /// Lowercased (trimmed) filename -> segments, for the case-insensitive fallback.
  final Map<String, List<SessionSegment>> _byLowerFilename = {};

  Future<void>? _loading;

  Future<void> _ensureLoaded() {
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _bundle.loadString(assetPath);
      _parse(raw);
    } catch (e, s) {
      // Don't crash playback if the asset is missing/corrupt — features just
      // won't show. Reset so a later call can retry.
      debugPrint('SessionTimingsService: failed to load $assetPath: $e\n$s');
      _loading = null;
    }
  }

  /// Parses raw JSON into the lookup maps. Exposed for testing.
  @visibleForTesting
  void loadFromString(String raw) {
    _parse(raw);
    _loading = Future<void>.value();
  }

  void _parse(String raw) {
    _byFilename.clear();
    _byLowerFilename.clear();
    final data = json.decode(raw) as Map<String, dynamic>;
    final sessions = (data['sessions'] as List<dynamic>? ?? const []);
    for (final entry in sessions) {
      final session = entry as Map<String, dynamic>;
      final filename = (session['filename'] as String?)?.trim();
      if (filename == null || filename.isEmpty) continue;
      final segments = (session['segments'] as List<dynamic>? ?? const [])
          .map((s) => SessionSegment.fromJson(s as Map<String, dynamic>))
          .toList(growable: false);
      _byFilename[filename] = segments;
      _byLowerFilename[filename.toLowerCase()] = segments;
    }
  }

  /// Returns the segments for [filename], or null if the session is unknown.
  Future<List<SessionSegment>?> getSegments(String filename) async {
    await _ensureLoaded();
    final key = filename.trim();
    return _byFilename[key] ?? _byLowerFilename[key.toLowerCase()];
  }

  /// Start of the Hypnotic Induction segment, or null if absent.
  Future<Duration?> getHypnoticInductionStart(String filename) =>
      _startOf(filename, hypnoticInductionSegment);

  /// Start of the Reorientation segment, or null if absent.
  Future<Duration?> getReorientationStart(String filename) =>
      _startOf(filename, reorientationSegment);

  Future<Duration?> _startOf(String filename, String segmentName) async {
    final segments = await getSegments(filename);
    if (segments == null) return null;
    for (final segment in segments) {
      if (segment.name == segmentName) return segment.start;
    }
    return null;
  }
}
