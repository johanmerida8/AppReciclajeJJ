class Task {
  int? idTask;
  int? employeeId;
  int? articleId;
  int? companyId;
  int? assignedBy; // userId of admin-empresa who assigned
  String? status; // 'sin_asignar', 'asignado', 'en_proceso', 'completado', 'cancelado'
  String? priority; // 'baja', 'media', 'alta', 'urgente'
  DateTime? assignedDate;
  DateTime? startDate;
  DateTime? completedDate;
  DateTime? dueDate;
  String? notes; // Admin notes
  String? employeeNotes; // Employee notes
  int? estimatedDuration; // Minutes
  int? actualDuration; // Minutes
  double? collectionLatitude;
  double? collectionLongitude;
  DateTime? lastUpdate;
  DateTime? createdAt;

  Task({
    this.idTask,
    this.employeeId,
    this.articleId,
    this.companyId,
    this.assignedBy,
    this.status,
    this.priority,
    this.assignedDate,
    this.startDate,
    this.completedDate,
    this.dueDate,
    this.notes,
    this.employeeNotes,
    this.estimatedDuration,
    this.actualDuration,
    this.collectionLatitude,
    this.collectionLongitude,
    this.lastUpdate,
    this.createdAt,
  });

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      idTask: map['idTask'] as int?,
      employeeId: map['employeeID'] as int?,
      articleId: map['articleID'] as int?,
      companyId: map['companyID'] as int?,
      assignedBy: map['assignedBy'] as int?,
      status: map['status'] as String?,
      priority: map['priority'] as String?,
      assignedDate: map['assignedDate'] != null 
          ? DateTime.parse(map['assignedDate']) 
          : null,
      startDate: map['startDate'] != null 
          ? DateTime.parse(map['startDate']) 
          : null,
      completedDate: map['completedDate'] != null 
          ? DateTime.parse(map['completedDate']) 
          : null,
      dueDate: map['dueDate'] != null 
          ? DateTime.parse(map['dueDate']) 
          : null,
      notes: map['notes'] as String?,
      employeeNotes: map['employeeNotes'] as String?,
      estimatedDuration: map['estimatedDuration'] as int?,
      actualDuration: map['actualDuration'] as int?,
      collectionLatitude: (map['collectionLatitude'] as num?)?.toDouble(),
      collectionLongitude: (map['collectionLongitude'] as num?)?.toDouble(),
      lastUpdate: map['lastUpdate'] != null 
          ? DateTime.parse(map['lastUpdate']) 
          : null,
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (employeeId != null) 'employeeID': employeeId,
      if (articleId != null) 'articleID': articleId,
      if (companyId != null) 'companyID': companyId,
      if (assignedBy != null) 'assignedBy': assignedBy,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (assignedDate != null) 'assignedDate': assignedDate!.toIso8601String(),
      if (startDate != null) 'startDate': startDate!.toIso8601String(),
      if (completedDate != null) 'completedDate': completedDate!.toIso8601String(),
      if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
      if (notes != null) 'notes': notes,
      if (employeeNotes != null) 'employeeNotes': employeeNotes,
      if (estimatedDuration != null) 'estimatedDuration': estimatedDuration,
      if (actualDuration != null) 'actualDuration': actualDuration,
      if (collectionLatitude != null) 'collectionLatitude': collectionLatitude,
      if (collectionLongitude != null) 'collectionLongitude': collectionLongitude,
    };
  }

  @override
  String toString() {
    return 'Task{idTask: $idTask, employeeId: $employeeId, articleId: $articleId, status: $status, priority: $priority}';
  }
}

/// ✅ Detailed task with joined data from related tables
class TaskDetailed {
  int idTask;
  String status;
  String? priority;
  DateTime? assignedDate;
  DateTime? startDate;
  DateTime? completedDate;
  DateTime? dueDate;
  String? notes;
  String? employeeNotes;
  int? estimatedDuration;
  int? actualDuration;
  
  // Employee info
  int employeeId;
  String employeeName;
  String employeeEmail;
  String? employeePhone;
  
  // Article info
  int articleId;
  String articleName;
  int? categoryId;
  String? articleCondition;
  String? articleDescription;
  
  // Article location
  String articleAddress;
  double articleLatitude;
  double articleLongitude;
  
  // Article owner info
  String articleOwnerName;
  String articleOwnerEmail;
  String? articleOwnerPhone;
  
  // Company info
  int companyId;
  String companyName;
  String? companyEmail;
  
  // Assigned by info
  String assignedByName;
  String assignedByEmail;

  TaskDetailed({
    required this.idTask,
    required this.status,
    this.priority,
    this.assignedDate,
    this.startDate,
    this.completedDate,
    this.dueDate,
    this.notes,
    this.employeeNotes,
    this.estimatedDuration,
    this.actualDuration,
    required this.employeeId,
    required this.employeeName,
    required this.employeeEmail,
    this.employeePhone,
    required this.articleId,
    required this.articleName,
    this.categoryId,
    this.articleCondition,
    this.articleDescription,
    required this.articleAddress,
    required this.articleLatitude,
    required this.articleLongitude,
    required this.articleOwnerName,
    required this.articleOwnerEmail,
    this.articleOwnerPhone,
    required this.companyId,
    required this.companyName,
    this.companyEmail,
    required this.assignedByName,
    required this.assignedByEmail,
  });

  factory TaskDetailed.fromMap(Map<String, dynamic> map) {
    return TaskDetailed(
      idTask: map['idtask'] as int,
      status: map['status'] as String,
      priority: map['priority'] as String?,
      assignedDate: map['assigneddate'] != null 
          ? DateTime.parse(map['assigneddate']) 
          : null,
      startDate: map['startdate'] != null 
          ? DateTime.parse(map['startdate']) 
          : null,
      completedDate: map['completeddate'] != null 
          ? DateTime.parse(map['completeddate']) 
          : null,
      dueDate: map['duedate'] != null 
          ? DateTime.parse(map['duedate']) 
          : null,
      notes: map['notes'] as String?,
      employeeNotes: map['employeenotes'] as String?,
      estimatedDuration: map['estimatedduration'] as int?,
      actualDuration: map['actualduration'] as int?,
      employeeId: map['idemployee'] as int,
      employeeName: map['employeename'] as String,
      employeeEmail: map['employeeemail'] as String,
      employeePhone: map['employeephone'] as String?,
      articleId: map['idarticle'] as int,
      articleName: map['articlename'] as String,
      categoryId: map['categoryid'] as int?,
      articleCondition: map['articlecondition'] as String?,
      articleDescription: map['articledescription'] as String?,
      articleAddress: map['articleaddress'] as String,
      articleLatitude: (map['articlelatitude'] as num).toDouble(),
      articleLongitude: (map['articlelongitude'] as num).toDouble(),
      articleOwnerName: map['articleownername'] as String,
      articleOwnerEmail: map['articleowneremail'] as String,
      articleOwnerPhone: map['articleownerphone'] as String?,
      companyId: map['idcompany'] as int,
      companyName: map['companyname'] as String,
      companyEmail: map['companyemail'] as String?,
      assignedByName: map['assignedbyname'] as String,
      assignedByEmail: map['assignedbyemail'] as String,
    );
  }

  @override
  String toString() {
    return 'TaskDetailed{idTask: $idTask, status: $status, articleName: $articleName, employeeName: $employeeName}';
  }
}
