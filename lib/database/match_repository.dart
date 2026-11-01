import 'package:sqflite/sqflite.dart';

import '../models/match.dart';
import 'database_helper.dart';

class MatchRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> insert(Match match) async {
    final db = await _databaseHelper.database;

    return await db.insert(
      'matches',
      match.toMap(),
    );
  }

  Future<List<Match>> getAll() async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'matches',
      orderBy: 'dateTime DESC',
    );

    return maps.map((e) => Match.fromMap(e)).toList();
  }

  Future<void> update(Match match) async {
    final db = await _databaseHelper.database;

    await db.update(
      'matches',
      match.toMap(),
      where: 'id = ?',
      whereArgs: [match.id],
    );
  }

  Future<void> finishMatch({
    required int matchId,
    required int gcsSets,
    required int opponentSets,
  }) async {
    final db = await _databaseHelper.database;

    await db.update(
      'matches',
      {
        'gcsSets': gcsSets,
        'opponentSets': opponentSets,
        'finished': 1,
      },
      where: 'id = ?',
      whereArgs: [matchId],
    );
  }

  Future<void> delete(int id) async {
    final Database db = await _databaseHelper.database;

    await db.delete(
      'matches',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}