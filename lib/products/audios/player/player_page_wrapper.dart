import 'package:flutter/material.dart';
import 'package:hypnosis_downloads/app/home/routes/navigation_service.dart';
import 'package:hypnosis_downloads/audio_player/audio_player_controller_widget_extension.dart';
import 'package:hypnosis_downloads/products/audios/download/data/model/downloadable.dart';
import 'package:hypnosis_downloads/products/audios/player/player_page.dart';

class PlayerPageWrapper extends StatelessWidget {
  const PlayerPageWrapper({super.key});

  static MaterialPageRoute<dynamic> get route => MaterialPageRoute(
        builder: (context) => const PlayerPageWrapper(),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: context.hypnosisAudioPlayer.currentAudioStream,
        builder: (context, snapshot) {
          final liveAudio = NavigationService
              .navigatorKey.currentContext!.hypnosisAudioPlayer.currentAudio;
          final currentPack = NavigationService.currentPack;
          final currentPlaylist = NavigationService.currentPlaylist;

          // Which products belong to what we're currently showing.
          final products = currentPack?.products ??
              currentPlaylist?.products ??
              const [];

          // Prefer the live playing audio when it actually belongs to the
          // current pack/playlist (covers auto-advance and re-entering the
          // Listen tab). Otherwise fall back to the explicitly requested
          // audio — this is the case right after a fresh tap, before the
          // player's live currentAudio has switched over. Using the requested
          // audio here stops the wrapper from loading the wrong track.
          final target = (liveAudio != null &&
                  products.any((p) => p.id == liveAudio.id))
              ? liveAudio
              : NavigationService.currentAudio;

          return PlayerPage(
            downloadable: target == null
                ? null
                : Downloadable(
                    item: target,
                    name: target.filename,
                    onlineUrl: target.link,
                  ),
            audioPack: currentPack,
            playlist: currentPlaylist,
          );
        });
  }
}
