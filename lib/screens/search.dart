import 'package:flutter/material.dart';
import 'package:mangas/models/persistence.dart';
import 'package:mangas/services/filesystem.dart';
import 'dart:async';

import 'package:mangas/services/persistence.dart';
import 'package:mangas/services/scrapers.dart';
import 'package:mangas/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class SearchResultModel {
  final String title;
  final String lastChapter;
  final String img;
  final String src;
  final String folder;
  final String rating;

  SearchResultModel({
    required this.title,
    required this.lastChapter,
    required this.img,
    required this.src,
    required this.folder,
    required this.rating,
  });
}

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPage();
}

class _SearchPage extends State<SearchPage> {
  final String _scraperKey = 'scraper_key';
  
  Timer? _debounce;
  final List<SearchResultModel> _items = [];
  String _lastQuery = '';
  List<String> _sources = [];
  String _scraperID = 'manganato';

  void _search(Scraper scraper, String query) async {
    if (query.isEmpty || query == _lastQuery) {
      return;
    }

    var results = await scraper.search(query);
    var r = <SearchResultModel>[];
    for (var v in results) {
      r.add(SearchResultModel(
        title: v.title,
        lastChapter: v.lastChapter,
        img: v.img,
        src: v.src,
        folder: v.folder,
        rating: v.rating,
      ));
    }
    setState(() {
      _items.clear();
      _items.addAll(r);
    });

    _lastQuery = query;
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      var v = prefs.getString(_scraperKey);
      if (v != null) {
        setState(() {
          _scraperID = v;
        });
      }
    });

    _getMangaCodes().then((value) {
      setState(() {
        _sources = value;
      });
    });
  }

  Future<List<String>> _getMangaCodes() async {
    return await DatabaseHelper.db.getMangaSources();
  }

  void _clearSearch() {
    controller.clear();
    setState(() {
      _lastQuery = '';
      _items.clear();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    if (query.length < 3) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      var scraper = Scrapers.getScraper(_scraperID);
      _search(scraper, query);
    });
  }

  _onBookmark(SearchResultModel item) async {
    var manga = Manga(
        id: 0,
        title: item.title,
        img: item.img,
        src: item.src,
        scraperID: _scraperID,
        bookmarkedChapterID: 1,
        lastChapterID: 0,
        folder: item.folder,
        chapters: []);

    var scraper = Scrapers.getScraper(_scraperID);
    var res = await scraper.chapters(manga);
    for (var r in res) {
      manga.addChapter(Chapter(
        id: 0,
        mangaID: 0,
        title: r.title,
        src: r.src,
        uploadedAt: r.uploadedAt,
        downloaded: false,
        imgCnt: 0,
        folder: r.folder,
      ));
    }



    // save image to directory
    await MyFS.downloadMangaCover(Dio(), _scraperID, manga.folder, manga.img);
    await DatabaseHelper.db.insertManga(manga);

    setState(() {
      _sources.add(item.src);
    });
  }

  var controller = TextEditingController(text: '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 120,
        // The search area here
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,

          children: [
            Container(
              width: double.infinity,
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(5)),
              child: Center(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _scraperID,
                  onChanged: (value) {
                    if (value != null) {
                      SharedPreferences.getInstance().then((prefs) {
                        _scraperID = value;
                        prefs.setString(_scraperKey, _scraperID);
                        _clearSearch();
                      });
                    }
                  },
                  items: Scrapers.getScrapers().entries.map((entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value.name()),
                  )).toList(),
                ),
              ),
            ),
            const SizedBox(height: 10,),
            Container(
              width: double.infinity,
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(5)),
              child: Center(
                child: TextField(
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  controller: controller,
                  decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _clearSearch();
                        },
                      ),
                      hintText: 'Search...',
                      border: InputBorder.none),
                ),
              ),
            )
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.only(bottom: 56),
        itemCount: _items.length,
        separatorBuilder: (context, index) => const SizedBox(
          height: 2,
        ),
        itemBuilder: (context, index) {
          var item = _items[index];
          var disabled = _sources.contains(item.src);
          return IntrinsicHeight(
              child: Row(
            children: [
              const SizedBox(
                width: 4,
              ),
              Image.network(
                item.img,
                height: 90,
                width: 61,
              ),
              const SizedBox(
                width: 4,
              ),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(item.lastChapter),
                  Text('rating: ${item.rating}'),
                ],
              )),
              IconButton(
                  onPressed: disabled
                      ? null
                      : () async {
                          _onBookmark(item);
                          Utils.snack(context, "Bookmarked ${item.title}");
                        },
                  icon: Icon(disabled
                      ? Icons.bookmark_added_outlined
                      : Icons.bookmark_add)),
            ],
          ));
        },
      ),
    );
  }
}
