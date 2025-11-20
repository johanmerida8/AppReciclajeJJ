class CompanyModel {
  final int idCompany;
  final String nameCompany;
  final int state;
  final DateTime createdAt;
  final int? adminUserID;
  final String adminName;
  final String? adminEmail;
  final String? avatarUrl; // 👈 nueva propiedad opcional

  CompanyModel({
    required this.idCompany,
    required this.nameCompany,
    required this.adminName,
    required this.state,
    required this.createdAt,
    this.adminUserID,
    this.adminEmail,
    this.avatarUrl,
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
    );
  }
}
