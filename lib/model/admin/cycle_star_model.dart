class CycleStarModel {
  final int stars;
  final int points;

  CycleStarModel({
    required this.stars,
    required this.points,
  });

  factory CycleStarModel.fromJson(Map<String, dynamic> json) {
    return CycleStarModel(
      stars: json['stars'] as int,
      points: json['points'] as int,
    );
  }
}
