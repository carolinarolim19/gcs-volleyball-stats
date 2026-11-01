import 'database_helper.dart';

class MatchSetStateRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<void> saveState({
    required int matchId,
    required int setNumber,
    required int activeLiberoId,
    required int replacedPlayerId,
  }) async {
    final db = await _databaseHelper.database;

    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO match_set_state(
        matchId,
        setNumber,
        activeLiberoId,
        replacedPlayerId
      )
      VALUES (?, ?, ?, ?)
      ''',
      [
        matchId,
        setNumber,
        activeLiberoId,
        replacedPlayerId,
      ],
    );
  }

  Future<Map<String, dynamic>?> getState(
      int matchId,
      int setNumber,
      ) async {
    final db = await _databaseHelper.database;

    final result = await db.query(
      'match_set_state',
      where: 'matchId = ? AND setNumber = ?',
      whereArgs: [
        matchId,
        setNumber,
      ],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  Future<void> clearState(
      int matchId,
      int setNumber,
      ) async {
    final db = await _databaseHelper.database;

    await db.delete(
      'match_set_state',
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
      'match_set_state',
      where: 'matchId = ?',
      whereArgs: [matchId],
    );
  }
}