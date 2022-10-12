import 'package:mangas/models/remote.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class Manganato {
  static const rootURL = 'https://manganato.com';
  static const String searchPath = "/search/story";

  static Future<List<SearchResult>> search(String query) async {
    query = query.trim();
    var url = '$rootURL$searchPath/${query.replaceAll(' ', '_')}';

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

        var rightElement = element.getElementsByClassName('item-right')[0];
        var lastChapter = rightElement.children[1].innerHtml;
        var updated = rightElement.children[4].innerHtml;

        results.add(SearchResult(
            title: attrs["alt"] ?? '',
            lastChapter: lastChapter,
            img: attrs["src"] ?? '',
            src: src ?? '',
            updatedDate: updated));
      }

      return results;
    } catch (e) {
      throw Exception('Failed to parse $url: $e');
    }
  }

  static Future<List<ChapterResult>> chapters(
      String mangaSrc, String fromChapterSrc) async {

    final response = await http.Client().get(Uri.parse(mangaSrc));
    if (response.statusCode != 200) {
      throw Exception('Failed to load $mangaSrc: HTTP ${response.statusCode}');
    }

    var document = parser.parse(response.body);
    try {
      var anchors = document.getElementsByClassName('chapter-name');
      var results = <ChapterResult>[];

      for (var element in anchors) {
        var src = element.attributes['href'];

        if (fromChapterSrc == src) {
          break;
        }

        var title = element.innerHtml;
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
            ChapterResult(title: title, src: src ?? '', uploadedAt: timestamp));
      }

      return List.from(results.reversed);
    } catch (e) {
      throw Exception('Failed to parse $mangaSrc: $e');
    }
  }

  static Future<List<String>> chapterImages(String chapterSrc) async {
    final response = await http.Client().get(Uri.parse(chapterSrc));
    if (response.statusCode != 200) {
      throw Exception('Failed to load $chapterSrc: HTTP ${response.statusCode}');
    }

    var document = parser.parse(response.body);
    try {
      var container =
          document.getElementsByClassName('container-chapter-reader');
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
}
