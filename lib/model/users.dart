class Users {
  int? id;
  String? names;
  String? email;
  String? role;
  String? avatarUrl;
  String? avatarFilePath;
  String? avatarFileName;
  int? state;
  DateTime? lastUpdate;

  Users({
    this.id,
    this.names,
    this.email,
    this.role,
    this.avatarUrl,
    this.avatarFilePath,
    this.avatarFileName,
    this.state,
    this.lastUpdate,
  });

  factory Users.fromMap(Map<String, dynamic> map) {
    return Users(
      id: map['idUser'] as int?,
      names: map['names'] as String?,
      email: map['email'] as String?,
      role: map['role'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      avatarFilePath: map['avatarFilePath'] as String?,
      avatarFileName: map['avatarFileName'] as String?,
      state: map['state'] as int?,
      lastUpdate: map['lastUpdate'] != null ? DateTime.parse(map['lastUpdate']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'names': names,
      'email': email,
      'role': role,
      'avatarUrl': avatarUrl,
      'avatarFilePath': avatarFilePath,
      'avatarFileName': avatarFileName,
      'state': state,
      'lastUpdate': lastUpdate?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Users{id: $id, names: $names, email: $email, role: $role, avatarUrl: $avatarUrl, avatarFilePath: $avatarFilePath, avatarFileName: $avatarFileName, state: $state, lastUpdate: $lastUpdate}';
  }
}