import 'package:flutter/material.dart';
import 'package:hypnosis_downloads/app/home/routes/navigation_service.dart';
import 'package:hypnosis_downloads/audio_player/audio_player_controller_widget_extension.dart';
import 'package:hypnosis_downloads/library/data/model/product.dart';
import 'package:hypnosis_downloads/products/audios/download/data/model/downloadable.dart';
import 'package:hypnosis_downloads/products/audios/player/player_page.dart';

class PlayerPageWrapper extends StatefulWidget {
  const PlayerPageWrapper({super.key});

  static MaterialPageRoute<dynamic> get route => MaterialPageRoute(
        builder: (context) => const PlayerPageWrapper(),
      );

  @override
  State<PlayerPageWrapper> createState() => _PlayerPageWrapperState();
}

class _PlayerPageWrapperState extends State<PlayerPageWrapper> {
  /// The last selection revision this wrapper has already applied. Used to tell
  /// a fresh explicit tap (revision just bumped) apart from a stream-driven
  /// rebuild such as auto-advance or re-entering the Listen tab.
  int _handledRevision = NavigationService.selectionRevision.value;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NavigationService.selectionRevision,
      builder: (context, revision, __) {
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

            final Product? target;
            if (revision != _handledRevision) {
              // Fresh explicit tap: honour exactly what the user just picked,
              // even if a different track from the same pack is still playing.
              _handledRevision = revision;
              target = NavigationService.currentAudio;
            } else {
              // Stream-driven rebuild (auto-advance / re-entering the tab):
              // prefer the live playing audio when it belongs to the current
              // pack/playlist so we track what is actually playing.
              target = (liveAudio != null &&
                      products.any((p) => p.id == liveAudio.id))
                  ? liveAudio
                  : NavigationService.currentAudio;
            }

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
          },
        );
      },
    );
  }
}
