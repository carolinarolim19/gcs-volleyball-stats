import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'match_point_undo_state_repository.dart';

class MatchSetParticipationRepository {

  final DatabaseHelper _databaseHelper =
      DatabaseHelper.instance;

  final MatchPointUndoStateRepository
  _pointUndoStateRepository =
  MatchPointUndoStateRepository();

  Future<void> markPlayerInGame({
    required int matchId,
    required int setNumber,
    required int playerId,
  }) async {
    final db = await _databaseHelper.database;

    await db.insert(
      'match_set_participation',
      {
        'matchId': matchId,
        'setNumber': setNumber,
        'playerId': playerId,
      },
      conflictAlgorithm:
      ConflictAlgorithm.ignore,
    );
  }

  Future<List<int>> getPlayersInGame({
    required int matchId,
    required int setNumber,
  }) async {
    final db = await _databaseHelper.database;

    final rows = await db.query(
      'match_set_participation',
      columns: ['playerId'],
      where: 'matchId = ? AND setNumber = ?',
      whereArgs: [matchId, setNumber],
    );

    return rows
        .map((row) => row['playerId'] as int)
        .toList();
  }

  Future<Map<int, Map<String, int>>> getSetParticipationStats({
    required int matchId,
    required int setNumber,
  }) async {
    final playersInGame = await getPlayersInGame(
      matchId: matchId,
      setNumber: setNumber,
    );

    final pointsPlayed =
    await _pointUndoStateRepository.getPointsPlayedByPlayer(
      matchId: matchId,
      setNumber: setNumber,
    );

    final totalPoints =
    await _pointUndoStateRepository.getTotalPointsInSet(
      matchId: matchId,
      setNumber: setNumber,
    );

    final stats = <int, Map<String, int>>{};

    for (final playerId in playersInGame) {
      final played = pointsPlayed[playerId] ?? 0;

      stats[playerId] = {
        'pointsPlayed': played,
        'pointsOut': totalPoints - played,
      };
    }

    return stats;
  }

  Future<Map<int, Map<String, int>>> getMatchParticipationStats({
    required int matchId,
  }) async {
    final db = await _databaseHelper.database;

    final setRows = await db.query(
      'match_set_participation',
      columns: ['setNumber'],
      where: 'matchId = ?',
      whereArgs: [matchId],
      distinct: true,
      orderBy: 'setNumber ASC',
    );

    final totals = <int, Map<String, int>>{};

    for (final row in setRows) {
      final setNumber = row['setNumber'] as int;

      final setStats = await getSetParticipationStats(
        matchId: matchId,
        setNumber: setNumber,
      );

      for (final entry in setStats.entries) {
        final playerId = entry.key;
        final playerStats = entry.value;

        totals.putIfAbsent(
          playerId,
              () => {
            'pointsPlayed': 0,
            'pointsOut': 0,
            'setsInGame': 0,
          },
        );

        totals[playerId]!['pointsPlayed'] =
            totals[playerId]!['pointsPlayed']! +
                playerStats['pointsPlayed']!;

        totals[playerId]!['pointsOut'] =
            totals[playerId]!['pointsOut']! +
                playerStats['pointsOut']!;

        totals[playerId]!['setsInGame'] =
            totals[playerId]!['setsInGame']! + 1;
      }
    }

    return totals;
  }

  Future<void> clearMatch(int matchId) async {
    final db = await _databaseHelper.database;

    await db.delete(
      'match_set_participation',
      where: 'matchId = ?',
      whereArgs: [matchId],
    );
  }
}