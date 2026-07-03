import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:error_handling/error_handling.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'connectivity_status_state.dart';

class ConnectivityStatusCubit extends Cubit<ConnectivityStatusState> {
  ConnectivityStatusCubit(this.connectivity)
      : super(const ConnectivityStatusStateInitial());

  final Connectivity connectivity;
  StreamSubscription? connectivitySubscription;

  Future<void> onPageOpened() async {
    await _showConnectivityStatus();
    await _startListeningToConnectivityStatus();
  }

  Future<void> onPageClosed() async {
    await _stopListeningToConnectivityStatus();
  }

  Future<void> onBackPressed() async {
    emit(const ConnectivityStatusStateInitial());
  }

  Future<void> _showConnectivityStatus() async {
    emit(const ConnectivityStatusLoadInProgress());
    final results = await connectivity.checkConnectivity();
    emit(_stateFor(results));
  }

  Future<void> _startListeningToConnectivityStatus() async {
    try {
      connectivitySubscription =
          connectivity.onConnectivityChanged.listen((results) {
        emit(_stateFor(results));
      });
    } on UserCanceledException catch (_) {
      emit(const ConnectivityStatusStateInitial());
    } catch (e) {
      emit(ConnectivityStatusLoadFailure(e.toString()));
    }
  }

  /// connectivity_plus 6.x emits `List<ConnectivityResult>`. We treat the
  /// device as offline when the list is empty or contains only
  /// [ConnectivityResult.none].
  ConnectivityStatusState _stateFor(List<ConnectivityResult> results) {
    final hasConnection = results
        .any((r) => r != ConnectivityResult.none);
    return hasConnection
        ? const ConnectivityStatusOnline()
        : const ConnectivityStatusOffline();
  }

  Future<void> _stopListeningToConnectivityStatus() async {
    await connectivitySubscription?.cancel();
  }
}
