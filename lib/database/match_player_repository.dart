import 'package:sqflite/sqflite.dart';

import '../models/match_player.dart';
import 'database_helper.dart';

class MatchPlayerRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<void> insert(MatchPlayer player) async {
    final Database db = await _databaseHelper.database;

    await db.insert(
      'match_players',
      player.toMap(),
    );
  }

  Future<List<MatchPlayer>> getByMatch(int matchId) async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'match_players',
      where: 'matchId = ?',
      whereArgs: [matchId],
    );

    return maps.map((e) => MatchPlayer.fromMap(e)).toList();
  }

  Future<void> deleteByMatch(int matchId) async {
    final Database db = await _databaseHelper.database;

    await db.delete(
      'match_players',
      where: 'matchId = ?',
      whereArgs: [matchId],
    );
  }
}