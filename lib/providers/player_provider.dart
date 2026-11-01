import 'package:flutter/material.dart';

import '../database/player_repository.dart';
import '../models/player.dart';


class PlayerProvider extends ChangeNotifier {
  final PlayerRepository _repository = PlayerRepository();

  List<Player> _players = [];

  List<Player> get players => _players;

  List<Player> get activePlayers =>
      _players.where((p) => p.status == "Ativa").toList();

  Future<void> loadPlayers() async {
    _players = await _repository.getAll();

    _players.sort((a, b) => a.number.compareTo(b.number));

    notifyListeners();
  }

  Future<void> addPlayer(Player player) async {
    await _repository.insert(player);
    await loadPlayers();
  }

  Future<void> updatePlayer(Player player) async {
    await _repository.update(player);
    await loadPlayers();
  }

  Future<void> deletePlayer(int id) async {
    await _repository.delete(id);
    await loadPlayers();
  }

  Future<bool> numberExists(int number, {int? ignoreId}) async {
    return await _repository.numberExists(
      number,
      ignoreId: ignoreId,
    );
  }
}