class daysAvailable {
  int? id;
  int? articleId;
  DateTime? availableDate;
  String? timeStart;
  String? timeEnd;

  daysAvailable({
    this.id,
    this.articleId,
    this.availableDate,
    this.timeStart,
    this.timeEnd,
  });

  factory daysAvailable.fromMap(Map<String, dynamic> map) {
    return daysAvailable(
      id: map['idDaysAvailable'] as int?,
      articleId: map['articleID'] as int?,
      availableDate: map['dateAvailable'] != null ? DateTime.parse(map['dateAvailable']) : null,
      timeStart: map['startTime'] as String?,
      timeEnd: map['endTime'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'articleID': articleId,
      'dateAvailable': availableDate?.toIso8601String(),
      'startTime': timeStart,
      'endTime': timeEnd,
    };
  }
}