import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

class MyFS {
  static late Directory docDir;

  static init() async {
    docDir = await getApplicationDocumentsDirectory();
  }

  static String mangasFolder(String scraperID) {
    return join([docDir.path, 'mangas', scraperID]);
  }

  static Future<File> downloadMangaCover(Dio dioClient, String scraperID, String src, String img) async {
    await Directory(join([mangasFolder(scraperID), src])).create(recursive: true);
    File file = File(join([mangasFolder(scraperID), src, 'cover.jpg']));

    await dioClient.download(
      img,
      file.path,
    );
    return file;
  }

  static Future<File> loadMangaCover(Dio dioClient, String scraperID, String src, String img) async {
    File file = File(join([mangasFolder(scraperID), src, 'cover.jpg']));
    if (file.existsSync()) {
      return file;
    }
    var fileDwn = await downloadMangaCover(dioClient, scraperID, src, img);
    return fileDwn;
  }

  static Future downloadChapterImages (
      Dio dioClient,
      String scraperID,
      String mangaSrc,
      String chapterSrc,
      int index,
      String img,
      Map<String, String>? headers
      ) async {
    await Directory(join([mangasFolder(scraperID), mangaSrc, chapterSrc]))
        .create(recursive: true);
    var idx = index.toString().padLeft(3, '0');
    File file = File(
        join([mangasFolder(scraperID), mangaSrc, chapterSrc, '$chapterSrc-$idx.jpg']));
    for (var retry = 0; retry < 1; retry++) {
      try {
        await dioClient.download(
          img,
          file.path,
          options: Options(
            headers: headers,
          ),
        );
      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionTimeout) {
          continue;
        }
        if (e.type == DioExceptionType.receiveTimeout) {
          throw TimeoutException("failed downloading");
        }
      }
      return;
    }
  }

  static File loadChapterImage(
      String scraperID, String mangaSrc, String chapterSrc, int index) {
    var idx = index.toString().padLeft(3, '0');
    File file = File(
        join([mangasFolder(scraperID), mangaSrc, chapterSrc, '$chapterSrc-$idx.jpg']));
    if (file.existsSync()) {
      return file;
    }
    throw Exception('$file not found');
  }

  static deleteMangas() {
    var dir = Directory(join([docDir.path, 'mangas']));
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  static deleteManga(String scraperID, String mangaSrc) {
    var dir = Directory(join([mangasFolder(scraperID), mangaSrc]));
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  static deleteChapter(String scraperID, String mangaSrc, String chapterSrc) {
    var dir = Directory(join([mangasFolder(scraperID), mangaSrc, chapterSrc]));
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  static String join(List<String> parts) {
    var buffer = StringBuffer(parts[0]);
    for (var i = 1; i < parts.length; i++) {
      var s0 = parts[i - 1];
      var s1 = parts[i];
      if (!s0.endsWith(Platform.pathSeparator) &&
          !s1.startsWith(Platform.pathSeparator)) {
        buffer.write(Platform.pathSeparator);
      }
      buffer.write(s1);
    }
    return buffer.toString();
  }
}
