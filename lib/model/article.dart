class Article {
  int? id;
  String? name;
  int? categoryID;
  String? description;
  int? deliverID;
  int? userId;
  int? state;

  Article ({
    this.id,
    this.name,
    this.categoryID,
    this.description,
    this.deliverID,
    this.userId,
    this.state,
  });

  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      id: map['idArticle'] as int?,
      name: map['name'] as String?,
      categoryID: map['categoryID'] as int?,
      description: map['description'] as String?,
      deliverID: map['deliverID'] as int?,
      userId: map['userID'] as int?,
      state: map['state'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'categoryID': categoryID,
      'description': description,
      'deliverID': deliverID,
      'userID': userId,
      'state': state,
    };
  }

  @override
  String toString() {
    return 'Article{id: $id, name: $name, categoryID: $categoryID, description: $description, deliverID: $deliverID, userID: $userId, state: $state}';
  }
}