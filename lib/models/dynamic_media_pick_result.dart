enum DynamicMediaUploadMode {
  livePhotoPair,
  motionPhotoFile,
}

class DynamicMediaPickResult {
  const DynamicMediaPickResult({
    required this.coverPath,
    required this.uploadMode,
    required this.sourceType,
    this.videoPath,
  });

  final String coverPath;
  final String? videoPath;
  final DynamicMediaUploadMode uploadMode;
  final String sourceType;

  bool get isPairedUpload => uploadMode == DynamicMediaUploadMode.livePhotoPair;
}
