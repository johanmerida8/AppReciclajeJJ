class Company {
  int? companyId;
  int? adminUserId;
  String? nameCompany;
  int? state;

  Company({
    this.companyId,
    this.adminUserId,
    this.nameCompany,
    this.state,
  });

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      companyId: map['idCompany'] as int,
      adminUserId: map['adminUserID'],
      nameCompany: map['nameCompany'] as String,
      state: map['state'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adminUserID': adminUserId,
      'nameCompany': nameCompany,
      'state': state,
    };
  }

  @override
  String toString() {
    return 'Company{idCompany: $companyId, adminUserId: $adminUserId, nameCompany: $nameCompany, state: $state}';
  }
}