import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:hypnosis_downloads/app/connectivity_status/logic/connectivity_status_cubit.dart';
import 'package:hypnosis_downloads/app/home/page_index_provider.dart';
import 'package:hypnosis_downloads/app/home/routes/navigation_service.dart';
import 'package:hypnosis_downloads/playlists/data/model/playlist.dart';
import 'package:hypnosis_downloads/products/audios/download/data/model/downloadable.dart';
import 'package:hypnosis_downloads/products/audios/download/logic/downloadable_products_cubit.dart';
import 'package:hypnosis_downloads/products/audios/player/player_page.dart';
import 'package:hypnosis_downloads/products/audios/player/player_page_wrapper.dart';
import 'package:hypnosis_downloads/products/scripts/document_viewer/document_viewer_page.dart';
import 'package:hypnosis_downloads/library/data/model/product.dart';
import 'package:hypnosis_downloads/library/data/model/product_pack.dart';
import 'package:hypnosis_downloads/library/data/model/product_type.dart';
import 'package:provider/provider.dart';

class PackDetailPageArguments {
  PackDetailPageArguments(this.type, this.pack);

  final DownloadProductType type;
  final ProductPack pack;
}

class ProductPageArgumnets {
  ProductPageArgumnets({
    required this.type,
    required this.downloadable,
    required this.productPack,
    required this.playlist,
  });

  final DownloadProductType type;
  final Downloadable<Product> downloadable;
  final ProductPack? productPack;
  final Playlist? playlist;
}

const String productPageRouteName = '_product_page_route_name';

Route<dynamic>? onGenerateListenRoute(RouteSettings settings) {
  return PlayerPageWrapper.route;
}

Future<void> pushPlayerPage(
  BuildContext context,
  DownloadProductType type,
  Downloadable<Product> downloadable,
  ProductPack? productPack,
  Playlist? playlist, {
  bool navigatedByMiniPlayer = false,
}) async {
  if (type == DownloadProductType.audio && !navigatedByMiniPlayer) {
    final isOnline = context.read<ConnectivityStatusCubit>().state
        is ConnectivityStatusOnline;
    if (!isOnline) {
      var isDownloaded =
          downloadable.status == DownloadTaskStatus.complete.index ||
              downloadable.downloadedPercent == 100;
      if (!isDownloaded) {
        // Re-check with authoritative source in case the passed-in
        // downloadable's status is stale.
        try {
          final fresh = await context
              .read<DownloadableProductsCubit>()
              .getDownloadStatusForSingle(downloadable.item);
          isDownloaded =
              fresh.status == DownloadTaskStatus.complete.index ||
                  fresh.downloadedPercent == 100;
        } catch (_) {
          // If lookup fails while offline, treat as not downloaded.
        }
      }
      if (!isDownloaded) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Only downloaded titles can be played while offline.'),
          ),
        );
        return;
      }
    }
  }
  if (productPack != null) {
    NavigationService.currentPack = productPack;
    NavigationService.currentPlaylist = null;
  }
  if (playlist != null) {
    NavigationService.currentPlaylist = playlist;
    NavigationService.currentPack = null;
  }
  // Record the explicitly requested audio so PlayerPageWrapper targets the
  // tapped item on its first build (the audio player's live currentAudio is
  // still stale at this point). This prevents the wrapper from racing the
  // pushed PlayerPage and loading the wrong track.
  if (type == DownloadProductType.audio) {
    NavigationService.currentAudio = downloadable.item;
  }
  if (!context.mounted) return;
  if (type == DownloadProductType.audio) {
    Navigator.push(context, MaterialPageRoute(builder: (_) {
      return PlayerPage(
        downloadable: downloadable,
        audioPack: productPack,
        playlist: playlist,
        navigatedByMiniPlayer: navigatedByMiniPlayer,
      );
    }));
    if (!navigatedByMiniPlayer) {
      Provider.of<PageIndexProvider>(context, listen: false)
          .navigateToListenTab();
    }
  } else {
    Navigator.push(context, MaterialPageRoute(builder: (_) {
      return DocumentViewerPage(
        script: downloadable.item,
      );
    }));
  }
}
