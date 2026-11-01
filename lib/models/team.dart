class Team {
  int? id;

  String name;

  String? coach;

  bool isGCS;

  Team({
    this.id,
    required this.name,
    this.coach,
    this.isGCS = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'coach': coach,
      'isGCS': isGCS ? 1 : 0,
    };
  }

  factory Team.fromMap(Map<String, dynamic> map) {
    return Team(
      id: map['id'],
      name: map['name'],
      coach: map['coach'],
      isGCS: map['isGCS'] == 1,
    );
  }
}