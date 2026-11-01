import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {

    if (_database != null) {
      return _database!;
    }

    _database = await _initDB("gcs.db");

    return _database!;
  }

  Future<Database> _initDB(String filePath) async {

    final dbPath = await getDatabasesPath();

    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 12,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );

  }

  Future _createDB(Database db, int version) async {

    await db.execute('''
    CREATE TABLE players(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      number INTEGER,
      name TEXT,
      primaryPosition TEXT,
      secondaryPosition TEXT,
      status TEXT,
      active INTEGER
    )
    ''');

    await db.execute('''
    CREATE TABLE teams(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      coach TEXT,
      isGCS INTEGER
    )
    ''');

    await db.execute('''
CREATE TABLE matches(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  opponent TEXT,
  competition TEXT,
  dateTime TEXT,
  home INTEGER,
  sets INTEGER,
  official INTEGER,
  firstServer INTEGER DEFAULT 1,
  gcsLeft INTEGER DEFAULT 1,
  gcsSets INTEGER DEFAULT 0,
  opponentSets INTEGER DEFAULT 0,
  finished INTEGER DEFAULT 0
)
''');

    await db.execute('''
    CREATE TABLE match_players(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      matchId INTEGER,
      playerId INTEGER,
      selected INTEGER
    )
    ''');

    await db.execute('''
    CREATE TABLE match_lineup(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    matchId INTEGER,
    setNumber INTEGER,
    playerId INTEGER,
    position INTEGER
)
    ''');

    await db.execute('''
    CREATE TABLE match_events(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      matchId INTEGER,
      playerId INTEGER,
      action TEXT,
      result TEXT,
      setNumber INTEGER,
      rallyId INTEGER
    )
    ''');

    await db.execute('''
    CREATE TABLE match_liberos(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      matchId INTEGER,
      playerId INTEGER
    )
    ''');

    await db.execute('''
  CREATE TABLE match_set_state(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    matchId INTEGER NOT NULL,
    setNumber INTEGER NOT NULL,
    activeLiberoId INTEGER,
    replacedPlayerId INTEGER,
    UNIQUE(matchId, setNumber)
  )
''');

    await db.execute('''
  CREATE TABLE match_game_state(
    matchId INTEGER PRIMARY KEY,
    currentSet INTEGER NOT NULL,
    gcsScore INTEGER NOT NULL DEFAULT 0,
    opponentScore INTEGER NOT NULL DEFAULT 0,
    gcsSets INTEGER NOT NULL DEFAULT 0,
    opponentSets INTEGER NOT NULL DEFAULT 0,
    gcsServing INTEGER NOT NULL DEFAULT 1,
    currentRallyId INTEGER NOT NULL DEFAULT 1
  )
''');

    await db.execute('''
  CREATE TABLE match_substitution_state(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    matchId INTEGER NOT NULL,
    setNumber INTEGER NOT NULL,
    starterId INTEGER NOT NULL,
    substituteId INTEGER NOT NULL,
    completed INTEGER NOT NULL DEFAULT 0,
    UNIQUE(matchId, setNumber, starterId)
  )
''');

    await db.execute('''
  CREATE TABLE match_point_undo_state(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    eventId INTEGER UNIQUE,
    matchId INTEGER NOT NULL,
    setNumber INTEGER NOT NULL,
    team TEXT NOT NULL,
    previousGcsServing INTEGER NOT NULL,
    lineup TEXT NOT NULL,
    activeLiberoId INTEGER,
    replacedPlayerId INTEGER,
    previousRallyId INTEGER NOT NULL DEFAULT 1
  )
''');

    await db.execute('''
  CREATE TABLE match_set_participation(
    matchId INTEGER NOT NULL,
    setNumber INTEGER NOT NULL,
    playerId INTEGER NOT NULL,
    PRIMARY KEY (matchId, setNumber, playerId)
  )
''');
  }

  Future<void> _upgradeDB(
      Database db,
      int oldVersion,
      int newVersion,
      ) async {

    if (oldVersion < 2) {

      await db.execute('''
      CREATE TABLE IF NOT EXISTS matches(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        opponent TEXT,
        competition TEXT,
        dateTime TEXT,
        home INTEGER,
        sets INTEGER,
        official INTEGER,
        firstServer INTEGER DEFAULT 1,
        gcsLeft INTEGER
      )
      ''');

      await db.execute('''
      CREATE TABLE IF NOT EXISTS match_players(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        matchId INTEGER,
        playerId INTEGER,
        selected INTEGER
      )
      ''');

      await db.execute('''
      CREATE TABLE IF NOT EXISTS match_lineup(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        matchId INTEGER,
        setNumber INTEGER,
        playerId INTEGER,
        position INTEGER
      )
      ''');

      await db.execute('''
      CREATE TABLE IF NOT EXISTS match_liberos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        matchId INTEGER,
        playerId INTEGER
      )
      ''');

    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE matches ADD COLUMN firstServer INTEGER DEFAULT 1',
      );

      await db.execute(
        'ALTER TABLE matches ADD COLUMN gcsLeft INTEGER DEFAULT 1',
      );
    }
    if (oldVersion < 4) {
        await db.execute(
          'ALTER TABLE match_lineup ADD COLUMN setNumber INTEGER DEFAULT 1',
        );
    }

    if (oldVersion < 5) {
      await db.execute('''
    CREATE TABLE match_set_state(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      matchId INTEGER NOT NULL,
      setNumber INTEGER NOT NULL,
      activeLiberoId INTEGER,
      replacedPlayerId INTEGER,
      UNIQUE(matchId, setNumber)
    )
  ''');
    }

    if (oldVersion < 6) {
      await db.execute('''
    CREATE TABLE match_game_state(
      matchId INTEGER PRIMARY KEY,
      currentSet INTEGER NOT NULL,
      gcsScore INTEGER NOT NULL DEFAULT 0,
      opponentScore INTEGER NOT NULL DEFAULT 0,
      gcsSets INTEGER NOT NULL DEFAULT 0,
      opponentSets INTEGER NOT NULL DEFAULT 0,
      gcsServing INTEGER NOT NULL DEFAULT 1
    )
  ''');
    }

    if (oldVersion < 7) {
      await db.execute('''
    CREATE TABLE match_substitution_state(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      matchId INTEGER NOT NULL,
      setNumber INTEGER NOT NULL,
      starterId INTEGER NOT NULL,
      substituteId INTEGER NOT NULL,
      completed INTEGER NOT NULL DEFAULT 0,
      UNIQUE(matchId, setNumber, starterId)
    )
  ''');
    }

    if (oldVersion < 8) {
    await db.execute(
    'ALTER TABLE matches ADD COLUMN gcsSets INTEGER DEFAULT 0',
    );

    await db.execute(
    'ALTER TABLE matches ADD COLUMN opponentSets INTEGER DEFAULT 0',
    );

    await db.execute(
    'ALTER TABLE matches ADD COLUMN finished INTEGER DEFAULT 0',
    );
    }

    if (oldVersion < 9) {
      await db.execute('''
    CREATE TABLE match_point_undo_state(
      eventId INTEGER PRIMARY KEY,
      matchId INTEGER NOT NULL,
      setNumber INTEGER NOT NULL,
      team TEXT NOT NULL,
      previousGcsServing INTEGER NOT NULL,
      lineup TEXT NOT NULL,
      activeLiberoId INTEGER,
      replacedPlayerId INTEGER
    )
  ''');
    }
    if (oldVersion < 10) {
      await db.execute('''
    CREATE TABLE match_point_undo_state_new(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      eventId INTEGER UNIQUE,
      matchId INTEGER NOT NULL,
      setNumber INTEGER NOT NULL,
      team TEXT NOT NULL,
      previousGcsServing INTEGER NOT NULL,
      lineup TEXT NOT NULL,
      activeLiberoId INTEGER,
      replacedPlayerId INTEGER
    )
  ''');

      await db.execute('''
    INSERT INTO match_point_undo_state_new(
      eventId,
      matchId,
      setNumber,
      team,
      previousGcsServing,
      lineup,
      activeLiberoId,
      replacedPlayerId
    )
    SELECT
      eventId,
      matchId,
      setNumber,
      team,
      previousGcsServing,
      lineup,
      activeLiberoId,
      replacedPlayerId
    FROM match_point_undo_state
    ORDER BY eventId ASC
  ''');

      await db.execute(
        'DROP TABLE match_point_undo_state',
      );

      await db.execute(
        'ALTER TABLE match_point_undo_state_new '
            'RENAME TO match_point_undo_state',
      );
    }

    if (oldVersion < 11) {
      await db.execute('''
    CREATE TABLE match_set_participation(
      matchId INTEGER NOT NULL,
      setNumber INTEGER NOT NULL,
      playerId INTEGER NOT NULL,
      PRIMARY KEY (matchId, setNumber, playerId)
    )
  ''');
    }

    if (oldVersion < 12) {
      await db.execute(
        'ALTER TABLE match_events ADD COLUMN rallyId INTEGER',
      );

      await db.execute('''
    ALTER TABLE match_game_state
    ADD COLUMN currentRallyId INTEGER NOT NULL DEFAULT 1
  ''');

      await db.execute('''
    ALTER TABLE match_point_undo_state
    ADD COLUMN previousRallyId INTEGER NOT NULL DEFAULT 1
  ''');
    }
  }
}