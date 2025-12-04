class ArticleHistoryModel {
  final int id;
  final String description;
  final int actorId;
  final int? targetID;
  final int ArticleID;
  final DateTime createdAt;

  ArticleHistoryModel({
    required this.id,
    required this.description,
    required this.actorId,
    this.targetID,
    required this.ArticleID,
    required this.createdAt,
  });

  factory ArticleHistoryModel.fromJson(Map<String, dynamic> json) {
    return ArticleHistoryModel(
      id: json['id'] as int,
      description: json['description'] ?? '',
      actorId: json['actorId'] as int,
      targetID: json['targetID'] != null ? json['targetID'] as int : null,
      ArticleID: json['ArticleID'] as int,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get formattedDate => createdAt.toLocal().toString();
}
