class SearchResult {
  final String title;
  final String lastChapter;
  final String rating;
  final String img;
  final String src;
  final String folder;

  SearchResult({
    required this.title,
    required this.lastChapter,
    required this.img,
    required this.src,
    required this.rating,
    required this.folder,
  });
}

class ChapterResult {
  final String title;
  final String src;
  final String folder;
  final DateTime uploadedAt;

  ChapterResult({
    required this.title,
    required this.src,
    required this.uploadedAt,
    required this.folder,
  });

  @override
  String toString() {
    return 'ChaptersResult{title: $title, src: $src, uploadedAt: $uploadedAt}';
  }
}
