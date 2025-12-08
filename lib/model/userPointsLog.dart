class userPointsLog {
  int? id;
  int? userId;
  int? articleId;
  int? reviewId;
  int? cycleId;
  int? points;
  String? reason;
  String? type;
  int? state;
  DateTime? lastUpdate;

  userPointsLog({
    this.id,
    this.userId,
    this.articleId,
    this.reviewId,
    this.cycleId,
    this.points,
    this.reason,
    this.type,
    this.state,
    this.lastUpdate,
  });

  factory userPointsLog.fromMap(Map<String, dynamic> map) {
    return userPointsLog(
      id: map['idUserPointsLog'] as int?,
      userId: map['userID'] as int?,
      articleId: map['articleID'] as int?,
      reviewId: map['reviewID'] as int?,
      cycleId: map['cycleID'] as int?,
      points: map['experiencePoints'] as int?,
      reason: map['reason'] as String?,
      type: map['actionType'] as String?,
      state: map['state'] as int?,
      lastUpdate: map['lastUpdate'] != null
          ? DateTime.parse(map['lastUpdate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userID': userId,
      'articleID': articleId,
      'reviewID': reviewId,
      'cycleID': cycleId,
      'experiencePoints': points,
      'reason': reason,
      'actionType': type,
      'state': state,
      'lastUpdate': lastUpdate?.toIso8601String(),
    };
  }
}