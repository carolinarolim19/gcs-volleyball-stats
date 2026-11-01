import 'package:flutter/material.dart';

import '../database/match_player_repository.dart';
import '../models/match_player.dart';

class MatchPlayerProvider extends ChangeNotifier {
  final MatchPlayerRepository _repository = MatchPlayerRepository();

  Future saveSquad(
      int matchId,
      List playerIds,
      ) async {

    await _repository.deleteByMatch(matchId);

    for (final id in playerIds) {
      await _repository.insert(
        MatchPlayer(
          matchId: matchId,
          playerId: id,
        ),
      );
    }
  }

  Future<List<int>> getSquad(int matchId) async {
    final players = await _repository.getByMatch(matchId);

    return players
        .map<int>((player) => player.playerId)
        .toList();
  }
}