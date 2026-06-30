import 'dart:convert';

import 'package:authentication_logic/authentication_logic.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hypnosis_downloads/app/config.dart';
import 'package:hypnosis_downloads/playlists/data/model/playlist.dart';
import 'package:hypnosis_downloads/library/data/model/product.dart';

class PlaylistsRepository {
  const PlaylistsRepository(
    this.httpClient,
    this.playlistsBox,
    this.currentUserRepository,
  );

  final Dio httpClient;
  final Box<Playlist> playlistsBox;
  final CurrentUserRepository currentUserRepository;

  Future<List<Playlist>> getPlaylists() async {
    try {
      final user = currentUserRepository.currentUser;
      final retrivePlaylistFormData = FormData.fromMap(
        {
          "action": Config.userRetrievePlaylistsAction,
          "rev": 1,
          "name": user.email,
          "pass": user.accessToken,
        },
      );

      final response = await httpClient.post(
        "/${Config.userPlaylistsPath}",
        data: retrivePlaylistFormData,
      );

      final responseErrorCode = jsonDecode(response.data)['error'];
      if (responseErrorCode > 0) {
        throw Exception(jsonDecode(response.data)['errorstr']);
      } else if (responseErrorCode < 0) {
        throw Exception(responseErrorCode);
      }

      List<Playlist> playlists = [];

      // Preserve locally-stored, server-less toggles (skipIntros / sleepMode)
      // across a server refresh, keyed by playlist id. The server never returns
      // these, so without this merge the returned list (and therefore the UI)
      // would always reset them to false.
      final existingToggles = {
        for (final playlist in playlistsBox.values)
          playlist.id: (
            skipIntros: playlist.skipIntros,
            sleepMode: playlist.sleepMode,
          ),
      };

      final playlistsResponse =
          jsonDecode(response.data)['lists'] as List<dynamic>;

      if (Hive.box<Product>('audios').isNotEmpty) {
        for (final playlistJson in playlistsResponse) {
          final entries = playlistJson['entries'] as List<dynamic>;
          final productFutures = <Future<Product?>>[];
          for (final entry in entries) {
            productFutures.add(getProductById(entry.toString()));
          }
          final products =
              (await Future.wait(productFutures)).whereType<Product>().toList();
          products.sort((a, b) => b.orderTime.compareTo(a.orderTime));
          playlistJson['products'] =
              products.map((product) => product.toJson()).toList();

          final playlist = Playlist.fromJson(playlistJson);
          final toggles = existingToggles[playlist.id];
          playlists.add(
            toggles == null
                ? playlist
                : playlist.copyWith(
                    skipIntros: toggles.skipIntros,
                    sleepMode: toggles.sleepMode,
                  ),
          );
        }
      }

      await writePlaylistsToBox(playlists);

      return playlists;
    } catch (e) {
      return Future.error(e.toString());
    }
  }

  Future<void> saveNewPlaylist({
    required String name,
    required String password,
    required String playlistName,
    int listNumber = 0,
  }) async {
    try {
      final playlistNameToSave = playlistName.isNotEmpty
          ? playlistName
          : 'My new playlist №$listNumber';

      debugPrint(playlistNameToSave);
      final savePlaylistFormData = FormData.fromMap(
        {
          "action": Config.userSavePlaylistAction,
          "rev": 1,
          "name": name,
          "pass": password,
          "list": playlistNameToSave,
          "entries": [],
        },
      );

      final response = await httpClient.post(
        "/${Config.userPlaylistsPath}",
        data: savePlaylistFormData,
      );

      final responseErrorCode = jsonDecode(response.data)['error'];
      if (responseErrorCode > 0 && responseErrorCode != 6) {
        throw Exception(jsonDecode(response.data)['errorstr']);
      } else if (responseErrorCode < 0) {
        throw Exception(responseErrorCode);
      }
    } catch (e) {
      return Future.error(e);
    }
  }

  Future<void> deletePlaylist({
    required String name,
    required String password,
    required String id,
  }) async {
    try {
      final deletePlaylistFormData = FormData.fromMap(
        {
          "action": Config.userDeletePlaylistAction,
          "rev": 1,
          "name": name,
          "pass": password,
          "id": id,
        },
      );

      final response = await httpClient.post(
        "/${Config.userPlaylistsPath}",
        data: deletePlaylistFormData,
      );

      final responseErrorCode = jsonDecode(response.data)['error'];
      if (responseErrorCode > 0 && responseErrorCode != 6) {
        throw Exception(jsonDecode(response.data)['errorstr']);
      } else if (responseErrorCode < 0) {
        throw Exception(responseErrorCode);
      }
    } catch (e) {
      return Future.error(e);
    }
  }

