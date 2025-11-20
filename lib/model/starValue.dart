class Starvalue {
  int? id;
  int? cycleID;
  int? stars;
  int? points;

  Starvalue({
    this.id,
    this.cycleID,
    this.stars,
    this.points,
  });

  factory Starvalue.fromMap(Map<String, dynamic> map) {
    return Starvalue(
      id: map['idStarValue'] as int?,
      cycleID: map['cycleID'] as int?,
      stars: map['stars'] as int?,
      points: map['points'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cycleID': cycleID,
      'stars': stars,
      'points': points,
    };
  }
}