class Employee {
  int? idEmployee;
  int? userId; // Links to users table
  int? companyId;
  String? temporaryPassword;

  Employee({
    this.idEmployee,
    this.userId,
    this.companyId,
    this.temporaryPassword,
  });

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      idEmployee: map['idEmployee'] as int?,
      userId: map['userID'] as int?,
      companyId: map['companyID'] as int?,
      temporaryPassword: map['temporaryPassword'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (userId != null) 'userID': userId,
      if (companyId != null) 'companyID': companyId,
      if (temporaryPassword != null) 'temporaryPassword': temporaryPassword,
    };
  }

  @override
  String toString() {
    return 'Employee{idEmployee: $idEmployee, userId: $userId, companyId: $companyId}';
  }
}
