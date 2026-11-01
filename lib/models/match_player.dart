class MatchPlayer {
  int? id;

  int matchId;
  int playerId;

  bool selected;

  MatchPlayer({
    this.id,
    required this.matchId,
    required this.playerId,
    this.selected = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matchId': matchId,
      'playerId': playerId,
      'selected': selected ? 1 : 0,
    };
  }

  factory MatchPlayer.fromMap(Map<String, dynamic> map) {
    return MatchPlayer(
      id: map['id'],
      matchId: map['matchId'],
      playerId: map['playerId'],
      selected: map['selected'] == 1,
    );
  }
}