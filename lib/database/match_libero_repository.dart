import 'package:sqflite/sqflite.dart';

import '../models/match_libero.dart';
import 'database_helper.dart';

class MatchLiberoRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<void> insert(MatchLibero libero) async {
    final Database db = await _databaseHelper.database;

    await db.insert(
      'match_liberos',
      libero.toMap(),
    );
  }

  Future<List<MatchLibero>> getByMatch(int matchId) async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'match_liberos',
      where: 'matchId = ?',
      whereArgs: [matchId],
    );

    return maps.map((e) => MatchLibero.fromMap(e)).toList();
  }

  Future<void> deleteByMatch(int matchId) async {
    final Database db = await _databaseHelper.database;

    await db.delete(
      'match_liberos',
      where: 'matchId = ?',
      whereArgs: [matchId],
    );
  }
}