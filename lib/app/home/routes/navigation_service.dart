import 'package:flutter/material.dart';
import 'package:hypnosis_downloads/playlists/data/model/playlist.dart';
import 'package:hypnosis_downloads/library/data/model/product.dart';
import 'package:hypnosis_downloads/library/data/model/product_pack.dart';

class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static ProductPack? currentPack;
  static Playlist? currentPlaylist;

  /// The audio the user last explicitly requested to play (the item they
  /// tapped). Used by [PlayerPageWrapper] to target the correct track on the
  /// first build, before the audio player's live `currentAudio` has caught up.
  static Product? currentAudio;

  /// Bumped every time the user explicitly requests a new play selection, so
  /// the kept-alive [PlayerPageWrapper] (which lives offstage in an
  /// IndexedStack tab and therefore isn't rebuilt by a mere tab switch) can
  /// rebuild to reflect the freshly selected pack/playlist/audio.
  static final ValueNotifier<int> selectionRevision = ValueNotifier<int>(0);
}
