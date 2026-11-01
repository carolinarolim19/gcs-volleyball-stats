import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class MatchSubstitutionStateRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<void> savePair({
    required int matchId,
    required int setNumber,
    required int starterId,
    required int substituteId,
  }) async {
    final db = await _databaseHelper.database;

    await db.insert(
      'match_substitution_state',
      {
        'matchId': matchId,
        'setNumber': setNumber,
        'starterId': starterId,
        'substituteId': substituteId,
        'completed': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markCompleted({
    required int matchId,
    required int setNumber,
    required int starterId,
  }) async {
    final db = await _databaseHelper.database;

    await db.update(
      'match_substitution_state',
      {
        'completed': 1,
      },
      where:
      'matchId = ? AND setNumber = ? AND starterId = ?',
      whereArgs: [
        matchId,
        setNumber,
        starterId,
      ],
    );
  }

  Future<List<Map<String, dynamic>>> getByMatchAndSet(
      int matchId,
      int setNumber,
      ) async {
    final db = await _databaseHelper.database;

    return db.query(
      'match_substitution_state',
      where: 'matchId = ? AND setNumber = ?',
      whereArgs: [
        matchId,
        setNumber,
      ],
    );
  }

  Future<void> clearSet(
      int matchId,
      int setNumber,
      ) async {
    final db = await _databaseHelper.database;

    await db.delete(
      'match_substitution_state',
      where: 'matchId = ? AND setNumber = ?',
      whereArgs: [
        matchId,
        setNumber,
      ],
    );
  }

  Future<void> clearMatch(
      int matchId,
      ) async {
    final db = await _databaseHelper.database;

    await db.delete(
      'match_substitution_state',
      where: 'matchId = ?',
      whereArgs: [matchId],
    );
  }
}