import '../models/match_event.dart';
import 'database_helper.dart';

class MatchEventRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> insert(MatchEvent event) async {
    final db = await _databaseHelper.database;

    return await db.insert(
      'match_events',
      event.toMap(),
    );
  }

  Future<List<MatchEvent>> getByMatch(int matchId) async {
    final db = await _databaseHelper.database;

    final maps = await db.query(
      'match_events',
      where: 'matchId = ?',
      whereArgs: [matchId],
      orderBy: 'id ASC',
    );

    return maps.map((e) => MatchEvent.fromMap(e)).toList();
  }

  Future<void> deleteAllFromMatch(int matchId) async {
    final db = await _databaseHelper.database;

    await db.delete(
      'match_events',
      where: 'matchId = ?',
      whereArgs: [matchId],
    );
  }

  Future<void> deleteById(int id) async {
    final db = await _databaseHelper.database;

    await db.delete(
      'match_events',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateResult(
      int id,
      String result,
      ) async {
    final db = await _databaseHelper.database;

    await db.update(
      'match_events',
      {
        'result': result,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}