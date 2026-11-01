import 'package:sqflite/sqflite.dart';

import '../models/match_lineup.dart';
import 'database_helper.dart';

class MatchLineupRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<void> insert(MatchLineup lineup) async {
    final Database db = await _databaseHelper.database;

    await db.insert(
      'match_lineup',
      lineup.toMap(),
    );
  }

  Future<List<MatchLineup>> getByMatch(int matchId) async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'match_lineup',
      where: 'matchId = ?',
      whereArgs: [matchId],
      orderBy: 'position',
    );

    return maps.map((e) => MatchLineup.fromMap(e)).toList();
  }

  Future<List<MatchLineup>> getOrderedByPosition(
      int matchId,
      int setNumber,
      ) async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'match_lineup',
      where: 'matchId = ? AND setNumber = ?',
      whereArgs: [matchId, setNumber],
      orderBy: 'position ASC',
    );

    return maps.map((e) => MatchLineup.fromMap(e)).toList();
  }

  Future deleteByMatch(int matchId) async {
    final Database db = await _databaseHelper.database;

    await db.delete(
      'match_lineup',
      where: 'matchId = ?',
      whereArgs: [matchId],
    );
  }

  Future<void> deleteByMatchAndSet(
      int matchId,
      int setNumber,
      ) async {
    final Database db = await _databaseHelper.database;

    await db.delete(
      'match_lineup',
      where: 'matchId = ? AND setNumber = ?',
      whereArgs: [
        matchId,
        setNumber,
      ],
    );
  }

  Future<void> updatePosition({
    required int matchId,
    required int setNumber,
    required int playerId,
    required int position,
  }) async {
    final Database db = await _databaseHelper.database;

    await db.update(
      'match_lineup',
      {
        'position': position,
      },
      where: 'matchId = ? AND setNumber = ? AND playerId = ?',
      whereArgs: [
        matchId,
        setNumber,
        playerId,
      ],
    );
  }

  Future<List<MatchLineup>> getByMatchAndSet(
      int matchId,
      int setNumber,
      ) async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'match_lineup',
      where: 'matchId = ? AND setNumber = ?',
      whereArgs: [
        matchId,
        setNumber,
      ],
      orderBy: 'position ASC',
    );

    return maps
        .map((e) => MatchLineup.fromMap(e))
        .toList();
  }
}