import 'dart:io';

import 'package:dynamic_photo_chat_flutter/utils/media_downloader.dart';
import 'package:photo_manager/photo_manager.dart';

class MediaSaver {
  static Future<void> saveImageFromUrl(String url, {String? title}) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      throw Exception('Please allow photo library access first.');
    }
    final downloaded = await MediaDownloader.downloadToCacheFile(
      url: url,
      extensionHint: 'jpg',
      onProgress: (_, __) {},
    );
    await PhotoManager.editor.saveImageWithPath(
      downloaded.file.path,
      title: title,
    );
  }

  static Future<void> saveVideoFromUrl(String url, {String? title}) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      throw Exception('Please allow photo library access first.');
    }
    final downloaded = await MediaDownloader.downloadToCacheFile(
      url: url,
      extensionHint: 'mp4',
      onProgress: (_, __) {},
    );
    await PhotoManager.editor.saveVideo(
      File(downloaded.file.path),
      title: title,
    );
  }
}
