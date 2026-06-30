import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hypnosis_downloads/app/view/common/colors.dart';
import 'package:hypnosis_downloads/app/view/components/text/body_medium_text.dart';
import 'package:hypnosis_downloads/app/view/widgets/default_buttons.dart';
import 'package:hypnosis_downloads/audio_player/audio_player_controller_widget_extension.dart';
import 'package:hypnosis_downloads/audio_player/session_timings_service.dart';
import 'package:hypnosis_downloads/library/data/model/product.dart';
import 'package:hypnosis_downloads/playlists/cubit/playlists_cubit.dart';
import 'package:hypnosis_downloads/playlists/data/model/playlist.dart';
import 'package:hypnosis_downloads/products/audios/player/view/components/sleep_mode_toggle.dart';
import 'package:just_audio/just_audio.dart';

/// Description shown when the user taps the Skip intros info icon / label.
const String skipIntrosDescription =
    'Skip intros: For every track in this playlist, playback will skip '
    'straight to the hypnotic induction, missing out the introduction.';

/// Playlist-level Skip Intros and Sleep Mode toggles.
///
/// Both toggles are persisted locally (Hive) on the playlist and are never
/// synced to the server. Their behaviour only applies while this playlist is
/// the active audio source:
///
///  * **Skip intros** — when a track starts, playback automatically seeks to
///    the Hypnotic Induction (no per-track popup; the driving-safety warning is
///    shown once per session when playback starts). Tracks without timings are
///    skipped silently.
///  * **Sleep mode** — when playback reaches the Reorientation segment the
///    audio fades out and pauses, so the user is not woken by the wake-up
///    section. The playlist does not advance.
class PlaylistToggles extends StatefulWidget {
  const PlaylistToggles({
    super.key,
    required this.playlist,
    this.timingsService,
  });

  final Playlist playlist;

  /// Injectable for testing; defaults to the shared instance.
  final SessionTimingsService? timingsService;

  @override
  State<PlaylistToggles> createState() => _PlaylistTogglesState();
}

class _PlaylistTogglesState extends State<PlaylistToggles> {
  late final SessionTimingsService _timings =
      widget.timingsService ?? SessionTimingsService.instance;

  late Playlist _playlist = widget.playlist;
  late bool _skipIntros = widget.playlist.skipIntros;
  late bool _sleepMode = widget.playlist.sleepMode;

  HypnosisAudioPlayerExtensionHelper? _player;

  StreamSubscription<Product?>? _audioSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  /// Filename of the track we have already auto-skipped, to avoid re-seeking
  /// repeatedly within the same track.
  String? _skippedFilename;

  /// Reorientation start for the current track, looked up when it changes.
  Duration? _reorientationStart;

  bool _fading = false;

  @override
  void initState() {
    super.initState();
    // Inherited-widget lookups aren't allowed in initState, so defer until the
    // first frame to capture the player and start any persisted toggles.
    debugPrint('[toggles] init playlist=${widget.playlist.id} '
        'skipIntros=${widget.playlist.skipIntros} '
        'sleepMode=${widget.playlist.sleepMode}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _player = context.hypnosisAudioPlayer;
      _ensureSubscriptions();
    });
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  bool get _isCurrentPlaylist =>
      _player?.audioSource?.id == widget.playlist.id;

  void _ensureSubscriptions() {
    final player = _player;
    if (player == null) return;

    // The current-audio stream drives both skip-intro seeking and reorientation
    // lookups, so subscribe while either toggle is on.
    if (_skipIntros || _sleepMode) {
      _audioSubscription ??= player.currentAudioStream.listen(_onAudioChanged);
    } else {
      _audioSubscription?.cancel();
      _audioSubscription = null;
    }

    if (_sleepMode) {
      _positionSubscription ??= player.positionStream.listen(_onPosition);
    } else {
      _positionSubscription?.cancel();
      _positionSubscription = null;
    }
  }

