import 'package:flutter/material.dart';

import '../database/match_repository.dart';
import '../models/match.dart';

class MatchProvider extends ChangeNotifier {
  final MatchRepository _repository = MatchRepository();

  List<Match> _matches = [];

  List<Match> get matches => _matches;

  Future<void> loadMatches() async {
    _matches = await _repository.getAll();

    _matches.sort(
          (a, b) => b.dateTime.compareTo(a.dateTime),
    );

    notifyListeners();
  }

  Future<int> addMatch(Match match) async {
    final id = await _repository.insert(match);

    await loadMatches();

    return id;
  }

  Future<void> updateMatch(Match match) async {
    await _repository.update(match);
    await loadMatches();
  }

  Future<void> deleteMatch(int id) async {
    await _repository.delete(id);
    await loadMatches();
  }
}