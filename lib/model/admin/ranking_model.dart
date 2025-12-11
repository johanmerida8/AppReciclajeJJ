class RankingModel {
  final int idUser;
  final String names;
   int totalPoints;
  int position;
  final int idCycle;
  final String cycleName;
  final DateTime startDate;
  final DateTime endDate;

  RankingModel({
    required this.idUser,
    required this.names,
    required this.totalPoints,
    required this.position,
    required this.idCycle,
    required this.cycleName,
    required this.startDate,
    required this.endDate,
  });
  // Crear una instancia de RankingModel a partir de un mapa JSON
  factory RankingModel.fromJson(Map<String, dynamic> json) {
    return RankingModel(
      idUser: json['idUser'] ?? 0,
      names: json['names'] ?? '',
      totalPoints: 
    json['totalPoints'] ??
    json['totalpoints'] ??
    json['total_points'] ??
    0,

      position: json['position'] ?? 0,
      idCycle: json['idCycle'] ?? 0,
      cycleName: json['cycleName'] ?? '',
      startDate:
          json['startDate'] != null
              ? DateTime.parse(json['startDate'].toString())
              : DateTime.now(),
      endDate:
          json['endDate'] != null
              ? DateTime.parse(json['endDate'].toString())
              : DateTime.now(),
    );
  }
}
