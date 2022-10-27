import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class MyFS {
  static const String referer = "https://readmanganato.com/";

  static late Directory docDir;

  static init() async {
    docDir = await getApplicationDocumentsDirectory();
  }

  static String mangasFolder(String scraperID) {
    return join([docDir.path, 'mangas', scraperID]);
  }

  static Future<File> downloadMangaCover(String scraperID, String src, String img) async {
    var res = await http.get(Uri.parse(img));
    await Directory(join([mangasFolder(scraperID), src])).create(recursive: true);
    File file = File(join([mangasFolder(scraperID), src, 'cover.jpg']));
    return file.writeAsBytes(res.bodyBytes);
  }

  static Future<File> loadMangaCover(String scraperID, String src, String img) async {
    File file = File(join([mangasFolder(scraperID), src, 'cover.jpg']));
    if (file.existsSync()) {
      return file;
    }
    return downloadMangaCover(scraperID, src, img);
  }

  static Future<File> downloadChapterImages(
      String scraperID, String mangaSrc, String chapterSrc, int index, String img) async {
    var res = await http.get(
      Uri.parse(img),
      headers: {
        HttpHeaders.refererHeader: referer,
      },
    );
    await Directory(join([mangasFolder(scraperID), mangaSrc, chapterSrc]))
        .create(recursive: true);
    var idx = index.toString().padLeft(3, '0');
    File file = File(
        join([mangasFolder(scraperID), mangaSrc, chapterSrc, '$chapterSrc-$idx.jpg']));
    return file.writeAsBytes(res.bodyBytes);
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
