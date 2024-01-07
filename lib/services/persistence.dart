import 'dart:developer';
import 'dart:io';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:mangas/models/persistence.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String dbName = 'mangas.db';
  static const String _mgTable = 'mangas';
  static const String _mgID = 'id';
  static const String _mgTitle = 'title';
  static const String _mgImg = 'img';
  static const String _mgSrc = 'src';
  static const String _mgFolder = 'folder';
  static const String _mgScraperID = 'scraper_id';
  static const String _mgBookmarkedChapterID = 'bookmarked_chapter_id';
  static const String _mgLastChapterID = 'last_chapter_id';

  static const String _chTable = 'chapters';
  static const String _chID = 'id';
  static const String _chMangaID = 'manga_id';
  static const String _chTitle = 'title';
  static const String _chSrc = 'src';
  static const String _chFolder = 'folder';
  static const String _chDownloaded = 'downloaded';
  static const String _chUploadedAt = 'uploaded_at';
  static const String _chImgCnt = 'img_cnt';

  DatabaseHelper();

  DatabaseHelper._();

  static final DatabaseHelper db = DatabaseHelper._();
  static Database? _database;

  Future<Database?> get database async {
    if (_database != null) {
      return _database;
    }
    _database = await _initDb();

    return _database;
  }

  Future<bool> exportDatabase(String exportFile) async {
    return _copy(join(await getDatabasesPath(), dbName), exportFile);
  }

  Future<bool> importDatabase(String importFile) async {
    var ok = await _copy(importFile, join(await getDatabasesPath(), dbName));
    if (!ok) {
      return ok;
    }
    final db = await database;
    await db!.update(_chTable, {_chDownloaded: false, _chImgCnt: 0});
    
    return ok;
  }

  Future<bool> _copy(String source, String target) async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    var sourceFile = File(source);
    var targetFile = File(target);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    if (await Permission.accessMediaLocation.request().isGranted &&
        await Permission.manageExternalStorage.request().isGranted) {
      await sourceFile.copy(targetFile.path);
      return true;
    }
    return false;
  }

  _initDb() async {
    return openDatabase(
      join(await getDatabasesPath(), dbName),
      onCreate: (db, version) async {
        await db.execute(
          '''CREATE TABLE $_mgTable(
            $_mgID INTEGER PRIMARY KEY, 
            $_mgTitle TEXT NOT NULL, 
            $_mgImg TEXT, 
            $_mgSrc TEXT NOT NULL, 
            $_mgFolder TEXT NOT NULL,
            $_mgScraperID TEXT NOT NULL, 
            $_mgBookmarkedChapterID INTEGER, 
            $_mgLastChapterID INTEGER
          )''',
        );
        await db.execute(
          '''CREATE TABLE $_chTable(
            $_chMangaID INTEGER NOT NULL,
            $_chID INTEGER NOT NULL, 
            $_chTitle TEXT NOT NULL, 
            $_chSrc TEXT NOT NULL,
            $_chFolder TEXT NOT NULL,
            $_chDownloaded INTEGER, 
            $_chUploadedAt INTEGER,
            $_chImgCnt INTEGER,
            PRIMARY KEY ($_chMangaID, $_chID),
            FOREIGN KEY($_chMangaID) REFERENCES mangas($_mgID)
          )''',
        );
      },
      // Set  version. This executes the onCreate function and provides a
      // path  perform database upgrades and downgrades.
      version: 1,
    );
  }

  Future<int> insertManga(Manga manga) async {
    final db = await database;
    int id = 0;
    await db!.transaction((txn) async {
      id = await txn.insert(
        _mgTable,
        manga.toMap(),
      );
      var cnt = 0;
      for (var ch in manga.chapters) {
        ch.mangaID = id;
        ch.id = ++cnt;
        await txn.insert(
          _chTable,
          ch.toMap(),
        );
      }
    });
    return id;
  }

  updateManga(Manga manga) async {
    final db = await database;
    await db!.transaction((txn) async {
      await txn.update(
        _mgTable,
        manga.toMap(),
        where: '$_mgID = ?',
        whereArgs: [manga.id],
      );
      var maxID = 0;
      for (var ch in manga.chapters) {
        if (ch.isNew()) {
          maxID = ch.id;
          break;
        }
      }
      if (maxID != 0) {
        await txn.delete(_chTable,
          where: '$_chMangaID = ? AND $_chID >= ?',
          whereArgs: [manga.id, maxID],
        );
      }
      for (var ch in manga.chapters) {
        if (ch.isNew()) {
          ch.mangaID = manga.id;
          await txn.insert(
            _chTable,
            ch.toMap(),
          );
        } else if (ch.isDirty()) {
          await txn.update(
            _chTable,
            ch.toMap(),
            where: '$_chMangaID = ? AND $_chID = ?',
            whereArgs: [ch.mangaID, ch.id],
          );
        }
      }
    });
  }

  Future<void> deleteManga(int mangaID) async {
    final db = await database;
    await db!.transaction((txn) async {
      txn.delete(
        _chTable,
        where: '$_chMangaID = ?',
        whereArgs: [mangaID],
      );
      txn.delete(
        _mgTable,
        where: '$_mgID = ?',
        whereArgs: [mangaID],
      );
    });
  }

  Future<Manga?> getManga(int id) async {
    final db = await database;
    var mangas =
        await db!.query(_mgTable, where: '$_mgID = ?', whereArgs: [id]);
    if (mangas.isEmpty) {
      return null;
    }
    var chapters = await db.query(_chTable,
        where: '$_chMangaID = ?', whereArgs: [id], orderBy: '$_chID ASC');
    return _toManga(mangas.first, chapters);
  }

  Future<List<Manga>> getMangas() async {
    final db = await database;
    var res = await db!.query(_mgTable);
    if (res.isEmpty) {
      return [];
    }
    List<Manga> mangas = [];
    for (var r in res) {
      var chapters = await db.query(_chTable,
          where: '$_chMangaID = ?',
          whereArgs: [r[_mgID]],
          orderBy: '$_chID ASC');
      mangas.add(_toManga(r, chapters));
    }
    return mangas;
  }

  Future<List<MangaView>> getMangaReadingOrder(bool sortByName) async {
    final db = await database;
    List<MangaView> mangas = [];

    if (sortByName) {
      // final List<Map<String, Object?>> read = await db!.rawQuery('''SELECT m.*, c.$_chTitle AS bm_title, c.$_chTitle AS last_title, c.$_chUploadedAt,
      //   (SELECT COUNT(*) FROM $_chTable cc WHERE cc.$_chMangaID = m.$_mgID AND cc.$_chID >= m.$_mgBookmarkedChapterID AND cc.$_chDownloaded = FALSE) AS to_download,
      //   (SELECT c.$_chTitle FROM $_chTable c WHERE c.$_chMangaID = m.$_mgID AND c.$_chID = m.$_mgBookmarkedChapterID)  AS bm_title,
      //   (SELECT c.$_chTitle FROM $_chTable c WHERE c.$_chMangaID = m.$_mgID AND c.$_chID = m.$_mgLastChapterID)  AS last_title,
      //      FROM $_mgTable m
      //      LEFT JOIN $_chTable c ON c.$_chMangaID = m.$_mgID
      //      ORDER BY m.$_mgTitle ASC''');
      final List<Map<String, Object?>> recs = await db!.rawQuery('''SELECT m.*, v.$_chTitle AS bm_title, c.$_chTitle AS last_title, c.$_chUploadedAt, 
        (SELECT COUNT(*) FROM $_chTable cc WHERE cc.$_chMangaID = m.$_mgID AND cc.$_chID >= m.$_mgBookmarkedChapterID AND cc.$_chDownloaded = FALSE) AS to_download
           FROM $_mgTable m
           LEFT JOIN $_chTable v ON v.$_chMangaID = m.$_mgID AND v.$_chID = m.$_mgBookmarkedChapterID
           LEFT JOIN $_chTable c ON c.$_chMangaID = m.$_mgID AND c.$_chID = m.$_mgLastChapterID
           ORDER BY m.$_mgTitle ASC''');
      for (var e in recs) {
        mangas.add(_toMangaView(e));
      }
      return mangas;
    }

    final List<Map<String, Object?>> unread = await db!.rawQuery('''SELECT m.*, v.$_chTitle AS bm_title, c.$_chTitle AS last_title, c.$_chUploadedAt, 
        (SELECT COUNT(*) FROM $_chTable cc WHERE cc.$_chMangaID = m.$_mgID AND cc.$_chID >= m.$_mgBookmarkedChapterID AND cc.$_chDownloaded = FALSE) AS to_download
           FROM $_mgTable m
           LEFT JOIN $_chTable v ON v.$_chMangaID = m.$_mgID AND v.$_chID = m.$_mgBookmarkedChapterID
           LEFT JOIN $_chTable c ON c.$_chMangaID = m.$_mgID AND c.$_chID = m.$_mgLastChapterID
           WHERE m.$_mgBookmarkedChapterID <> m.$_mgLastChapterID
           ORDER BY c.$_chUploadedAt DESC''');
    for (var e in unread) {
      mangas.add(_toMangaView(e));
    }

    final List<Map<String, Object?>> read = await db.rawQuery('''SELECT m.*, c.$_chTitle AS bm_title, c.$_chTitle AS last_title, c.$_chUploadedAt,
        (SELECT COUNT(*) FROM $_chTable cc WHERE cc.$_chMangaID = m.$_mgID AND cc.$_chID >= m.$_mgBookmarkedChapterID AND cc.$_chDownloaded = FALSE) AS to_download
           FROM $_mgTable m
           LEFT JOIN $_chTable c ON c.$_chMangaID = m.$_mgID AND c.$_chID = m.$_mgLastChapterID
           WHERE m.$_mgBookmarkedChapterID = m.$_mgLastChapterID
           ORDER BY c.$_chUploadedAt DESC''');
    for (var e in read) {
      mangas.add(_toMangaView(e));
    }
    return mangas;
  }

  Future<List<String>> getMangaSources() async {
    final db = await database;
    List<String> sources = [];
    final List<Map<String, Object?>> unread =
        await db!.rawQuery('SELECT m.$_mgSrc FROM $_mgTable m');
    for (var e in unread) {
      sources.add(e[_mgSrc].toString());
    }
    return sources;
  }

  Manga _toManga(Map<String, Object?> m, List<Map<String, Object?>> chs) {
    List<Chapter> chapters = [];
    for (var c in chs) {
      chapters.add(_toChapter(c));
    }

    return Manga.hydrate(
      id: m[_mgID] as int,
      title: m[_mgTitle].toString(),
      img: m[_mgImg].toString(),
      src: m[_mgSrc].toString(),
      folder: m[_mgFolder].toString(),
      scraperID: m[_mgScraperID].toString(),
      bookmarkedChapterID: m[_mgBookmarkedChapterID] as int,
      lastChapterID: m[_mgLastChapterID] as int,
      chapters: chapters,
    );
  }

  Chapter _toChapter(Map<String, Object?> e) {
    int ms = e[_chUploadedAt] as int;
    var at = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return Chapter(
      id: e[_chID] as int,
      mangaID: e[_chMangaID] as int,
      title: e[_chTitle].toString(),
      src: e[_mgSrc].toString(),
      folder: e[_chFolder].toString(),
      uploadedAt: at,
      downloaded: e[_chDownloaded] as int == 1,
      imgCnt: e[_chImgCnt] as int,
    );
  }

  MangaView _toMangaView(Map<String, Object?> e) {
    int ms = e[_chUploadedAt] as int;
    var at = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return MangaView(
      id: e[_mgID] as int,
      title: e[_mgTitle].toString(),
      img: e[_mgImg].toString(),
      src: e[_mgSrc].toString(),
      folder: e[_mgFolder].toString(),
      scraperID: e[_mgScraperID].toString(),
      bookmarkedChapter: e['bm_title']?.toString() ?? '',
      lastChapter: e['last_title']?.toString() ?? '',
      lastUploadedAt: at,
      missingDownloads: e['to_download'] as int,
    );
  }
}
