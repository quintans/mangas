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
    ch.id = chapters.length + 1;
    lastChapterID = ch.id;
    chapters.add(ch);
  }

  setReadChapter(Chapter ch) {
    viewedChapterID = ch.id;
  }

  Chapter? getViewedChapter() {
    if (viewedChapterID <= 0) {
      return null;
    }
    return chapters[viewedChapterID -1];
  }

  List<Chapter> getChaptersToDownload() {
    List<Chapter> chs = [];
    var idx = viewedChapterID <= 0 ? 0 : viewedChapterID -1;
    for (var i = idx; i < chapters.length; i++) {
      if (!chapters[i].downloaded) {
        chs.add(chapters[i]);
      }
    }
    return chs;
  }

  List<Chapter> getDownloadedChapters() {
    List<Chapter> chs = [];
    for (var i = 0; i < chapters.length; i++) {
      if (chapters[i].downloaded) {
        chs.add(chapters[i]);
      }
    }
    return chs;
  }

  bool hasPreviousChapter(Chapter chapter) {
    return chapter.id > 1 && chapters[chapter.id - 2].downloaded;
  }

  Chapter previousChapter(Chapter chapter) {
    if (hasPreviousChapter(chapter)) {
      return chapters[chapter.id - 2];
    }
    return chapter;
  }

  bool hasNextChapter(Chapter chapter) {
    return chapters.length > chapter.id && chapters[chapter.id].downloaded;
  }

  Chapter nextChapter(Chapter chapter) {
    if (hasNextChapter(chapter)) {
      return chapters[chapter.id];
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
      'id': id,
      'manga_id': mangaID,
      'title': title,
      'src': src,
      'downloaded': downloaded ? 1 : 0,
      'img_cnt': imgCnt,
      'uploaded_at': uploadedAt.millisecondsSinceEpoch,
    };
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

  MangaView({
    required this.id,
    required this.title,
    required this.img,
    required this.src,
    required this.viewedChapter,
    required this.lastChapter,
    required this.lastUploadedAt,
  });

  @override
  String toString() {
    return 'MangaView{id: $id, title: $title, img: $img, src: $src, viewedChapter: $viewedChapter, lastChapter: $lastChapter, lastUploadedAt: $lastUploadedAt}';
  }
}
