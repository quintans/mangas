import 'package:mangas/models/remote.dart';

class Manga {
  final int id;
  final String title;
  final String img;
  final String src;
  final String scraperID;
  int bookmarkedChapterID;
  int lastChapterID;
  final List<Chapter> chapters;

  String folder;

  Manga({
    required this.id,
    required this.title,
    required this.img,
    required this.src,
    required this.scraperID,
    required this.bookmarkedChapterID,
    required this.lastChapterID,
    required this.chapters,
    required this.folder,
  }) {
    for (var i = 0; i < chapters.length; i++) {
      chapters[i].id = i + 1;
    }
    if (chapters.isNotEmpty) {
      lastChapterID = chapters.length;
    }
  }

  Manga.hydrate({
    required this.id,
    required this.title,
    required this.img,
    required this.src,
    required this.scraperID,
    required this.bookmarkedChapterID,
    required this.lastChapterID,
    required this.chapters,
    required this.folder,
  });

  Map<String, Object?> toMap() {
    var m = {
      'title': title,
      'img': img,
      'src': src,
      'folder': folder,
      'scraper_id': scraperID,
      'bookmarked_chapter_id': bookmarkedChapterID,
      'last_chapter_id': lastChapterID,
    };
    if (id != 0) {
      m['id'] = id;
    }
    return m;
  }

  upsertChapter(ChapterResult r) {
    // update if it already exists
    for (var c in chapters) {
      if (c.title == r.title) {
        c.updateIfNotDownloaded(r);
        return;
      }
    }

    var ch = Chapter(
      id: chapters.length + 1,
      mangaID: 0,
      title: r.title,
      src: r.src,
      uploadedAt: r.uploadedAt,
      downloaded: false,
      imgCnt: 0,
      folder: r.folder,
    );

    lastChapterID = ch.id;
    chapters.add(ch);
  }

  Chapter getBookmarkedChapter() {
    return chapters[bookmarkedChapterID - 1];
  }

  List<Chapter> getChaptersToDownload() {
    List<Chapter> chs = [];
    for (var i = bookmarkedChapterID - 1; i < chapters.length; i++) {
      if (!chapters[i].downloaded) {
        chs.add(chapters[i]);
      }
    }
    return chs;
  }

  List<Chapter> getChaptersToDiscard() {
    List<Chapter> chs = [];
    for (var i = 0; i < bookmarkedChapterID - 1; i++) {
      if (chapters[i].downloaded) {
        chs.add(chapters[i]);
      }
    }
    return chs;
  }

  List<Chapter> getChapters() {
    return chapters;
  }

  bool hasPreviousChapter(Chapter chapter) {
    return chapter.id > 1 && chapters[chapter.id - 2].downloaded;
  }

  Chapter moveToPreviousChapter(Chapter chapter) {
    if (hasPreviousChapter(chapter)) {
      var ch = chapters[chapter.id - 2];
      bookmarkedChapterID = ch.id;
      return ch;
    }
    return chapter;
  }

  bool hasNextChapter(Chapter chapter) {
    return chapters.length > chapter.id && chapters[chapter.id].downloaded;
  }

  Chapter moveToNextChapter(Chapter chapter) {
    if (hasNextChapter(chapter)) {
      var ch = chapters[chapter.id];
      bookmarkedChapterID = ch.id;
      return ch;
    }
    return chapter;
  }

  bookmark(Chapter chapter) {
    bookmarkedChapterID = chapter.id;
  }

  bool isBookmarked(Chapter chapter) {
    return bookmarkedChapterID == chapter.id;
  }
}

class Chapter {
  static const int _unpersistedID = 0;

  int id;
  int mangaID;
  final String title;
  String src;
  DateTime uploadedAt;
  bool downloaded = false;
  int imgCnt = 0;
  bool _dirty = false;

  String? _folder;
  String get folder => _folder!;
  set folder(String folder) {
    _folder = folder;
    _dirty = true;
  }

  Chapter({
    required this.id,
    required this.mangaID,
    required this.title,
    required this.src,
    required this.uploadedAt,
    required this.downloaded,
    required this.imgCnt,
    required folder,
  }) {
    _folder = folder;
  }


  Map<String, Object?> toMap() {
    return {
      'manga_id': mangaID,
      'id': id,
      'title': title,
      'src': src,
      'folder': folder,
      'downloaded': downloaded ? 1 : 0,
      'img_cnt': imgCnt,
      'uploaded_at': uploadedAt.millisecondsSinceEpoch,
    };
  }

  bool isDownloaded() {
    return downloaded;
  }

  bool isNew() {
    return mangaID == _unpersistedID;
  }

  bool isDirty() {
    return _dirty;
  }

  void markDownloaded(int count) {
    downloaded = true;
    imgCnt = count;
    _dirty = true;
  }

  void discarded() {
    downloaded = false;
    imgCnt = 0;
    _dirty = true;
  }

  void updateIfNotDownloaded(ChapterResult r) {
    if (downloaded) {
      return;
    }

    src = r.src;
    uploadedAt = r.uploadedAt;
    folder = r.folder;

    _dirty = true;
  }

}

class MangaView {
  final int id;
  final String title;
  final String img;
  final String src;
  final String scraperID;
  String bookmarkedChapter;
  final String lastChapter;
  final DateTime lastUploadedAt;
  final int missingDownloads;

  final String _folder;
  String get folder => _folder;

  MangaView({
    required this.id,
    required this.title,
    required this.img,
    required this.src,
    required this.scraperID,
    required this.bookmarkedChapter,
    required this.lastChapter,
    required this.lastUploadedAt,
    required this.missingDownloads,
    required folder,
  }) :
        _folder = folder;

}
