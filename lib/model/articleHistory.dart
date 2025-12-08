class articleHistory {
  int? id;
  int? articleId;
  int? actorId;
  int? targetId;
  String? description;

  articleHistory({
    this.id,
    this.articleId,
    this.actorId,
    this.targetId,
    this.description,
  });

  factory articleHistory.fromMap(Map<String, dynamic> map) {
    return articleHistory(
      id: map['id'],
      articleId: map['ArticleID'],
      actorId: map['actorId'],
      targetId: map['targetID'],
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ArticleID': articleId,
      'actorId': actorId,
      'targetID': targetId,
      'description': description,
    };
  }
}