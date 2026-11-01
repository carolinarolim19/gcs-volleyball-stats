class MatchEvent {
  int? id;

  final int matchId;
  final int playerId;
  final String action;
  final String result;
  final int setNumber;
  final int? rallyId;

  MatchEvent({
    this.id,
    required this.matchId,
    required this.playerId,
    required this.action,
    required this.result,
    required this.setNumber,
    this.rallyId,
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "matchId": matchId,
      "playerId": playerId,
      "action": action,
      "result": result,
      "setNumber": setNumber,
      "rallyId": rallyId,
    };
  }

  factory MatchEvent.fromMap(Map<String, dynamic> map) {
    return MatchEvent(
      id: map["id"],
      matchId: map["matchId"],
      playerId: map["playerId"],
      action: map["action"],
      result: map["result"],
      setNumber: map["setNumber"],
      rallyId: map["rallyId"] as int?,
    );
  }
}