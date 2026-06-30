import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hypnosis_downloads/app/view/common/colors.dart';
import 'package:hypnosis_downloads/app/view/components/text/body_medium_text.dart';
import 'package:hypnosis_downloads/app/view/widgets/default_buttons.dart';
import 'package:hypnosis_downloads/audio_player/audio_player_controller_widget_extension.dart';
import 'package:hypnosis_downloads/audio_player/session_timings_service.dart';
import 'package:hypnosis_downloads/library/data/model/product.dart';

/// Description shown when the user taps the info icon / label.
const String sleepModeDescription =
    'Sleep mode: Playback will stop before the wake-up section so you can '
    'drift off to sleep.';

/// A toggle that, when on, fades out and stops playback when the Reorientation
/// segment is reached, so the user is not woken at the end of the session.
///
/// Defaults to off every time a session is opened and is intentionally never
/// persisted. The toggle follows whatever track the player is currently
/// playing — if the playlist auto-advances to the next track, the
/// reorientation lookup is re-run for that new track. Tracks without a
/// Reorientation timing are silently no-op.
class SleepModeToggle extends StatefulWidget {
  const SleepModeToggle({
    super.key,
    required this.audio,
    this.timingsService,
  });

  final Product audio;

  /// Injectable for testing; defaults to the shared instance.
  final SessionTimingsService? timingsService;

  @override
  State<SleepModeToggle> createState() => _SleepModeToggleState();
}

class _SleepModeToggleState extends State<SleepModeToggle> {
  late final SessionTimingsService _timings =
      widget.timingsService ?? SessionTimingsService.instance;

  bool _sleepMode = false;
  bool _fading = false;

  /// Reorientation start for the track the player is currently on, or `null`
  /// if the track has no Reorientation segment (or hasn't been looked up yet).
  Duration? _reorientationStart;

  /// Filename of the track we last looked up — used to guard against an
  /// out-of-order lookup completing after the user has already switched away.
  String? _currentFilename;

  HypnosisAudioPlayerExtensionHelper? _player;
  StreamSubscription<Product?>? _audioSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _onChanged(bool value) async {
    _player = context.hypnosisAudioPlayer;
    setState(() => _sleepMode = value);
    if (value) {
      // Subscribe to track changes so reorientation lookups stay in sync with
      // whatever the player is actually playing.
      _audioSubscription ??=
          _player!.currentAudioStream.listen(_onAudioChanged);
      _positionSubscription ??= _player!.positionStream.listen(_onPosition);
      // Prime for the track that's already playing (the stream won't replay
      // its last value to a fresh listener).
      await _onAudioChanged(_player!.currentAudio ?? widget.audio);
    } else {
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      _reorientationStart = null;
      _currentFilename = null;
      _fading = false;
    }
  }

  Future<void> _onAudioChanged(Product? audio) async {
    _fading = false;
    _reorientationStart = null;
    _currentFilename = audio?.filename;
    if (audio == null) return;
    final filename = audio.filename;
    final reorientation = await _timings.getReorientationStart(filename);
    if (!mounted || !_sleepMode) return;
    // If the user has switched tracks while we awaited, drop this result.
    if (_currentFilename != filename) return;
    _reorientationStart = reorientation;
  }

  Future<void> _onPosition(Duration position) async {
    final reorientation = _reorientationStart;
    if (!_sleepMode ||
        _fading ||
        reorientation == null ||
        position < reorientation) {
      return;
    }
    _fading = true;
    // Sleep mode: fade out and stop. The whole point is that the user is
    // asleep — do not auto-advance to the next track.
    await _player?.fadeOutAndPause();
    if (mounted) setState(() => _sleepMode = false);
    // Tear down subscriptions; user has to re-enable for the next session.
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _reorientationStart = null;
    _currentFilename = null;
    _fading = false;
  }

  void _showDescription() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ComponentColors.primaryCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: const BodyMediumText(sleepModeDescription),
        actions: [
          PrimaryButton(
            'OK',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.bedtime,
          size: 20,
          color: ComponentColors.secondaryIconColor,
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _showDescription,
          child: const BodyMediumText('Sleep mode'),
        ),
        IconButton(
          icon: const Icon(
            Icons.info_outline,
            size: 20,
            color: ComponentColors.secondaryIconColor,
          ),
          onPressed: _showDescription,
        ),
        Switch(
          value: _sleepMode,
          activeThumbColor: ComponentColors.primaryColor,
          onChanged: _onChanged,
        ),
      ],
    );
  }
}
