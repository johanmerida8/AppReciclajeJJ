class Article {
  int? id;
  int? userId;
  int? categoryID;
  String? name;
  String? condition;
  String? description;
  String? address;
  double? lat;
  double? lng;
  // String? availableDays;
  // String? availableTimeStart;
  // String? availableTimeEnd;
  // int? deliverID;
  int? state;
  DateTime? lastUpdate;

  Article ({
    this.id,
    this.userId,
    this.categoryID,
    this.name,
    this.condition,
    this.description,
    this.address,
    this.lat,
    this.lng,
    // this.deliverID,
    // this.availableDays,
    // this.availableTimeStart,
    // this.availableTimeEnd,
    this.state,
    this.lastUpdate,
  });

  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      id: map['idArticle'] as int?,
      name: map['name'] as String?,
      categoryID: map['categoryID'] as int?,
      condition: map['condition'] as String?,
      description: map['description'] as String?,
      address: map['address'] as String,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      // deliverID: map['deliverID'] as int?,
      userId: map['userID'] as int?,
      // availableDays: map['availableDays'] as String?,
      // availableTimeStart: map['availableTimeStart'] as String?,
      // availableTimeEnd: map['availableTimeEnd'] as String?,
      state: map['state'] as int?,
      lastUpdate: map['lastUpdate'] != null ? DateTime.parse(map['lastUpdate']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'categoryID': categoryID,
      'condition': condition,
      'description': description,
      'address': address,
      'lat': lat,
      'lng': lng,
      // 'deliverID': deliverID,
      'userID': userId,
      // 'availableDays': availableDays,
      // 'availableTimeStart': availableTimeStart,
      // 'availableTimeEnd': availableTimeEnd,
      'state': state,
      'lastUpdate': lastUpdate?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Article{id: $id, name: $name, categoryID: $categoryID, condition: $condition, description: $description, address: $address, lat: $lat, lng: $lng, userID: $userId, state: $state, lastUpdate: $lastUpdate}';
  }
}