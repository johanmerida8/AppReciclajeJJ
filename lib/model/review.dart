class Review {
  int? id;
  int? starId;
  int? articleId;
  int? senderId;
  int? receiverId;
  String? comment;
  int? state;

  Review({
    this.id,
    this.articleId,
    this.senderId,
    this.receiverId,
    this.starId,
    this.comment,
    this.state,
  });

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['idReview'] as int?,
      starId: map['starID'] as int?,
      articleId: map['articleID'] as int?,
      senderId: map['senderID'] as int?,
      receiverId: map['receiverID'] as int?,
      comment: map['comment'] as String?,
      state: map['state'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'starID': starId,
      'articleID': articleId,
      'senderID': senderId,
      'receiverID': receiverId,
      'comment': comment,
      'state': state,
    };
  }
}