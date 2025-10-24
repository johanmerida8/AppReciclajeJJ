class Article {
  int? id;
  String? name;
  int? categoryID;
  String? condition;
  String? description;
  String? availableDays;
  String? availableTimeStart;
  String? availableTimeEnd;
  int? deliverID;
  int? userId;
  int? state;
  String? workflowStatus; // ✅ 'pendiente', 'asignado', 'en_proceso', 'completado'
  DateTime? lastUpdate;

  Article ({
    this.id,
    this.name,
    this.categoryID,
    this.condition,
    this.description,
    this.deliverID,
    this.userId,
    this.availableDays,
    this.availableTimeStart,
    this.availableTimeEnd,
    this.state,
    this.workflowStatus,
    this.lastUpdate,
  });

  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      id: map['idArticle'] as int?,
      name: map['name'] as String?,
      categoryID: map['categoryID'] as int?,
      condition: map['condition'] as String?,
      description: map['description'] as String?,
      deliverID: map['deliverID'] as int?,
      userId: map['userID'] as int?,
      availableDays: map['availableDays'] as String?,
      availableTimeStart: map['availableTimeStart'] as String?,
      availableTimeEnd: map['availableTimeEnd'] as String?,
      state: map['state'] as int?,
      workflowStatus: map['workflowStatus'] as String?,
      lastUpdate: map['lastUpdate'] != null ? DateTime.parse(map['lastUpdate']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'categoryID': categoryID,
      'condition': condition,
      'description': description,
      'deliverID': deliverID,
      'userID': userId,
      'availableDays': availableDays,
      'availableTimeStart': availableTimeStart,
      'availableTimeEnd': availableTimeEnd,
      'state': state,
      'workflowStatus': workflowStatus,
      'lastUpdate': lastUpdate?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Article{id: $id, name: $name, categoryID: $categoryID, condition: $condition, description: $description, deliverID: $deliverID, userID: $userId, availableDays: $availableDays, availableTimeStart: $availableTimeStart, availableTimeEnd: $availableTimeEnd, state: $state, lastUpdate: $lastUpdate}';
  }
}