import 'dart:io';

import 'package:mangas/models/persistence.dart';
import 'package:mangas/models/remote.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mangas/services/scrapers.dart';

class Manganato implements Scraper{
  static const rootURL = 'https://manganato.com';
  static const String searchPath = "/search/story";

  static const String referer = "https://readmanganato.com/";

  @override
  String name() {
    return 'Manganato';
  }

  @override
  Future<List<SearchResult>> search(String query) async {
    query = query.trim();
    query = query.replaceAll(RegExp(r"[-!$%^&*()+|~=`{}#@\[\]:;'’<>?, ]"), '_');

    var url = '$rootURL$searchPath/$query';

    final response = await http.Client().get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load $url: HTTP ${response.statusCode}');
    }

    var document = parser.parse(response.body);
    try {
      var cards = document.getElementsByClassName('search-story-item');

      var results = <SearchResult>[];
      for (var element in cards) {
        var img = element.getElementsByTagName('img');
        var attrs = img[0].attributes;
        var src = img[0].parent?.attributes['href'];
        var folder = src?.split('/').last;
        var rightElement = element.getElementsByClassName('item-right')[0];
        var lastChapter = rightElement.children[1].innerHtml;

        var rating = element.getElementsByClassName('item-rate')[0].innerHtml;

        results.add(SearchResult(
            title: attrs["alt"] ?? '',
            lastChapter: lastChapter,
            img: attrs["src"] ?? '',
            src: src ?? '',
            folder: folder ?? '',
            rating: rating,
        ));
      }

      return results;
    } catch (e) {
      throw Exception('Failed to parse URL $url: $e');
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
      var anchors = document.getElementsByClassName('chapter-name');
      var results = <ChapterResult>[];

      for (var element in anchors) {
        var title = element.innerHtml;
        if (fromChapterTitle == title) {
          break;
        }

        var src = element.attributes['href'];
        var dateString =
            element.nextElementSibling?.nextElementSibling?.attributes['title'];
        DateTime timestamp;
        try {
          DateFormat format = DateFormat("MMM dd,yyyy HH:mm");
          timestamp = format.parse(dateString!);
        } catch (e) {
          timestamp = DateTime.now();
        }

        results.add(
            ChapterResult(
                title: title,
                src: src ?? '',
                folder: src?.split('/').last ?? '',
                uploadedAt: timestamp,
            ));
      }

      return List.from(results.reversed);
    } catch (e) {
      throw Exception('Failed to parse manga source $mangaSrc: $e');
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
          document.getElementsByClassName('container-chapter-reader');

      if (container.isEmpty) {
        throw Exception('Unable to find images container for $chapterSrc. Did the url changed?');
      }

      var results = <String>[];

      for (var element in container[0].getElementsByTagName('img')) {
        var src = element.attributes['src'];
        if (src != null) {
          results.add(src);
        }
      }

      return results;
    } catch (e) {
      throw Exception('Failed to parse chapter source $chapterSrc: $e');
    }
  }

  @override
  Map<String, String>? headers() {
    return {HttpHeaders.refererHeader: referer};
  }
}
