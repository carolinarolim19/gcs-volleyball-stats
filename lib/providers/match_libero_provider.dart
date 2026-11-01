import 'package:flutter/material.dart';

import '../database/match_libero_repository.dart';
import '../models/match_libero.dart';

class MatchLiberoProvider extends ChangeNotifier {
  final MatchLiberoRepository _repository =
  MatchLiberoRepository();

  List<MatchLibero> currentLiberos = [];

  Future<void> saveLiberos(
      int matchId,
      List<int> liberoIds,
      ) async {

    await _repository.deleteByMatch(matchId);

    for (final playerId in liberoIds) {

      await _repository.insert(
        MatchLibero(
          matchId: matchId,
          playerId: playerId,
        ),
      );

    }

    await loadLiberos(matchId);
  }

  Future<void> loadLiberos(int matchId) async {

    currentLiberos =
    await _repository.getByMatch(matchId);

    notifyListeners();
  }
}