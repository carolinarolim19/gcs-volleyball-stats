class Player {
  int? id;

  int number;
  String name;

  String primaryPosition;
  String? secondaryPosition;

  String status;

  bool active;

  Player({
    this.id,
    required this.number,
    required this.name,
    required this.primaryPosition,
    this.secondaryPosition,
    this.status = "Ativa",
    this.active = true,
  });

  Player copyWith({
    int? id,
    int? number,
    String? name,
    String? primaryPosition,
    String? secondaryPosition,
    String? status,
    bool? active,
  }) {
    return Player(
      id: id ?? this.id,
      number: number ?? this.number,
      name: name ?? this.name,
      primaryPosition: primaryPosition ?? this.primaryPosition,
      secondaryPosition: secondaryPosition ?? this.secondaryPosition,
      status: status ?? this.status,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'number': number,
      'name': name,
      'primaryPosition': primaryPosition,
      'secondaryPosition': secondaryPosition,
      'status': status,
      'active': active ? 1 : 0,
    };
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'],
      number: map['number'],
      name: map['name'],
      primaryPosition: map['primaryPosition'],
      secondaryPosition: map['secondaryPosition'],
      status: map['status'] ?? 'Ativa',
      active: map['active'] == 1,
    );
  }
}