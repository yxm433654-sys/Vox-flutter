import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DownloadResult {
  DownloadResult({required this.file, required this.bytes});
  final File file;
  final int bytes;
}

class MediaDownloader {
  static String _stableKeyFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final noQuery = (uri == null)
        ? url
        : uri.replace(query: null, fragment: null).toString();
    final b64 = base64Url.encode(utf8.encode(noQuery));
    // 文件名不要太长
    return b64.length > 64 ? b64.substring(0, 64) : b64;
  }

  static Future<Directory> _cacheDir() async {
    final base = await getApplicationCacheDirectory();
    final dir = Directory('${base.path}/media_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<void> clearCache() async {
    final dir = await _cacheDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  static Future<DownloadResult> downloadToCacheFile({
    required String url,
    required String extensionHint,
    required void Function(int received, int? total) onProgress,
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    try {
      final dir = await _cacheDir();
      final key = _stableKeyFromUrl(url);
      final ext = extensionHint.startsWith('.') ? extensionHint : '.$extensionHint';
      final out = File('${dir.path}/$key$ext');
      if (await out.exists()) {
        // 直接复用，避免重复下载
        final len = await out.length();
        onProgress(len, len);
        return DownloadResult(file: out, bytes: len);
      }

      final req = http.Request('GET', Uri.parse(url));
      final res = await c.send(req);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('下载失败: HTTP ${res.statusCode}');
      }

      final len = res.contentLength;
      final total = (len != null && len > 0) ? len : null;
      final sink = out.openWrite();
      var received = 0;
      try {
        await for (final chunk in res.stream) {
          received += chunk.length;
          sink.add(chunk);
          onProgress(received, total);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      return DownloadResult(file: out, bytes: received);
    } finally {
      if (client == null) {
        c.close();
      }
    }
  }
}

