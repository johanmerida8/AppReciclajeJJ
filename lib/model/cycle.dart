class Cycle {
  int? id;
  DateTime? startDate;
  DateTime? endDate;
  String? name;
  int? topQuantity;
  int? state;

  Cycle({
    this.id,
    this.startDate,
    this.endDate,
    this.name,
    this.topQuantity,
    this.state,
  });

  factory Cycle.fromMap(Map<String, dynamic> map) {
    return Cycle(
      id: map['idCycle'] as int?,
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']) : null,
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      name: map['cycleName'] as String?,
      topQuantity: map['topQuantity'] as int?,
      state: map['state'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'cycleName': name,
      'topQuantity': topQuantity,
      'state': state,
    };
  }
}