  Future<void> _onAudioChanged(Product? audio) async {
    _fading = false;
    _reorientationStart = null;
    debugPrint('[toggles] onAudioChanged: filename="${audio?.filename}" '
        'isCurrentPlaylist=$_isCurrentPlaylist '
        'audioSourceId=${_player?.audioSource?.id} '
        'playlistId=${widget.playlist.id} '
        'skipIntros=$_skipIntros sleepMode=$_sleepMode');
    if (audio == null || !_isCurrentPlaylist) return;

    if (_sleepMode) {
      _reorientationStart =
          await _timings.getReorientationStart(audio.filename);
      debugPrint('[toggles] reorientationStart for "${audio.filename}" = '
          '$_reorientationStart');
    }

    if (_skipIntros && _skippedFilename != audio.filename) {
      final inductionStart =
          await _timings.getHypnoticInductionStart(audio.filename);
      debugPrint('[toggles] inductionStart for "${audio.filename}" = '
          '$inductionStart');
      // No timings → leave playback at the start (silent no-op).
      if (inductionStart == null || !mounted || !_isCurrentPlaylist) return;
      // Mark as handled up front so re-emits of the same audio don't re-queue.
      _skippedFilename = audio.filename;
      // The new track's duration is not available the instant currentAudio
      // changes; seeking before that throws "Can`t forward 30 seconds" and the
      // skip is silently lost. Wait until just_audio reports the new source
      // is ready (which means duration is populated).
      await _waitForReady(audio.filename);
      // Re-validate — the user may have switched tracks/playlists meanwhile.
      if (!mounted ||
          !_isCurrentPlaylist ||
          _player?.currentAudio?.filename != audio.filename) {
        return;
      }
      debugPrint(
          '[toggles] seeking to inductionStart=$inductionStart for "${audio.filename}"');
      await _player?.seek(inductionStart);
    }
  }

  /// Waits until the player's processing state is [ProcessingState.ready] for
  /// the track identified by [filename]. Times out silently to avoid hanging
  /// the listener if the track never loads.
  ///
  /// We also have to filter on filename because the stream initially replays
  /// the previous track's state (which may already be `ready`) before the new
  /// source has actually loaded.
  Future<void> _waitForReady(
    String filename, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final player = _player;
    if (player == null) return;
    try {
      await player.playerStateStream
          .firstWhere((s) =>
              s.processingState == ProcessingState.ready &&
              player.currentAudio?.filename == filename)
          .timeout(timeout);
    } catch (_) {
      // Stream closed or timed out — caller handles the no-op.
    }
  }

  Future<void> _onPosition(Duration position) async {
    final reorientation = _reorientationStart;
    if (!_sleepMode ||
        _fading ||
        reorientation == null ||
        !_isCurrentPlaylist ||
        position < reorientation) {
      return;
    }
    debugPrint('[toggles] sleep-mode trigger: position=$position '
        'reorientation=$reorientation -> fadeOutAndPause');
    _fading = true;
    // Sleep mode: fade out and stop. Do NOT advance to the next track — the
    // whole point is the user is asleep and shouldn't be woken by the next
    // track resuming at full volume.
    await _player?.fadeOutAndPause();
  }

  Future<void> _onSkipIntrosChanged(bool value) async {
    _player = context.hypnosisAudioPlayer;
    // Re-arm so the current track is skipped immediately if applicable.
    _skippedFilename = null;
    setState(() => _skipIntros = value);
    await _persist(skipIntros: value);
    _ensureSubscriptions();
    if (value) {
      await _onAudioChanged(_player?.currentAudio);
    }
  }

  Future<void> _onSleepModeChanged(bool value) async {
    _player = context.hypnosisAudioPlayer;
    setState(() => _sleepMode = value);
    await _persist(sleepMode: value);
    _ensureSubscriptions();
    if (value) {
      // Prime reorientation lookup for the track already playing.
      await _onAudioChanged(_player?.currentAudio);
    }
  }

  Future<void> _persist({bool? skipIntros, bool? sleepMode}) async {
    _playlist = await context
        .read<PlaylistsCubit>()
        .updateToggles(_playlist, skipIntros: skipIntros, sleepMode: sleepMode);
    debugPrint('[toggles] persisted playlist=${_playlist.id} '
        'skipIntros=${_playlist.skipIntros} sleepMode=${_playlist.sleepMode}');
  }

  void _showDescription(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ComponentColors.primaryCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: BodyMediumText(message),
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
    return Column(
      children: [
        _ToggleRow(
          icon: Icons.fast_forward,
          label: 'Skip intros',
          value: _skipIntros,
          onChanged: _onSkipIntrosChanged,
          onInfo: () => _showDescription(skipIntrosDescription),
        ),
        _ToggleRow(
          icon: Icons.bedtime,
          label: 'Sleep mode',
          value: _sleepMode,
          onChanged: _onSleepModeChanged,
          onInfo: () => _showDescription(sleepModeDescription),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onInfo,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: ComponentColors.secondaryIconColor,
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onInfo,
          child: BodyMediumText(label),
        ),
        IconButton(
          icon: const Icon(
            Icons.info_outline,
            size: 20,
            color: ComponentColors.secondaryIconColor,
          ),
          onPressed: onInfo,
        ),
        const Spacer(),
        Switch(
          value: value,
          activeThumbColor: ComponentColors.primaryColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
