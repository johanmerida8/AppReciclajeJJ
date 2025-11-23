class Request {
  int? id;
  int? articleId;
  int? companyId;
  String? status;
  DateTime? requestDate;
  int? state;
  DateTime? lastUpdate;
  String? scheduledDay; // ✅ Selected pickup day
  String? scheduledStartTime; // ✅ Window start time (HH:MM:SS format)
  String? scheduledEndTime; // ✅ Window end time (HH:MM:SS format)

  Request({
    this.id,
    this.articleId,
    this.companyId,
    this.status,
    this.requestDate,
    this.state,
    this.lastUpdate,
    this.scheduledDay,
    this.scheduledStartTime,
    this.scheduledEndTime,
  });

  factory Request.fromMap(Map<String, dynamic> map ) {
    return Request(
      id: map['idRequest'] as int,
      articleId: map['articleID'] as int,
      companyId: map['companyID'] as int,
      status: map['status'] as String,
      requestDate: map['requestDate'] != null ? DateTime.parse(map['requestDate']) : null,
      state: map['state'] as int,
      lastUpdate: map['lastUpdate'] != null ? DateTime.parse(map['lastUpdate']) : null,
      scheduledDay: map['scheduledDay'] as String?,
      scheduledStartTime: map['scheduledStartTime'] as String?,
      scheduledEndTime: map['scheduledEndTime'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'articleID': articleId,
      'companyID': companyId,
      'status': status,
      'requestDate': requestDate?.toIso8601String(),
      'state': state,
      'lastUpdate': lastUpdate?.toIso8601String(),
      'scheduledDay': scheduledDay,
      'scheduledStartTime': scheduledStartTime,
      'scheduledEndTime': scheduledEndTime,
    };
  }

  @override
  String toString() {
    return 'Request{id: $id, articleID: $articleId, companyID: $companyId, status: $status, requestDate: $requestDate, state: $state, lastUpdate: $lastUpdate, scheduledDay: $scheduledDay, scheduledStartTime: $scheduledStartTime, scheduledEndTime: $scheduledEndTime}';
  }
}