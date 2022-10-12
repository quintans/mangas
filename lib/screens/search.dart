import 'package:flutter/material.dart';
import 'package:manganato/models/persistence.dart';
import 'package:manganato/services/filesystem.dart';
import 'dart:async';

import 'package:manganato/services/manganato.dart';
import 'package:manganato/services/persistence.dart';
import 'package:manganato/utils/utils.dart';

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
  Timer? _debounce;
  final List<SearchResultModel> items = [];
  String lastQuery = '';
  List<String> sources = [];

  void _search(String query) async {
    if (query.isEmpty || query == lastQuery) {
      return;
    }

    var results = await Manganato.search(query);
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
      items.clear();
      items.addAll(r);
    });

    lastQuery = query;
  }

  @override
  void initState() {
    super.initState();
    _getMangaCodes().then((value) {
      setState(() {
        sources = value;
      });
    });
  }

  Future<List<String>> _getMangaCodes() async {
    return await DatabaseHelper.db.getMangaSources();
  }

  void _clearSearch() {
    controller.clear();
    setState(() {
      lastQuery = '';
      items.clear();
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
      _search(query);
    });
  }

  _onBookmark(SearchResultModel item) async {
    var res = await Manganato.chapters(item.src, '');
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
        viewedChapterID: 1,
        lastChapterID: 0,
        chapters: chapters);
    // save image to directory
    await MyFS.downloadMangaCover(manga.src, manga.img);
    await DatabaseHelper.db.insertManga(manga);

    setState(() {
      sources.add(item.src);
    });
  }

  var controller = TextEditingController(text: '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          // The search area here
          title: Container(
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
      )),
      body: ListView.separated(
        padding: const EdgeInsets.only(bottom: 56),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(
          height: 2,
        ),
        itemBuilder: (context, index) {
          var item = items[index];
          var disabled = sources.contains(item.src);
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
