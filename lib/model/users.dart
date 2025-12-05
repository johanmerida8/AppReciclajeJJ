class Users {
  int? id;
  String? names;
  String? email;
  String? role;
  int? state;
  DateTime? lastUpdate;
  bool? isLoggedIn;

  Users({
    this.id,
    this.names,
    this.email,
    this.role,
    this.state,
    this.lastUpdate,
    this.isLoggedIn,
  });

  factory Users.fromMap(Map<String, dynamic> map) {
    return Users(
      id: map['idUser'] as int?,
      names: map['names'] as String?,
      email: map['email'] as String?,
      role: map['role'] as String?,
      state: map['state'] as int?,
      lastUpdate:
          map['lastUpdate'] != null ? DateTime.parse(map['lastUpdate']) : null,
      isLoggedIn: map['isLoggedIn'] as bool?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'names': names,
      'email': email,
      'role': role,
      'state': state,
      'lastUpdate': lastUpdate?.toIso8601String(),
      'isLoggedIn': isLoggedIn,
    };
  }

  @override
  String toString() {
    return 'Users{id: $id, names: $names, email: $email, role: $role, state: $state, lastUpdate: $lastUpdate, isLoggedIn: $isLoggedIn}';
  }
}
