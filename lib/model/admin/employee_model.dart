class EmployeeModel {
  final int idUser;
  final String names;
  int state;
  final DateTime createdAt;
  final int articles;
  final String? avatarUrl; // 👈 nueva propiedad opcional nuevo campo opcional


  EmployeeModel({
    required this.idUser,
    required this.names,
    required this.state,
    required this.createdAt,
    required this.articles,
    this.avatarUrl,
    opcional

  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      idUser: json['idUser'] as int,
      names: json['names'] ?? '',
      state: json['state'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      articles: json['articles'] ?? 0,
      avatarUrl: json['avatarUrl'], // 👈 agrega la URL del avatar si existe

    );
  }
}
