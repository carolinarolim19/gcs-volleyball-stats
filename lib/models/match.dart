class Match {
  int? id;

  String opponent;
  String competition;
  DateTime dateTime;
  bool home;
  int sets;
  bool official;
  bool firstServer;
  bool gcsLeft;

  int gcsSets;
  int opponentSets;
  bool finished;

  Match({
    this.id,
    required this.opponent,
    required this.competition,
    required this.dateTime,
    required this.home,
    required this.sets,
    this.official = true,
    this.gcsLeft = true,
    this.firstServer = true,
    this.gcsSets = 0,
    this.opponentSets = 0,
    this.finished = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'opponent': opponent,
      'competition': competition,
      'dateTime': dateTime.toIso8601String(),
      'home': home ? 1 : 0,
      'sets': sets,
      'official': official ? 1 : 0,
      'gcsLeft': gcsLeft ? 1 : 0,
      'firstServer': firstServer ? 1 : 0,
      'gcsSets': gcsSets,
      'opponentSets': opponentSets,
      'finished': finished ? 1 : 0,
    };
  }

  factory Match.fromMap(Map<String, dynamic> map) {
    return Match(
      id: map['id'],
      opponent: map['opponent'],
      competition: map['competition'] ?? '',
      dateTime: DateTime.parse(map['dateTime']),
      home: map['home'] == 1,
      sets: map['sets'],
      official: map['official'] == 1,
      gcsLeft: map['gcsLeft'] == 1,
      firstServer: map['firstServer'] == 1,
      gcsSets: map['gcsSets'] ?? 0,
      opponentSets: map['opponentSets'] ?? 0,
      finished: map['finished'] == 1,

    );
  }
}