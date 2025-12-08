  class UserModel {
    final int idUser;
    final String names;
    final String email;
    int state;
    final DateTime createdAt;
    final int articles;
    final String? avatarUrl; // 👈 nueva propiedad opcional
    final String? role; // 👈 nuevo campo opcional


    UserModel({
      required this.idUser,
      required this.names,
      required this.email,
      required this.state,
      required this.createdAt,
      required this.articles,
      this.avatarUrl,
      this.role,
      opcional

    });

    factory UserModel.fromJson(Map<String, dynamic> json) {
      return UserModel(
        idUser: json['idUser'] as int,
        names: json['names'] ?? '',
        email: json['email'] ?? '',
        state: json['state'] ?? 0,
        createdAt: DateTime.parse(json['created_at']),
        articles: json['articles'] ?? 0,
        avatarUrl: json['avatarUrl'], // 👈 agrega la URL del avatar si existe
        role: json['role'], // 👈 agrega el rol

      );
    }
  }
