import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class MyFS {
  static const String referer = "https://readmanganato.com/";

  static late Directory docDir;

  static init() async {
    docDir = await getApplicationDocumentsDirectory();
  }

  static String mangasFolder() {
    return join([docDir.path, 'mangas', 'manganato']);
  }

  static Future<File> downloadMangaCover(String src, String img) async {
    var res = await http.get(Uri.parse(img));
    await Directory(join([mangasFolder(), src])).create(recursive: true);
    File file = File(join([mangasFolder(), src, 'cover.png']));
    return file.writeAsBytes(res.bodyBytes);
  }

  static Future<File> loadMangaCover(String src, String img) async {
    File file = File(join([mangasFolder(), src, 'cover.png']));
    if (file.existsSync()) {
      return file;
    }
    return downloadMangaCover(src, img);
  }

  static Future<File> downloadChapterImage(
      String mangaSrc, String chapterSrc, int index, String img) async {
    var res = await http.get(
      Uri.parse(img),
      headers: {
        HttpHeaders.refererHeader: referer,
      },
    );
    await Directory(join([mangasFolder(), mangaSrc, chapterSrc]))
        .create(recursive: true);
    var idx = index.toString().padLeft(3, '0');
    File file = File(
        join([mangasFolder(), mangaSrc, chapterSrc, '$chapterSrc-$idx']));
    return file.writeAsBytes(res.bodyBytes);
  }

  static Future<File> loadChapterImage(
      String mangaSrc, String chapterSrc, int index) async {
    var idx = index.toString().padLeft(3, '0');
    File file = File(
        join([mangasFolder(), mangaSrc, chapterSrc, '$chapterSrc-$idx']));
    if (file.existsSync()) {
      return file;
    }
    throw Exception('$file not found');
  }

  static deleteManga(String mangaSrc) {
    Directory(join([mangasFolder(), mangaSrc])).deleteSync(recursive: true);
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