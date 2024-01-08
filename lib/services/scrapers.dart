import 'package:mangas/models/persistence.dart';
import 'package:mangas/models/remote.dart';
import 'package:mangas/services/manganato.dart';
import 'package:mangas/services/asura.dart';

class Scrapers {
  static final Map<String, Scraper> _scrapers =  {
    "asura": Asura(),
    "manganato": Manganato(),
  };

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

  Map<String, String>? headers() {
    throw Exception('name is unimplemented');
  }

  Future<List<SearchResult>> search(String query) async {
    throw Exception('search is unimplemented');
  }

  Future<List<ChapterResult>> chapters(Manga manga, bool rescan) async {
    throw Exception('chapters is unimplemented');
  }

  Future<List<String>> chapterImages(String chapterSrc) async {
    throw Exception('chapterImages is unimplemented');
  }

}