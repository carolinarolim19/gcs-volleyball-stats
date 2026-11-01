import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class MatchPointUndoStateRepository {
  final DatabaseHelper _databaseHelper =
      DatabaseHelper.instance;

  Future<int> saveState({
    int? eventId,
    required int matchId,
    required int setNumber,
    required String team,
    required bool previousGcsServing,
    required List<int> lineupPlayerIds,
    int? activeLiberoId,
    int? replacedPlayerId,
    int previousRallyId = 1,
  }) async {
    final db = await _databaseHelper.database;

    return await db.insert(
      'match_point_undo_state',
      {
        'eventId': eventId,
        'matchId': matchId,
        'setNumber': setNumber,
        'team': team,
        'previousGcsServing':
        previousGcsServing ? 1 : 0,
        'lineup': jsonEncode(lineupPlayerIds),
        'activeLiberoId': activeLiberoId,
        'replacedPlayerId': replacedPlayerId,
        'previousRallyId': previousRallyId,
      },
      conflictAlgorithm:
      ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>>
  getByMatchAndSet(
      int matchId,
      int setNumber,
      ) async {
    final db = await _databaseHelper.database;

    return db.query(
      'match_point_undo_state',
      where: 'matchId = ? AND setNumber = ?',
      whereArgs: [
        matchId,
        setNumber,
      ],
      orderBy: 'id ASC',
    );
  }

  Future<void> deleteByEventId(
      int eventId,
      ) async {
    final db = await _databaseHelper.database;

    await db.delete(
      'match_point_undo_state',
      where: 'eventId = ?',
      whereArgs: [eventId],
    );
  }

  Future<void> deleteById(
      int id,
      ) async {
    final db = await _databaseHelper.database;

    await db.delete(
      'match_point_undo_state',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearMatch(
      int matchId,
      ) async {
    final db = await _databaseHelper.database;

    await db.delete(
      'match_point_undo_state',
      where: 'matchId = ?',
      whereArgs: [matchId],
    );
  }

  Future<Map<int, int>> getPointsPlayedByPlayer({
    required int matchId,
    required int setNumber,
  }) async {
    final states = await getByMatchAndSet(
      matchId,
      setNumber,
    );

    final pointsPlayed = <int, int>{};

    for (final state in states) {
      final lineupIds = decodeLineup(
        state['lineup'] as String,
      );

      for (final playerId in lineupIds) {
        pointsPlayed[playerId] =
            (pointsPlayed[playerId] ?? 0) + 1;
      }
    }

    return pointsPlayed;
  }

  Future<int> getTotalPointsInSet({
    required int matchId,
    required int setNumber,
  }) async {
    final states = await getByMatchAndSet(
      matchId,
      setNumber,
    );

    return states.length;
  }

  List<int> decodeLineup(
      String value,
      ) {
    return List<int>.from(
      jsonDecode(value),
    );
  }
}