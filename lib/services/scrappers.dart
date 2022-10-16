import 'package:mangas/models/remote.dart';
import 'package:mangas/services/manganato.dart';

class Scrappers {
  static final Map<String, Scrapper> _scrappers =  { "manganato": Manganato()};

  static Map<String, Scrapper> getScrappers() {
    return _scrappers;
  }

  static Scrapper getScrapper(String providerID) {
    return _scrappers[providerID]!;
  }
}

abstract class Scrapper {
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