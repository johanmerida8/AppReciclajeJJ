class CompanyModel {
  final int idCompany;
  final String nameCompany;
  int state;
  final DateTime createdAt;
  final int? adminUserID;
  final String adminName;
  final String? adminEmail;
  final String? avatarUrl; // 👈 nueva propiedad opcional
  final int totalEmployees;
  final int totalArticlesApproved;
   String isApproved;


  CompanyModel({
    required this.idCompany,
    required this.nameCompany,
    required this.adminName,
    required this.state,
    required this.createdAt,
    required this.totalEmployees,
    required this.totalArticlesApproved,
    this.adminUserID,
    this.adminEmail,
    this.avatarUrl,
    required this.isApproved,
    
    
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      idCompany: json['idCompany'] as int,
      nameCompany: json['nameCompany'] ?? '',
      state: json['state'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      adminUserID: json['adminUserID'],
      adminName: json['users'] != null ? json['users']['names'] : null,
      adminEmail: json['users'] != null ? json['users']['email'] : null,
      avatarUrl: json['avatarUrl'],
      isApproved: json['isApproved'] ?? "Pending",

      // 👇 ESTO ES LO IMPORTANTE
      totalEmployees:
          json['employees'] != null && json['employees'].isNotEmpty
              ? json['employees'][0]['count'] ?? 0
              : 0,
          totalArticlesApproved:
        json['request'] != null && json['request'].isNotEmpty
            ? json['request'][0]['count'] ?? 0
            : 0,
    );
  }
}