  Future<void> savePlaylistName({
    required String username,
    required String password,
    required String playlistName,
    required Playlist playlist,
  }) async {
    try {
      final savePlaylistFormData = FormData.fromMap(
        {
          "action": Config.userSavePlaylistAction,
          "rev": 1,
          "name": username,
          "pass": password,
          "list": playlistName,
          "id": playlist.id,
          "entries": playlist.products.map((e) => e.id).toList(),
        },
      );

      final response = await httpClient.post(
        "/${Config.userPlaylistsPath}",
        data: savePlaylistFormData,
      );

      final responseErrorCode = jsonDecode(response.data)['error'];
      if (responseErrorCode > 0 &&
          responseErrorCode != 6 &&
          responseErrorCode !=
              7 /* Backend returns "cannot decode entries" error message in successful responses*/) {
        throw Exception(jsonDecode(response.data)['errorstr']);
      } else if (responseErrorCode < 0) {
        throw Exception(responseErrorCode);
      }
    } catch (e) {
      return Future.error(e);
    }
  }

  /// Returns a [Product] from the [Box] with the given playlist [id] id.
  Future<Product?> getProductById(String playlist) async {
    final cachedProduct = Hive.box<Product>('audios')
        .values
        .firstWhereOrNull((element) => element.idInPlaylist == playlist);

    if (cachedProduct != null) {
      return cachedProduct;
    } else {
      return null;
    }
  }

  /// Write [playlists] to box
  Future<void> writePlaylistsToBox(List<Playlist> playlists) async {
    final box = playlistsBox;

    // Preserve locally-stored, server-less toggles (skipIntros / sleepMode)
    // across a server refresh, keyed by playlist id.
    final existingToggles = {
      for (final playlist in box.values)
        playlist.id: (
          skipIntros: playlist.skipIntros,
          sleepMode: playlist.sleepMode,
        ),
    };

    playlistsBox.clear();

    try {
      for (final playlist in playlists) {
        final toggles = existingToggles[playlist.id];
        await box.put(
          playlist.id,
          toggles == null
              ? playlist
              : playlist.copyWith(
                  skipIntros: toggles.skipIntros,
                  sleepMode: toggles.sleepMode,
                ),
        );
      }
    } catch (e) {
      debugPrint('Error writing playlists to box: $e');
    }
  }

  Future<void> writePlaylistToBox(Playlist playlist) async {
    final box = playlistsBox;

    try {
      await box.put(playlist.id, playlist);
    } catch (e) {
      debugPrint('Error writing playlist to box: $e');
    }
  }

  Future<Playlist> addToPlaylist(Product audio, Playlist playlist) async {
    try {
      // Guard: the backend addresses a track inside a playlist by its
      // per-account `plrefid` (mapped to `Product.idInPlaylist`). For some
      // entries in a user's library this field is missing/null — e.g. titles
      // that have no playlist-reference id allocated for that account. Posting
      // `entries: '["null"]'` returns error == 0 from the server, so the cubit
      // would otherwise emit success even though nothing was persisted, which
      // is exactly the "added successfully but never shows up" symptom
      // reported by customers on Samsung A25 / One UI 8.5.
      if (audio.idInPlaylist == null || audio.idInPlaylist!.isEmpty) {
        throw Exception(
          "This track can't be added to a playlist. Please contact support.",
        );
      }

      final user = currentUserRepository.currentUser;
      final addToPlaylistFormData = FormData.fromMap(
        {
          "action": Config.addToPlaylistAction,
          "rev": 1,
          "name": user.email,
          "pass": user.accessToken,
          "id": playlist.id,
          "entries": '["${audio.idInPlaylist}"]',
        },
      );

      debugPrint("addToPlaylist initial playlist: ${playlist.toJson()}");
      debugPrint(
          "addToPlaylist form data: {${addToPlaylistFormData.fields.map((e) => "${e.key} : ${e.value}").join(", ")}}");

      final response = await httpClient.post(
        "/${Config.userPlaylistsPath}",
        data: addToPlaylistFormData,
      );

      debugPrint("addToPlaylist response: $response");

      final decoded = jsonDecode(response.data);
      final responseErrorCode = decoded['error'];
      // error == 6 is the backend's "entry already in playlist" code and is
      // treated as success below.
      if (responseErrorCode > 0 && responseErrorCode != 6) {
        throw Exception(decoded['errorstr']);
      } else if (responseErrorCode < 0) {
        throw Exception(responseErrorCode);
      }

      final updatedPlaylist = await _parsePlaylistFrom(response);

      // Verify the server actually persisted the entry. If the response's
      // entries list doesn't reference this audio (and we weren't told the
      // entry was already present), the add silently failed server-side and
      // we must surface that to the user instead of showing a fake success.
      final entries =
          (decoded['entries'] as List<dynamic>?)?.map((e) => e.toString()) ??
              const <String>[];
      final persisted = entries.contains(audio.idInPlaylist) ||
          updatedPlaylist.products.any((p) => p.id == audio.id);
      if (responseErrorCode != 6 && !persisted) {
        throw Exception(
          "We couldn't add that track to your playlist. Please try again.",
        );
      }

      return updatedPlaylist;
    } catch (e) {
      return Future.error(e);
    }
  }

