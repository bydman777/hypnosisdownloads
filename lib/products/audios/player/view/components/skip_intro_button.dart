import 'package:flutter/material.dart';
import 'package:hypnosis_downloads/app/view/common/colors.dart';
import 'package:hypnosis_downloads/audio_player/audio_player_controller_widget_extension.dart';
import 'package:hypnosis_downloads/audio_player/driving_safety_warning_service.dart';
import 'package:hypnosis_downloads/audio_player/session_timings_service.dart';
import 'package:hypnosis_downloads/library/data/model/product.dart';
import 'package:hypnosis_downloads/products/audios/player/view/components/skip_intro_warning_dialog.dart';

/// A small text button that jumps playback to the start of the Hypnotic
/// Induction segment, skipping the Welcome and Introduction sections.
///
/// Only shown when timings exist for the **currently playing** session and
/// playback has not yet reached the induction. Tapping shows the mandatory
/// driving-safety warning and, on acknowledgement, seeks to the induction.
///
/// [audio] is used as the initial value while the player's current-audio
/// stream emits its first event; after that the button follows the actually
/// playing track, so it stays correct if the playlist auto-advances.
class SkipIntroButton extends StatefulWidget {
  const SkipIntroButton({
    super.key,
    required this.audio,
    this.timingsService,
  });

  final Product audio;

  /// Injectable for testing; defaults to the shared instance.
  final SessionTimingsService? timingsService;

  @override
  State<SkipIntroButton> createState() => _SkipIntroButtonState();
}

class _SkipIntroButtonState extends State<SkipIntroButton> {
  late final SessionTimingsService _timings =
      widget.timingsService ?? SessionTimingsService.instance;

  /// Memoised lookup so we don't re-hit the asset cache on every rebuild —
  /// only when the current track's filename changes.
  String? _cachedFilename;
  Future<Duration?>? _cachedInduction;

  Future<Duration?> _inductionFor(String filename) {
    if (_cachedFilename != filename) {
      _cachedFilename = filename;
      _cachedInduction = _timings.getHypnoticInductionStart(filename);
    }
    return _cachedInduction!;
  }

  @override
  Widget build(BuildContext context) {
    final player = context.hypnosisAudioPlayer;
    return StreamBuilder<Product?>(
      stream: player.currentAudioStream,
      initialData: player.currentAudio ?? widget.audio,
      builder: (context, audioSnapshot) {
        final audio = audioSnapshot.data;
        if (audio == null) return const SizedBox.shrink();
        return FutureBuilder<Duration?>(
          future: _inductionFor(audio.filename),
          builder: (context, futureSnapshot) {
            final inductionStart = futureSnapshot.data;
            if (inductionStart == null) return const SizedBox.shrink();
            return StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, positionSnapshot) {
                final position = positionSnapshot.data ?? Duration.zero;
                // Hide once playback has already reached the induction.
                if (position >= inductionStart) return const SizedBox.shrink();
                return Center(
                  child: TextButton(
                    onPressed: () async {
                      // Per QA: the driving-safety warning must appear when
                      // the user taps Skip intro on the player screen. Only
                      // perform the seek if the user acknowledges the warning.
                      final acknowledged =
                          await showDrivingSafetyWarning(context);
                      if (!acknowledged) return;
                      DrivingSafetyWarningService.instance.markAcknowledged();
                      await player.seek(inductionStart);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: ComponentColors.primaryColor,
                    ),
                    child: const Text('Skip intro →'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
