class Photo {
  int? id;
  int? articleID;
  String? url;
  String? fileName;
  String? filePath;
  int? fileSize;
  String? mimeType;
  bool isMain;
  int uploadOrder;
  // DateTime? lastUpdate;

  Photo({
    this.id,
    this.articleID,
    this.url,
    this.fileName,
    this.filePath,
    this.fileSize,
    this.mimeType,
    this.isMain = false,
    this.uploadOrder = 0,
    // this.lastUpdate,
  });

  factory Photo.fromMap(Map<String, dynamic> map) {
    return Photo(
      id: map['idPhoto'] as int?,
      articleID: map['article_id'] as int?,
      url: map['url'] as String?,
      fileName: map['fileName'] as String?,
      filePath: map['filePath'] as String?,
      fileSize: map['fileSize'] as int?,
      mimeType: map['mimeType'] as String?,
      isMain: map['isMain'] as bool? ?? false,
      uploadOrder: map['uploadOrder'] as int? ?? 0,
      // lastUpdate: map['lastUpdate'] != null ? DateTime.parse(map['lastUpdate']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'article_id': articleID,
      'url': url,
      'fileName': fileName,
      'filePath': filePath,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'isMain': isMain,
      'uploadOrder': uploadOrder,
      // 'lastUpdate': lastUpdate?.toIso8601String(),
    };
  }

  //helper methods for state management
  // bool get isActive => state == 1;
  // bool get isDeleted => state == 0;

  // void markAsDeleted() {
  //   state = 0;
  //   lastUpdate = DateTime.now();
  // }

  // void markAsActive() {
  //   state = 1;
  //   lastUpdate = DateTime.now();
  // }

  @override
  String toString() {
    return 'Photo{id: $id, articleID: $articleID, url: $url, fileName: $fileName, filePath: $filePath, fileSize: $fileSize, mimeType: $mimeType, isMain: $isMain, uploadOrder: $uploadOrder}';
  }
}