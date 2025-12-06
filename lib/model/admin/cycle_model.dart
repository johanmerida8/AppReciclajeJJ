class CycleModel {
  final int idCycle;
  final String name;
  final DateTime createdAt;
  final DateTime startDate;
  final DateTime endDate;
  final int topQuantity;
  final int state;

  CycleModel({
    required this.idCycle,
    required this.name,
    required this.createdAt,
    required this.startDate,
    required this.endDate,
    required this.topQuantity,
    required this.state,
  });

  factory CycleModel.fromJson(Map<String, dynamic> json) {
    return CycleModel(
      idCycle: json['idCycle'] as int,
      name: json['name'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      topQuantity: json['topQuantity'] ?? 0,
      state: json['state'] ?? 0,
    );
  }
}
