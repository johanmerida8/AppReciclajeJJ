class Company {
  int? companyId;
  int? adminUserId;
  String? nameCompany;
  int? state;
  String? isApproved; // "Approved", "Rejected", "Pending"

  Company({
    this.companyId,
    this.adminUserId,
    this.nameCompany,
    this.state,
    this.isApproved,
  });

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      companyId: map['idCompany'] as int,
      adminUserId: map['adminUserID'],
      nameCompany: map['nameCompany'] as String,
      state: map['state'] as int,
      isApproved: map['isApproved'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adminUserID': adminUserId,
      'nameCompany': nameCompany,
      'state': state,
      'isApproved': isApproved,
    };
  }

  @override
  String toString() {
    return 'Company{idCompany: $companyId, adminUserId: $adminUserId, nameCompany: $nameCompany, state: $state, isApproved: $isApproved}';
  }
}