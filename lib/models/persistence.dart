class Manga {
  final int id;
  final String title;
  final String img;
  final String src;
  int viewedChapterID;
  int lastChapterID;
  final List<Chapter> chapters;

  Manga({
    required this.id,
    required this.title,
    required this.img,
    required this.src,
    required this.viewedChapterID,
    required this.lastChapterID,
    required this.chapters,
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
    required this.viewedChapterID,
    required this.lastChapterID,
    required this.chapters,
  });

  Map<String, Object?> toMap() {
    var m = {
      'title': title,
      'img': img,
      'src': src,
      'viewed_chapter_id': viewedChapterID,
      'last_chapter_id': lastChapterID,
    };
    if (id != 0) {
      m['id'] = id;
    }
    return m;
  }

  addChapter(Chapter ch) {
    // check if it already exists
    for (var c in chapters) {
      if (c.src == ch.src) {
        return;
      }
    }
    ch.id = chapters.length + 1;
    lastChapterID = ch.id;
    chapters.add(ch);
  }

  Chapter? getBookmarkedChapter() {
    if (viewedChapterID <= 0) {
      return null;
    }
    return chapters[viewedChapterID - 1];
  }

  List<Chapter> getChaptersToDownload() {
    List<Chapter> chs = [];
    for (var i = viewedChapterID - 1; i < chapters.length; i++) {
      if (!chapters[i].downloaded) {
        chs.add(chapters[i]);
      }
    }
    return chs;
  }

  List<Chapter> getChaptersToDiscard() {
    List<Chapter> chs = [];
    for (var i = 0; i < viewedChapterID - 1; i++) {
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
      viewedChapterID = ch.id;
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
      viewedChapterID = ch.id;
      return ch;
    }
    return chapter;
  }

  bookmark(Chapter chapter) {
    viewedChapterID = chapter.id;
  }

  bool isBookmarked(Chapter chapter) {
    return viewedChapterID == chapter.id;
  }
}

class Chapter {
  static const int _unpersistedID = 0;

  int id;
  int mangaID;
  final String title;
  final String src;
  final DateTime uploadedAt;
  bool downloaded = false;
  int imgCnt = 0;
  bool _dirty = false;

  Chapter({
    required this.id,
    required this.mangaID,
    required this.title,
    required this.src,
    required this.uploadedAt,
    required this.downloaded,
    required this.imgCnt,
  });

  Map<String, Object?> toMap() {
    return {
      'manga_id': mangaID,
      'id': id,
      'title': title,
      'src': src,
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

  @override
  String toString() {
    return 'Chapter{id: $id, mangaID: $mangaID, title: $title, src: $src, uploadedAt: $uploadedAt, downloaded: $downloaded}';
  }
}

class MangaView {
  final int id;
  final String title;
  final String img;
  final String src;
  String viewedChapter;
  final String lastChapter;
  final DateTime lastUploadedAt;
  final int missingDownloads;

  MangaView({
    required this.id,
    required this.title,
    required this.img,
    required this.src,
    required this.viewedChapter,
    required this.lastChapter,
    required this.lastUploadedAt,
    required this.missingDownloads,
  });

  @override
  String toString() {
    return 'MangaView{id: $id, title: $title, img: $img, src: $src, viewedChapter: $viewedChapter, lastChapter: $lastChapter, lastUploadedAt: $lastUploadedAt}';
  }
}
