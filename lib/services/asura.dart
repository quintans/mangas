import 'dart:developer';

import 'package:mangas/models/persistence.dart';
import 'package:mangas/models/remote.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mangas/services/scrapers.dart';

class Asura implements Scraper{
  static const rootURL = 'https://asura.gg';
  static const String searchPath = "/?s=";

  @override
  String name() {
    return 'Asura';
  }
  
  String _lastPath(String? url) {
    var parts = url?.split('/');
    if (parts?.isNotEmpty ?? false) {
      return parts!.elementAt(parts.length - 2);
    }
    return '';
  }

  @override
  Future<List<SearchResult>> search(String query) async {
    query = query.trim();
    var url = '$rootURL$searchPath${query.replaceAll(' ', '+')}';

    final response = await http.Client().get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load $url: HTTP ${response.statusCode}');
    }

    var document = parser.parse(response.body);
    try {
      var cards = document.getElementsByClassName('bsx');

      var results = <SearchResult>[];
      for (var element in cards) {
        var anchor = element.getElementsByTagName('a')[0];
        var src = anchor.attributes['href'];
        String folder = _lastPath(src);

        var title = anchor.attributes['title'];

        var img = anchor.getElementsByTagName('img')[0];

        var chapterElement = anchor.getElementsByClassName('epxs')[0];
        var lastChapter = chapterElement.innerHtml;
        var ratingElement = anchor.getElementsByClassName('numscore')[0];
        var rating = ratingElement.innerHtml;

        results.add(SearchResult(
            title: title ?? 'n/a',
            lastChapter: lastChapter,
            img: img.attributes["src"] ?? '',
            src: src ?? '',
            folder: folder,
            rating: rating,
        ));
      }

      return results;
    } catch (e) {
      throw Exception('Failed to parse $url: $e');
    }
  }

  @override
  Future<List<ChapterResult>> chapters(Manga manga, bool rescan) async {
    String mangaSrc = manga.src;
    var chapters = manga.getChapters();
    var fromChapterTitle = '';
    if (chapters.isNotEmpty) {
      if (rescan) {
        fromChapterTitle = chapters[manga.bookmarkedChapterID - 1].title;
      } else {
        fromChapterTitle = chapters.last.title;
      }
    }
    
    final response = await http.Client().get(Uri.parse(mangaSrc));
    if (response.statusCode != 200) {
      throw Exception('Failed to load $mangaSrc: HTTP ${response.statusCode}');
    }

    var document = parser.parse(response.body);
    try {
      var chapters = document.getElementsByClassName('chbox');
      var results = <ChapterResult>[];

      for (var element in chapters) {
        var title = element.getElementsByClassName('chapternum')[0].innerHtml;
        if (fromChapterTitle == title) {
          break;
        }

        var src = element.getElementsByTagName('a')[0].attributes['href'];
        var dateString = element.getElementsByClassName('chapterdate')[0].innerHtml;
        DateTime timestamp;
        try {
          DateFormat format = DateFormat("MMM dd, yyyy");
          timestamp = format.parse(dateString!);
        } catch (e) {
          timestamp = DateTime.now();
        }

        var folder = _lastPath(src);
        folder = folder.replaceAll(manga.folder, '');

        results.add(
            ChapterResult(
                title: title,
                src: src ?? '',
                folder: folder,
                uploadedAt: timestamp,
            ));
      }

      return List.from(results.reversed);
    } catch (e) {
      throw Exception('Failed to parse $mangaSrc: $e');
    }
  }

  @override
  Future<List<String>> chapterImages(String chapterSrc) async {
    final response = await http.Client().get(Uri.parse(chapterSrc));
    if (response.statusCode != 200) {
      throw Exception('Failed to load $chapterSrc: HTTP ${response.statusCode}');
    }

    var document = parser.parse(response.body);
    try {
      var container =
          document.getElementsByClassName('rdminimal');
      var results = <String>[];

      for (var element in container[0].getElementsByTagName('img')) {
        var src = element.attributes['src'];
        if (src != null) {
          results.add(src);
        }
      }

      return results;
    } catch (e) {
      throw Exception('Failed to parse $chapterSrc: $e');
    }
  }

  @override
  Map<String, String>? headers() {
    return null;
  }
}
