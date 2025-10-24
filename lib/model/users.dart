class Users {
  int? id;
  String? names;
  String? email;
  int? state;
  String? role;

  Users({
    this.id,
    this.names,
    this.email,
    this.state,
    this.role,
  });

  factory Users.fromMap(Map<String, dynamic> map) {
    return Users(
      id: map['idUser'] as int?,
      names: map['names'] as String?,
      email: map['email'] as String?,
      role: map['role'] as String?,
      state: map['state'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'names': names,
      'email': email,
      'role': role,
      'state': state,
    };
  }

  @override
  String toString() {
    return 'Users{id: $id, names: $names, email: $email, role: $role, state: $state}';
  }
}