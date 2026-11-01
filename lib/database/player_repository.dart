import 'package:sqflite/sqflite.dart';

import '../models/player.dart';
import 'database_helper.dart';

class PlayerRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> insert(Player player) async {
    final Database db = await _databaseHelper.database;

    return await db.insert(
      'players',
      player.toMap(),
    );
  }

  Future<List<Player>> getAll() async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'players',
      orderBy: 'number ASC',
    );

    return maps.map((e) => Player.fromMap(e)).toList();
  }

  Future<int> update(Player player) async {
    final Database db = await _databaseHelper.database;

    return await db.update(
      'players',
      player.toMap(),
      where: 'id = ?',
      whereArgs: [player.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _databaseHelper.database;

    await db.delete(
      'players',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> numberExists(int number, {int? ignoreId}) async {
    final db = await _databaseHelper.database;

    final result = await db.query(
      'players',
      where: ignoreId == null
          ? 'number = ?'
          : 'number = ? AND id != ?',
      whereArgs: ignoreId == null
          ? [number]
          : [number, ignoreId],
    );

    return result.isNotEmpty;
  }
}