import 'package:flutter/material.dart';

import '../database/match_lineup_repository.dart';
import '../models/match_lineup.dart';

class MatchLineupProvider extends ChangeNotifier {
  final MatchLineupRepository _repository =
  MatchLineupRepository();

  List<MatchLineup> _currentLineup = [];

  List<MatchLineup> get currentLineup => _currentLineup;

  Future saveLineup(
      int matchId,
      int setNumber,
      Map<int, int> lineup,
      ) async {

    await _repository.deleteByMatchAndSet(
      matchId,
      setNumber,
    );

    for (final item in lineup.entries) {

      await _repository.insert(
        MatchLineup(
          matchId: matchId,
          setNumber: setNumber,
          playerId: item.value,
          position: item.key,
        ),
      );

    }

  }

  Future<void> loadLineup(
      int matchId,
      int setNumber,
      ) async {

      _currentLineup =
      await _repository.getOrderedByPosition(
        matchId,
        setNumber,
      );

    notifyListeners();
  }

  Future<void> loadLineupForSet(
      int matchId,
      int setNumber,
      ) async {
      _currentLineup =
      await _repository.getByMatchAndSet(
        matchId,
        setNumber,
      );

    notifyListeners();
  }

  Future<void> updatePosition(
      int matchId,
      int setNumber,
      int playerId,
      int position,
      ) async {
    await _repository.updatePosition(
      matchId: matchId,
      setNumber: setNumber,
      playerId: playerId,
      position: position,
    );

    await loadLineup(matchId, setNumber);
  }
}
