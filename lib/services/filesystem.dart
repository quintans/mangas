import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class MyFS {
  static const String referer = "https://readmanganato.com/";

  static late Directory docDir;

  static init() async {
    docDir = await getApplicationDocumentsDirectory();
  }

  static String mangasFolder(String providerID) {
    return join([docDir.path, 'mangas', providerID]);
  }

  static Future<File> downloadMangaCover(String providerID, String src, String img) async {
    var res = await http.get(Uri.parse(img));
    await Directory(join([mangasFolder(providerID), src])).create(recursive: true);
    File file = File(join([mangasFolder(providerID), src, 'cover.png']));
    return file.writeAsBytes(res.bodyBytes);
  }

  static Future<File> loadMangaCover(String providerID, String src, String img) async {
    File file = File(join([mangasFolder(providerID), src, 'cover.png']));
    if (file.existsSync()) {
      return file;
    }
    return downloadMangaCover(providerID, src, img);
  }

  static Future<File> downloadChapterImages(
      String providerID, String mangaSrc, String chapterSrc, int index, String img) async {
    var res = await http.get(
      Uri.parse(img),
      headers: {
        HttpHeaders.refererHeader: referer,
      },
    );
    await Directory(join([mangasFolder(providerID), mangaSrc, chapterSrc]))
        .create(recursive: true);
    var idx = index.toString().padLeft(3, '0');
    File file = File(
        join([mangasFolder(providerID), mangaSrc, chapterSrc, '$chapterSrc-$idx']));
    return file.writeAsBytes(res.bodyBytes);
  }

  static File loadChapterImage(
      String providerID, String mangaSrc, String chapterSrc, int index) {
    var idx = index.toString().padLeft(3, '0');
    File file = File(
        join([mangasFolder(providerID), mangaSrc, chapterSrc, '$chapterSrc-$idx']));
    if (file.existsSync()) {
      return file;
    }
    throw Exception('$file not found');
  }

  static deleteManga(String providerID, String mangaSrc) {
    var dir = Directory(join([mangasFolder(providerID), mangaSrc]));
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  static deleteChapter(String providerID, String mangaSrc, String chapterSrc) {
    var dir = Directory(join([mangasFolder(providerID), mangaSrc, chapterSrc]));
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
