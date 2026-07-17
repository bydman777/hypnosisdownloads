import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hypnosis_downloads/app/common/filtering_mode.dart';
import 'package:hypnosis_downloads/audio_player/audio_player_controller_widget_extension.dart';
import 'package:hypnosis_downloads/app/home/routes/listen_routes.dart';
import 'package:hypnosis_downloads/app/home/routes/sessions_routes.dart';
import 'package:hypnosis_downloads/app/view/common/assets.dart';
import 'package:hypnosis_downloads/app/view/common/colors.dart';
import 'package:hypnosis_downloads/app/view/components/custom_bottom_modal_sheet.dart';
import 'package:hypnosis_downloads/app/view/components/text/headline_medium_text.dart';
import 'package:hypnosis_downloads/app/view/components/ui_views_states.dart';
import 'package:hypnosis_downloads/app/view/widgets/default_switch.dart';
import 'package:hypnosis_downloads/app/view/widgets/default_text_button_small.dart';
import 'package:hypnosis_downloads/playlists/cubit/playlists_cubit.dart';
import 'package:hypnosis_downloads/playlists/data/model/playlist.dart';
import 'package:hypnosis_downloads/playlists/playlist/common/remove_from_playlist/cubit/remove_from_playlist_cubit.dart';
import 'package:hypnosis_downloads/playlists/view/components/filter_bottom_sheet.dart';
import 'package:hypnosis_downloads/products/audios/download/data/model/downloadable.dart';
import 'package:hypnosis_downloads/products/audios/download/logic/downloadable_products_cubit.dart';
import 'package:hypnosis_downloads/products/audios/view/components/audio_list_view_item.dart';
import 'package:hypnosis_downloads/products/scripts/view/components/script_list_view_item.dart';
import 'package:hypnosis_downloads/library/data/model/product.dart';
import 'package:hypnosis_downloads/library/data/model/product_pack.dart';
import 'package:hypnosis_downloads/library/data/model/product_type.dart';
import 'package:hypnosis_downloads/library/view/components/download_bottom_sheet.dart';

class ProductsListView extends StatefulWidget {
  const ProductsListView({
    required this.pack,
    required this.playlist,
    super.key,
  });

  final ProductPack? pack;
  final Playlist? playlist;

  @override
  State<ProductsListView> createState() => _ProductsListViewState();
}

