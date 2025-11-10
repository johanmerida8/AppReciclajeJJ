class Multimedia {
  int? id;
  String? url;
  String? fileName;
  String? filePath;
  int? fileSize;
  String? mimeType;
  bool isMain;
  int uploadOrder;
  String? entityType;
  int? entityId;

  Multimedia({
    this.id,
    this.url,
    this.fileName,
    this.filePath,
    this.fileSize,
    this.mimeType,
    this.isMain = false,
    this.uploadOrder = 0,
    this.entityType,
    this.entityId,
  });

  factory Multimedia.fromMap(Map<String, dynamic> map) {
    return Multimedia(
      id: map['idMultimedia'] as int?,
      url: map['url'] as String?,
      fileName: map['fileName'] as String?,
      filePath: map['filePath'] as String?,
      fileSize: map['fileSize'] as int?,
      mimeType: map['mimeType'] as String?,
      isMain: map['isMain'] as bool? ?? false,
      uploadOrder: map['uploadOrder'] as int? ?? 0,
      entityType: map['entityType'] as String?,
      entityId: map['entityID'] as int?
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'fileName': fileName,
      'filePath': filePath,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'isMain': isMain,
      'uploadOrder': uploadOrder,
      'entityType': entityType,
      'entityID': entityId,
    };
  }

  @override
  String toString() {
    return 'Photo{id: $id, url: $url, fileName: $fileName, filePath: $filePath, fileSize: $fileSize, mimeType: $mimeType, isMain: $isMain, uploadOrder: $uploadOrder, entityType: $entityType, entityID: $entityId}';
  }
}