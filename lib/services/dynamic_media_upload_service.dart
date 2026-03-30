import 'package:dynamic_photo_chat_flutter/models/dynamic_media_pick_result.dart';
import 'package:dynamic_photo_chat_flutter/models/file_upload_response.dart';
import 'package:dynamic_photo_chat_flutter/services/file_service.dart';

class DynamicMediaUploadService {
  const DynamicMediaUploadService(this._files);

  final FileService _files;

  Future<FileUploadResponse> upload({
    required DynamicMediaPickResult pickResult,
    required int userId,
  }) async {
    switch (pickResult.uploadMode) {
      case DynamicMediaUploadMode.livePhotoPair:
        final videoPath = pickResult.videoPath;
        if (videoPath == null || videoPath.trim().isEmpty) {
          throw Exception('Live Photo pair is missing the video path.');
        }
        return _files.uploadLivePhotoAuto(
          jpegPath: pickResult.coverPath,
          movPath: videoPath,
          userId: userId,
        );
      case DynamicMediaUploadMode.motionPhotoFile:
        return _files.uploadMotionPhotoFromPath(
          filePath: pickResult.coverPath,
          userId: userId,
        );
    }
  }
}