class _ProductsListViewState extends State<ProductsListView> {
  @override
  void initState() {
    if (widget.pack != null) {
      print('tagx - This pack got ${widget.pack!.products.length} products');
    } else if (widget.playlist != null) {
      print(
          'tagx - This playlist got ${widget.playlist!.products.length} products');
      // A freshly opened playlist starts in manual (drag-reorderable) order.
      // Reorder is only offered while the sort filter is "None".
      context.read<DownloadableProductsCubit>().filter = FilteringMode.none;
    }
    unawaited(context.read<DownloadableProductsCubit>().onPageOpened(
          widget.pack != null
              ? widget.pack!.products
              : widget.playlist!.products,
          // Preserve the playlist's saved order so drag-reorder persists across
          // reloads instead of being re-sorted by download time.
          preserveOrder: widget.playlist != null,
        ));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadableProductsCubit, DownloadableProductsState>(
      builder: (context, state) {
        if (state is DownloadableProductsLoadSuccess) {
          final downloadableProducts = state.downloadableProducts;
          print(
              'tagx - We have downloaded ${downloadableProducts.where((element) => element.status == DownloadTaskStatus.complete.index).length} products');
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const HeadlineMediumText.dark('Download'),
                  const Spacer(),
                  DefaultTextButtonSmall.icon(
                    'Sort by',
                    icon: SvgPicture.asset(
                      IconsOutlined.sort,
                      color: ComponentColors.defaultIconColor,
                    ),
                    onPressed: () =>
                        CustomBottomModalSheet.showBottomSheet<FilteringMode?>(
                      context: context,
                      builder: (context) => FilterBottomSheet(
                        initialFilter:
                            context.read<DownloadableProductsCubit>().filter,
                        skipFilters: const [
                          FilteringMode.date,
                          FilteringMode.dateReversed,
                        ],
                      ),
                    ).then((value) {
                      if (value != null) {
                        if (widget.playlist != null) {
                          // In a playlist the sort isn't a transient view
                          // filter: it rewrites the playlist's real order (so
                          // it plays and persists that way), and the user can
                          // still drag to fine-tune afterwards.
                          _applySortAsOrder(value, downloadableProducts);
                        } else {
                          context
                              .read<DownloadableProductsCubit>()
                              .applyFilter(value);
                        }
                      }
                    }),
                  ),
                  const SizedBox(width: 8),
                  DefaultSwitch.small(
                    value: context
                        .read<DownloadableProductsCubit>()
                        .areSomeProductsDownloaded(),
                    onToggle: (isChecked) {
                      if (isChecked) {
                        CustomBottomModalSheet.showBottomSheet.call(
                          context: context,
                          builder: (context) => DownloadBottomSheet(
                            onConfirm: () {
                              context
                                  .read<DownloadableProductsCubit>()
                                  .onBulkActionTap();
                              Navigator.of(context).pop();
                            },
                            onCancel: () => Navigator.of(context).pop(),
                          ),
                        );
                      } else {
                        context
                            .read<DownloadableProductsCubit>()
                            .onBulkActionTap();
                      }
                    },
                  ),
                ],
              ),
              _renderContent(_filterProducts(downloadableProducts)),
            ],
          );
        } else {
          return nothing;
        }
      },
    );
  }

  List<Downloadable<Product>> _filterProducts(
      List<Downloadable<Product>> downloadableProducts) {
    final filter = context.read<DownloadableProductsCubit>().filter;
    switch (filter) {
      // Sort a COPY so the cubit's stored order (the saved manual/playlist
      // order) is never mutated. This lets selecting "None" restore the manual
      // order for drag-reorder instead of leaving it alphabetically sorted.
      case FilteringMode.alphabet:
        return List<Downloadable<Product>>.from(downloadableProducts)
          ..sort((a, b) => a.item.name.compareTo(b.item.name));
      case FilteringMode.aplhabetReversed:
        return List<Downloadable<Product>>.from(downloadableProducts)
          ..sort((a, b) => b.item.name.compareTo(a.item.name));
      default:
        return downloadableProducts;
    }
  }

  Widget _renderContent(List<Downloadable<Product>> downloadableProducts) {
    final isPlaylist = widget.playlist != null;

    // Inside a playlist, drag-to-reorder is always available — even right after
    // applying a Sort-by option, the user can keep dragging to fine-tune. The
    // shown order is the order that plays and gets persisted.
    if (isPlaylist) {
      return ReorderableListView.builder(
        itemCount: downloadableProducts.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        buildDefaultDragHandles: true,
        onReorder: (oldIndex, newIndex) =>
            _onReorder(downloadableProducts, oldIndex, newIndex),
        itemBuilder: (BuildContext context, int index) {
          final downloadableProduct = downloadableProducts[index];
          return _playlistRow(
            downloadableProduct,
            key: ValueKey(downloadableProduct.item.id),
          );
        },
      );
    }

    // Packs (non-playlist) keep the plain, non-reorderable list.
    return ListView.builder(
      itemCount: downloadableProducts.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemBuilder: (BuildContext context, int index) {
        return _buildItem(downloadableProducts[index]);
      },
    );
  }

  /// A playlist row wrapped in a swipe-to-remove [Dismissible]. Swiping left
  /// asks for confirmation, then removes the item from the playlist. The row is
  /// not torn out of the tree by the Dismissible itself (confirm returns false)
  /// — the list refreshes it away once the removal round-trip completes, which
  /// avoids the "dismissed Dismissible still in the tree" assertion.
  Widget _playlistRow(
    Downloadable<Product> downloadableProduct, {
    required Key key,
  }) {
    return Dismissible(
      key: key,
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmRemoveFromPlaylist(downloadableProduct),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red,
        child: SvgPicture.asset(
          IconsOutlined.delete,
          color: Colors.white,
          width: 24,
          height: 24,
        ),
      ),
      child: _buildItem(downloadableProduct),
    );
  }

  Future<bool> _confirmRemoveFromPlaylist(
    Downloadable<Product> downloadableProduct,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from playlist'),
        content: Text(
          'Remove "${downloadableProduct.item.name}" from this playlist?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<RemoveFromPlaylistCubit>().removeFromPlaylist(
            downloadableProduct.item,
            widget.playlist!,
          );
    }
    // Always false: let the playlist refresh remove the row rather than the
    // Dismissible, so the widget tree and the data source stay in sync.
    return false;
  }

  Widget _buildItem(Downloadable<Product> downloadableProduct) {
    if (downloadableProduct.item.type == DownloadProductType.audio) {
      return AudioListViewItem(
        downloadable: downloadableProduct,
        onTap: () {
          // Inside a playlist, tapping a track plays it in place (no redirect
          // to the full player screen); packs still open the player page.
          if (widget.playlist != null) {
            unawaited(_playPlaylistFrom(downloadableProduct.item));
          } else {
            pushPlayerPage(
              context,
              DownloadProductType.audio,
              downloadableProduct,
              widget.pack,
              widget.playlist,
            );
          }
        },
        onActionTap: (downloadable) =>
            context.read<DownloadableProductsCubit>().onActionTap(downloadable),
        onCancel: (downloadable) =>
            context.read<DownloadableProductsCubit>().onCancel(downloadable),
        playlist: widget.playlist,
      );
    } else {
      return ScriptListViewItem(
        downloadable: downloadableProduct,
        onTap: () => pushProductPage(
          context,
          DownloadProductType.script,
          downloadableProduct,
          widget.pack,
          widget.playlist,
        ),
        onActionTap: (downloadable) =>
            context.read<DownloadableProductsCubit>().onActionTap(downloadable),
        onCancel: (downloadable) =>
            context.read<DownloadableProductsCubit>().onCancel(downloadable),
      );
    }
  }

  /// Plays the playlist starting at [initial] without leaving the playlist
  /// screen. Reads the freshest order from the Hive box so a just-reordered /
  /// sorted playlist plays in the new order, and reveals the mini-player.
  Future<void> _playPlaylistFrom(Product initial) async {
    final freshPlaylist =
        Hive.box<Playlist>('playlists').get(widget.playlist!.id) ??
            widget.playlist!;
    final cubit = context.read<DownloadableProductsCubit>();
    final player = context.hypnosisAudioPlayer;

    await player.setPlaylistAudioSource(
      freshPlaylist,
      initialProduct: initial,
      useOfflineLinkIfAvailable: (product) async {
        final downloadable = await cubit.getDownloadStatusForSingle(product);
        if (downloadable.status == DownloadTaskStatus.complete.index) {
          return downloadable.item.copyWith(link: downloadable.offlineUrl);
        }
        return product;
      },
    );
    player.show();
  }

  Future<void> _onReorder(
    List<Downloadable<Product>> current,
    int oldIndex,
    int newIndex,
  ) async {
    // ReorderableListView reports newIndex as the insertion slot before the
    // removal is applied; adjust when moving an item downward.
    if (newIndex > oldIndex) newIndex -= 1;

    final reordered = List<Downloadable<Product>>.from(current);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    await _persistOrder(current: current, reordered: reordered);
  }

  /// Applies a Sort-by option as a real reorder of the playlist: the sorted
  /// order becomes the playlist's stored order (so it plays and persists that
  /// way), and the user can keep dragging afterwards.
  void _applySortAsOrder(
    FilteringMode mode,
    List<Downloadable<Product>> current,
  ) {
    List<Downloadable<Product>> sorted;
    switch (mode) {
      case FilteringMode.alphabet:
        sorted = List<Downloadable<Product>>.from(current)
          ..sort((a, b) => a.item.name.compareTo(b.item.name));
        break;
      case FilteringMode.aplhabetReversed:
        sorted = List<Downloadable<Product>>.from(current)
          ..sort((a, b) => b.item.name.compareTo(a.item.name));
        break;
      default:
        // "None" and date modes have no manual baseline to restore here; keep
        // the current (possibly hand-dragged) order untouched.
        return;
    }
    unawaited(_persistOrder(current: current, reordered: sorted));
  }

  /// Reflects [reordered] immediately, then persists it to the server + Hive
  /// (via [reorderPlaylist]). Rolls back to [current] on failure. This single
  /// path backs both drag-reorder and the Sort-by sheet so the shown order,
  /// the stored order, and the play order always agree.
  Future<void> _persistOrder({
    required List<Downloadable<Product>> current,
    required List<Downloadable<Product>> reordered,
  }) async {
    final downloadablesCubit = context.read<DownloadableProductsCubit>();
    final playlistsCubit = context.read<PlaylistsCubit>();
    final messenger = ScaffoldMessenger.of(context);

    // Reflect the new order immediately.
    downloadablesCubit.setOrder(reordered);

    try {
      // reorderPlaylist writes the box optimistically before the network call,
      // so the order is saved even if the user backs out mid-request; this
      // await only completes/fails based on the server sync.
      await playlistsCubit.reorderPlaylist(
        widget.playlist!,
        reordered.map((d) => d.item).toList(),
      );
    } catch (_) {
      // The optimistic local write was already rolled back inside
      // reorderPlaylist. Only touch the UI if we're still on-screen.
      if (!mounted) return;
      downloadablesCubit.setOrder(current);
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to save new order')),
      );
    }
  }
}
