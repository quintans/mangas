import 'package:mangas/models/remote.dart';
import 'package:mangas/services/manganato.dart';

class Scrapers {
  static final Map<String, Scraper> _scrapers =  { "manganato": Manganato()};

  static Map<String, Scraper> getScrapers() {
    return _scrapers;
  }

  static Scraper getScraper(String scraperID) {
    return _scrapers[scraperID]!;
  }
}

abstract class Scraper {
  String name() {
    throw Exception('name is unimplemented');
  }

  Future<List<SearchResult>> search(String query) async {
    throw Exception('search is unimplemented');
  }

  Future<List<ChapterResult>> chapters(String mangaSrc, String fromChapterSrc) async {
    throw Exception('chapters is unimplemented');
  }

  Future<List<String>> chapterImages(String chapterSrc) async {
    throw Exception('chapterImages is unimplemented');
  }
}