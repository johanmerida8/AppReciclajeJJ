class Task {
  int? idTask;
  int? employeeId;
  int? articleId;
  int? companyId;
  int? requestId;
  DateTime? assignedDate;
  String? workflowStatus; // 'asignado', 'en_proceso', 'completado', 'cancelado'
  int? state; // 1 = active, 0 = deleted
  DateTime? lastUpdate;

  Task({
    this.idTask,
    this.employeeId,
    this.articleId,
    this.companyId,
    this.requestId,
    this.assignedDate,
    this.workflowStatus,
    this.state,
    this.lastUpdate,
  });

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      idTask: map['idTask'] as int?,
      employeeId: map['employeeID'] as int?,
      articleId: map['articleID'] as int?,
      companyId: map['companyID'] as int?,
      requestId: map['requestID'] as int?,
      assignedDate: map['assignedDate'] != null 
          ? DateTime.parse(map['assignedDate']) 
          : null,
      workflowStatus: map['workflowStatus'] as String?,
      state: map['state'] as int?,
      lastUpdate: map['lastUpdate'] != null 
          ? DateTime.parse(map['lastUpdate']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (employeeId != null) 'employeeID': employeeId,
      if (articleId != null) 'articleID': articleId,
      if (companyId != null) 'companyID': companyId,
      if (requestId != null) 'requestID': requestId,
      if (assignedDate != null) 'assignedDate': assignedDate!.toIso8601String(),
      if (workflowStatus != null) 'workflowStatus': workflowStatus,
      if (state != null) 'state': state,
      if (lastUpdate != null) 'lastUpdate': lastUpdate!.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Task{idTask: $idTask, employeeId: $employeeId, articleId: $articleId, companyId: $companyId, requestId: $requestId, workflowStatus: $workflowStatus, state: $state}';
  }
}

/// ✅ Detailed task with joined data from related tables (for display purposes)
// class TaskDetailed {
//   int idTask;
//   int employeeId;
//   int articleId;
//   int companyId;
//   int requestId;
//   DateTime? assignedDate;
//   String workflowStatus;
  
//   // Employee info
//   String employeeName;
//   String employeeEmail;
  
//   // Article info
//   String articleName;
//   String? articleCondition;
//   String? articleDescription;
//   String articleAddress;
//   double articleLatitude;
//   double articleLongitude;
  
//   // Article owner info
//   String articleOwnerName;
//   String articleOwnerEmail;
  
//   // Company info
//   String companyName;
  
//   // Request schedule info
//   String? scheduledDay;
//   String? scheduledTime;

//   TaskDetailed({
//     required this.idTask,
//     required this.employeeId,
//     required this.articleId,
//     required this.companyId,
//     required this.requestId,
//     this.assignedDate,
//     required this.workflowStatus,
//     required this.employeeName,
//     required this.employeeEmail,
//     required this.articleName,
//     this.articleCondition,
//     this.articleDescription,
//     required this.articleAddress,
//     required this.articleLatitude,
//     required this.articleLongitude,
//     required this.articleOwnerName,
//     required this.articleOwnerEmail,
//     required this.companyName,
//     this.scheduledDay,
//     this.scheduledTime,
//   });

//   factory TaskDetailed.fromMap(Map<String, dynamic> map) {
//     return TaskDetailed(
//       idTask: map['idTask'] as int,
//       employeeId: map['employeeID'] as int,
//       articleId: map['articleID'] as int,
//       companyId: map['companyID'] as int,
//       requestId: map['requestID'] as int,
//       assignedDate: map['assignedDate'] != null 
//           ? DateTime.parse(map['assignedDate']) 
//           : null,
//       workflowStatus: map['workflowStatus'] as String,
//       employeeName: map['employeeName'] as String,
//       employeeEmail: map['employeeEmail'] as String,
//       articleName: map['articleName'] as String,
//       articleCondition: map['articleCondition'] as String?,
//       articleDescription: map['articleDescription'] as String?,
//       articleAddress: map['articleAddress'] as String,
//       articleLatitude: (map['articleLatitude'] as num).toDouble(),
//       articleLongitude: (map['articleLongitude'] as num).toDouble(),
//       articleOwnerName: map['articleOwnerName'] as String,
//       articleOwnerEmail: map['articleOwnerEmail'] as String,
//       companyName: map['companyName'] as String,
//       scheduledDay: map['scheduledDay'] as String?,
//       scheduledTime: map['scheduledTime'] as String?,
//     );
//   }

//   @override
//   String toString() {
//     return 'TaskDetailed{idTask: $idTask, workflowStatus: $workflowStatus, articleName: $articleName, employeeName: $employeeName, scheduledDay: $scheduledDay, scheduledTime: $scheduledTime}';
//   }
// }
