class SearchResult {
  final String title;
  final String lastChapter;
  final String updatedDate;
  final String img;
  final String src;

  SearchResult({
    required this.title,
    required this.lastChapter,
    required this.img,
    required this.src,
    required this.updatedDate,
  });
}

class ChapterResult {
  final String title;
  final String src;
  final DateTime uploadedAt;

  ChapterResult({
    required this.title,
    required this.src,
    required this.uploadedAt,
  });

  @override
  String toString() {
    return 'ChaptersResult{title: $title, src: $src, uploadedAt: $uploadedAt}';
  }
}
