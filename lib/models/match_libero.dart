class MatchLibero {
  int? id;

  int matchId;
  int playerId;

  MatchLibero({
    this.id,
    required this.matchId,
    required this.playerId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matchId': matchId,
      'playerId': playerId,
    };
  }

  factory MatchLibero.fromMap(Map<String, dynamic> map) {
    return MatchLibero(
      id: map['id'],
      matchId: map['matchId'],
      playerId: map['playerId'],
    );
  }
}