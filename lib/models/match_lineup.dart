class MatchLineup {
  int? id;

  int matchId;
  int setNumber;
  int playerId;
  int position;

  MatchLineup({
    this.id,
    required this.matchId,
    required this.setNumber,
    required this.playerId,
    required this.position,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matchId': matchId,
      'setNumber': setNumber,
      'playerId': playerId,
      'position': position,
    };
  }

  factory MatchLineup.fromMap(Map<String, dynamic> map) {
    return MatchLineup(
      id: map['id'],
      matchId: map['matchId'],
      setNumber: map['setNumber'] ?? 1,
      playerId: map['playerId'],
      position: map['position'],
    );
  }
}