import 'package:equatable/equatable.dart';
import 'package:error_handling/error_handling.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hypnosis_downloads/playlists/data/model/playlist.dart';
import 'package:hypnosis_downloads/playlists/data/playlists_repository.dart';
import 'package:hypnosis_downloads/library/data/model/product.dart';

part 'add_to_playlist_state.dart';

class AddToPlaylistCubit extends Cubit<AddToPlaylistState> {
  AddToPlaylistCubit(this._playlistsRepository) : super(AddToPlaylistInitial());

  final PlaylistsRepository _playlistsRepository;

  Future<void> addToPlaylist(Product audio, Playlist playlist) async {
    emit(AddToPlaylistInProgress(audio));
    try {
      // Use the playlist returned by the repository (not the snapshot we
      // started with) so the local Hive cache reflects the server's actual
      // state immediately — the ValueListenableBuilder in the list item
      // shows the check-mark without waiting for a full PlaylistsCubit
      // refresh round-trip.
      final updated = await _playlistsRepository.addToPlaylist(audio, playlist);
      await _playlistsRepository.writePlaylistToBox(updated);
      emit(AddToPlaylistSuccess(playlist.name));
    } catch (e) {
      emit(AddToPlaylistFailure(parseErrorMessageFrom(e)));
    }
  }
}
