class Users {
  int? id;
  String? names;
  String? email;
  // String? password;
  int? state;

  Users({
    this.id,
    this.names,
    this.email,
    // this.password,
    this.state,
  });

  factory Users.fromMap(Map<String, dynamic> map) {
    return Users(
      id: map['idUser'] as int?,
      names: map['names'] as String?,
      email: map['email'] as String?,
      // password: map['password'] ?? '',
      state: map['state'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'names': names,
      'email': email,
      // 'password': password,
      'state': state,
    };
  }

  @override
  String toString() {
    return 'Users{id: $id, names: $names, email: $email, state: $state}';
  }
}