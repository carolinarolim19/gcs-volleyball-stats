import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class MatchGameStateRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;


  Future<void> saveState({
    required int matchId,
    required int currentSet,
    required int gcsScore,
    required int opponentScore,
    required int gcsSets,
    required int opponentSets,
    required bool gcsServing,
    int? currentRallyId,
  }) async {
    final db = await _databaseHelper.database;

    final int rallyIdToSave;

    if (currentRallyId != null) {
      rallyIdToSave = currentRallyId;
    } else {
      // Se não for indicado um novo valor, mantém o contador atual.
      final existing = await db.query(
        'match_game_state',
        columns: ['currentRallyId'],
        where: 'matchId = ?',
        whereArgs: [matchId],
        limit: 1,
      );

      rallyIdToSave = existing.isEmpty
          ? 1
          : (existing.first['currentRallyId'] as int? ?? 1);
    }

    await db.insert(
      'match_game_state',
      {
        'matchId': matchId,
        'currentSet': currentSet,
        'gcsScore': gcsScore,
        'opponentScore': opponentScore,
        'gcsSets': gcsSets,
        'opponentSets': opponentSets,
        'gcsServing': gcsServing ? 1 : 0,
        'currentRallyId': rallyIdToSave,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getState(
      int matchId,
      ) async {
    final db = await _databaseHelper.database;

    final result = await db.query(
      'match_game_state',
      where: 'matchId = ?',
      whereArgs: [matchId],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  Future<void> clearState(
      int matchId,
      ) async {
    final db = await _databaseHelper.database;

    await db.delete(
      'match_game_state',
      where: 'matchId = ?',
      whereArgs: [matchId],
    );
  }
}