  Future<Playlist> removeFromPlaylist(Product audio, Playlist playlist) async {
    try {
      final user = currentUserRepository.currentUser;
      final removeFromPlaylistFormData = FormData.fromMap(
        {
          "action": Config.removeFromPlaylistAction,
          "rev": 1,
          "name": user.email,
          "pass": user.accessToken,
          "id": playlist.id,
          "entries": '["${audio.idInPlaylist}"]',
        },
      );

      debugPrint("removeFromPlaylist initial playlist: ${playlist.toJson()}");
      debugPrint(
          "removeFromPlaylist form data: {${removeFromPlaylistFormData.fields.map((e) => "${e.key} : ${e.value}").join(", ")}}");

      final response = await httpClient.post(
        "/${Config.userPlaylistsPath}",
        data: removeFromPlaylistFormData,
      );

      debugPrint("removeFromPlaylist response: $response");

      final responseErrorCode = jsonDecode(response.data)['error'];
      if (responseErrorCode > 0 && responseErrorCode != 6) {
        throw Exception(jsonDecode(response.data)['errorstr']);
      } else if (responseErrorCode < 0) {
        throw Exception(responseErrorCode);
      }

      final updatedPlaylist = _parsePlaylistFrom(response);
      return updatedPlaylist;
    } catch (e) {
      return Future.error(e);
    }
  }

  Future<Playlist> updatePlaylistEntry({
    required String username,
    required String password,
    required Playlist playlist,
    required List<Product> products,
  }) async {
    try {
      final savePlaylistFormData = FormData.fromMap(
        {
          "action": Config.userSavePlaylistAction,
          "rev": 1,
          "name": username,
          "pass": password,
          "id": playlist.id,
          "entries": products
              .where((element) => element.idInPlaylist != null)
              .map((product) => product.idInPlaylist)
              .toList()
              .toString(),
        },
      );

      debugPrint("updatePlaylistEntry initial playlist: ${playlist.toJson()}");
      debugPrint(
          "updatePlaylistEntry form data: {${savePlaylistFormData.fields.map((e) => "${e.key} : ${e.value}").join(", ")}}");
      final response = await httpClient.post(
        "/${Config.userPlaylistsPath}",
        data: savePlaylistFormData,
      );

      debugPrint("updatePlaylistEntry response: ${response.data}");

      final responseErrorCode = jsonDecode(response.data)['error'];
      if (responseErrorCode > 0) {
        throw Exception(jsonDecode(response.data)['errorstr']);
      } else if (responseErrorCode < 0) {
        throw Exception(responseErrorCode);
      }

      return await _parsePlaylistFrom(response);
    } catch (e) {
      return Future.error(e);
    }
  }

  Future<Playlist> _parsePlaylistFrom(Response<dynamic> response) async {
    final entries = jsonDecode(response.data)['entries'] as List<dynamic>;
    final newProducts = <Product>[];
    for (final entry in entries) {
      final product = await getProductById(entry.toString());
      if (product != null) {
        newProducts.add(product);
      }
    }
    return Playlist(
      jsonDecode(response.data)['id'],
      jsonDecode(response.data)['list'],
      newProducts,
      DateTime.now(),
    );
  }
}
