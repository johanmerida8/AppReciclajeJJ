class RecyclingItem {
  final int id;
  final String title;
  final int? deliverID;
  final String? description;
  final int? categoryID;
  final String categoryName;
  final String? condition;
  final int? ownerUserId;
  final String userName;
  final String userEmail;
  final double latitude;
  final double longitude;
  final String address;
  final String availableDays;
  final String availableTimeStart;
  final String availableTimeEnd;
  final DateTime createdAt;
  final String? workflowStatus;

  RecyclingItem({
    required this.id,
    required this.title,
    this.deliverID,
    this.description,
    this.categoryID,
    this.condition,
    required this.categoryName,
    required this.ownerUserId,
    required this.userName,
    required this.userEmail,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.availableDays,
    required this.availableTimeStart,
    required this.availableTimeEnd,
    required this.createdAt,
    this.workflowStatus,
  });

  // ✅ Serialization methods for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'deliverID': deliverID,
      'description': description,
      'categoryID': categoryID,
      'categoryName': categoryName,
      'condition': condition,
      'ownerUserId': ownerUserId,
      'userName': userName,
      'userEmail': userEmail,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'availableDays': availableDays,
      'availableTimeStart': availableTimeStart,
      'availableTimeEnd': availableTimeEnd,
      'createdAt': createdAt.toIso8601String(),
      'workflowStatus': workflowStatus,
    };
  }

  factory RecyclingItem.fromJson(Map<String, dynamic> json) {
    return RecyclingItem(
      id: json['id'],
      title: json['title'],
      deliverID: json['deliverID'],
      description: json['description'],
      categoryID: json['categoryID'],
      categoryName: json['categoryName'],
      condition: json['condition'],
      ownerUserId: json['ownerUserId'],
      userName: json['userName'],
      userEmail: json['userEmail'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      address: json['address'],
      availableDays: json['availableDays'],
      availableTimeStart: json['availableTimeStart'],
      availableTimeEnd: json['availableTimeEnd'],
      createdAt: DateTime.parse(json['createdAt']),
      workflowStatus: json['workflowStatus'],
    );
  }
}