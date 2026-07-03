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
}
