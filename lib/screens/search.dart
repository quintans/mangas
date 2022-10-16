import 'package:flutter/material.dart';
import 'package:mangas/models/persistence.dart';
import 'package:mangas/services/filesystem.dart';
import 'dart:async';

import 'package:mangas/services/persistence.dart';
import 'package:mangas/services/scrappers.dart';
import 'package:mangas/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchResultModel {
  final String title;
  final String lastChapter;
  final String img;
  final String src;
  final String uploadedDate;

  SearchResultModel({
    required this.title,
    required this.lastChapter,
    required this.img,
    required this.src,
    required this.uploadedDate,
  });
}

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPage();
}

class _SearchPage extends State<SearchPage> {
  final String _scrapperKey = 'scrapper_key';
  
  Timer? _debounce;
  final List<SearchResultModel> _items = [];
  String _lastQuery = '';
  List<String> _sources = [];
  String _scrapperID = 'manganato';

  void _search(Scrapper scrapper, String query) async {
    if (query.isEmpty || query == _lastQuery) {
      return;
    }

    var results = await scrapper.search(query);
    var r = <SearchResultModel>[];
    for (var v in results) {
      r.add(SearchResultModel(
        title: v.title,
        lastChapter: v.lastChapter,
        img: v.img,
        src: v.src,
        uploadedDate: v.updatedDate,
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
      var v = prefs.getString(_scrapperKey);
      if (v != null) {
        setState(() {
          _scrapperID = v;
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
      var scrapper = Scrappers.getScrapper(_scrapperID);
      _search(scrapper, query);
    });
  }

  _onBookmark(SearchResultModel item) async {
    var scrapper = Scrappers.getScrapper(_scrapperID);
    var res = await scrapper.chapters(item.src, '');
    List<Chapter> chapters = [];
    for (var r in res) {
      chapters.add(Chapter(
        id: 0,
        mangaID: 0,
        title: r.title,
        src: r.src,
        uploadedAt: r.uploadedAt,
        downloaded: false,
        imgCnt: 0,
      ));
    }

    var manga = Manga(
        id: 0,
        title: item.title,
        img: item.img,
        src: item.src,
        scrapperID: _scrapperID,
        bookmarkedChapterID: 1,
        lastChapterID: 0,
        chapters: chapters);
    var subDir = manga.src.split('/').last;
    // save image to directory
    await MyFS.downloadMangaCover(_scrapperID, subDir, manga.img);
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
                  value: _scrapperID,
                  onChanged: (value) {
                    if (value != null) {
                      SharedPreferences.getInstance().then((prefs) {
                        _scrapperID = value;
                        prefs.setString(_scrapperKey, _scrapperID);
                        _clearSearch();
                      });
                    }
                  },
                  items: Scrappers.getScrappers().entries.map((entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value.name()),
                  )).toList(),
                  // items: Scrappers.getScrappers().map((key, value) => null),
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
                  Text(item.uploadedDate),
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
