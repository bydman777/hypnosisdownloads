import 'dart:async';

import 'package:authentication_logic/authentication_logic.dart';
import 'package:equatable/equatable.dart';
import 'package:error_handling/error_handling.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hypnosis_downloads/library/data/model/product.dart';
import 'package:hypnosis_downloads/playlists/data/model/playlist.dart';
import 'package:hypnosis_downloads/playlists/data/playlists_repository.dart';

part 'playlists_state.dart';

class PlaylistsCubit extends Cubit<PlaylistsState> {
  PlaylistsCubit(this.playlistsRepository, this.currentUserRepository)
      : super(PlaylistsInitial());

  final PlaylistsRepository playlistsRepository;
  final CurrentUserRepository currentUserRepository;

  Future<void> onPageOpened() async {
    await _showPlaylists();
  }

  Future<void> _showPlaylists() async {
    try {
      emit(PlaylistsLoadInProgress());
      final playlists = await playlistsRepository.getPlaylists();
      emit(PlaylistsLoadSuccess(playlists));
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'Playlists load failure',
        fatal: false,
      );
      emit(PlaylistsLoadFailure(parseErrorMessageFrom(error)));
    }
  }

  /// Persists the playlist-level [skipIntros] / [sleepMode] toggles locally
  /// (Hive only — these are never synced to the server) and returns the
  /// updated playlist. Does not emit a new state: the toggles are owned by the
  /// playlist view's local state.
  Future<Playlist> updateToggles(
    Playlist playlist, {
    bool? skipIntros,
    bool? sleepMode,
  }) async {
    final updated = playlist.copyWith(
      skipIntros: skipIntros,
      sleepMode: sleepMode,
    );
    await playlistsRepository.writePlaylistToBox(updated);
    return updated;
  }

  /// Persists a new ordering of [reorderedProducts] for [playlist] to the
  /// server (via the playlist "entries" list) and updates the local Hive
  /// cache. Returns the server-parsed playlist. Does not emit — the playlist
  /// view drives the visible order through DownloadableProductsCubit.
  Future<Playlist> reorderPlaylist(
    Playlist playlist,
    List<Product> reorderedProducts,
  ) async {
    // Persist the exact order the user dragged rather than the server-parsed
    // order: the parse round-trip can re-order entries, which would leave the
    // cached (and therefore the played) order out of sync with what was shown.
    final reordered = playlist.copyWith(products: reorderedProducts);

    // Write locally FIRST (optimistic). Hive is a fast local write, so the new
    // order is saved effectively synchronously — even if the user backs out of
    // the playlist before the network round-trip finishes, the order survives.
    // The server sync then runs independently (this cubit is app-scoped, so it
    // isn't cancelled when the page is disposed).
    await playlistsRepository.writePlaylistToBox(reordered);

    final user = currentUserRepository.currentUser;
    try {
      await playlistsRepository.updatePlaylistEntry(
        username: user.email,
        password: user.accessToken,
        playlist: playlist,
        products: reorderedProducts,
      );
    } catch (e) {
      // Server rejected the new order — undo the optimistic local write so the
      // cache doesn't drift from the server (which would otherwise revert on
      // the next getPlaylists anyway, but silently).
      await playlistsRepository.writePlaylistToBox(playlist);
      rethrow;
    }
    return reordered;
  }

  Future<void> delete(Playlist playlist) async {
    emit(const PlaylistDeleteInProgress());
    try {
      final user = currentUserRepository.currentUser;
      await playlistsRepository.deletePlaylist(
        name: user.email,
        password: user.accessToken,
        id: playlist.id,
      );
      emit(const PlaylistDeleteSuccess());
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'Playlist delete failure',
        fatal: false,
      );
      emit(PlaylistDeleteFailure(parseErrorMessageFrom(error)));
    }
    unawaited(_showPlaylists());
  }
}
