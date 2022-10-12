import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manganato/services/filesystem.dart';
import 'package:manganato/services/manganato.dart';
import 'package:manganato/services/persistence.dart';
import 'package:manganato/utils/utils.dart';
import './search.dart';
import './reader.dart';
import '../models/persistence.dart';
import 'package:intl/intl.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  State<FavoritesPage> createState() => _FavoritesPage();
}

class _FavoritesPage extends State<FavoritesPage> {
  List<MangaView> mangas = [];

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    return DatabaseHelper.db.getMangaReadingOrder().then((value) {
      // check if file exists in FS
      setState(() {
        mangas = value;
      });
    });
  }

  Future<Chapter?> _chooseCurrentChapter(
      BuildContext context, MangaView mangaView) async {
    var manga = await DatabaseHelper.db.getManga(mangaView.id);
    return showDialog<Chapter>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Choose viewed chapter'),
                content: DropdownButton<Chapter>(
                  isExpanded: true,
                  value: manga?.getBookmarkedChapter(),
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items: manga?.chapters.reversed.map((Chapter chapter) {
                    return DropdownMenuItem(
                      value: chapter,
                      child: Text(chapter.title),
                    );
                  }).toList(),
                  onChanged: (Chapter? newValue) {
                    setState(() {
                      manga?.bookmark(newValue!);
                    });
                  },
                ),
                actions: <Widget>[
                  TextButton(
                    style: ButtonStyle(
                      foregroundColor:
                          MaterialStateProperty.all<Color>(Colors.white),
                      backgroundColor:
                          MaterialStateProperty.all<Color>(Colors.red),
                    ),
                    child: const Text('CANCEL'),
                    onPressed: () {
                      setState(() {
                        Navigator.pop(context);
                      });
                    },
                  ),
                  TextButton(
                    style: ButtonStyle(
                      foregroundColor:
                          MaterialStateProperty.all<Color>(Colors.white),
                      backgroundColor:
                          MaterialStateProperty.all<Color>(Colors.green),
                    ),
                    child: const Text('OK'),
                    onPressed: () {
                      setState(() {
                        DatabaseHelper.db.updateManga(manga!);
                        setState(() {
                          var viewed = manga.getBookmarkedChapter();
                          if (viewed != null) {
                            mangaView.viewedChapter = viewed.title;
                          }
                        });
                        Navigator.pop(context, manga.getBookmarkedChapter());
                      });
                    },
                  ),
                ],
              );
            },
          );
        });
  }

  Future<void> _downloadFromViewed(BuildContext context, MangaView view) async {
    var snack = Snack(context: context);
    final ProgressDialog pd = ProgressDialog(context: context);

    var manga = await DatabaseHelper.db.getManga(view.id);
    var chapters = manga!.getChaptersToDownload();

    pd.show(max: chapters.length, msg: 'Chapter Downloading...');
    try {
      var cnt = 0;
      for (var ch in chapters) {
        var imgs = await Manganato.chapterImages(manga.src, ch.src);
        List<Future<File>> futures = [];
        for (var i = 0; i < imgs.length; i++) {
          var f = MyFS.downloadChapterImage(manga.src, ch.src, i, imgs[i]);
          futures.add(f);
        }
        await Future.wait(futures);
        ch.markDownloaded(imgs.length);
        DatabaseHelper.db.updateManga(manga);
        pd.update(value: ++cnt);
      }
    } finally {
      pd.close();
    }
    await _load();
    snack.show("Finished Downloading");
  }

  _deleteManga(BuildContext context, MangaView mangaView) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete?"),
          content: Text("Would you like to delete ${mangaView.title}?"),
          actions: <Widget>[
            TextButton(
              style: ButtonStyle(
                foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                backgroundColor: MaterialStateProperty.all<Color>(Colors.red),
              ),
              child: const Text('CANCEL'),
              onPressed: () {
                setState(() {
                  Navigator.pop(context);
                });
              },
            ),
            TextButton(
              style: ButtonStyle(
                foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                backgroundColor: MaterialStateProperty.all<Color>(Colors.green),
              ),
              child: const Text('OK'),
              onPressed: () {
                DatabaseHelper.db.deleteManga(mangaView.id);
                Navigator.pop(context);
                setState(() {
                  _load().then((value) => MyFS.deleteManga(mangaView.src));
                });
              },
            ),
          ],
        );
      },
    );
  }

  _lookForNewChapters() async {
    var snack = Snack(context: context);
    final ProgressDialog pd = ProgressDialog(context: context);

    var mng = await DatabaseHelper.db.getMangas();
    pd.show(max: mng.length, msg: 'Looking for new chapters...');
    var count = 0;
    for (var m in mng) {
      var last = m.getChapters().last;
      var newChapters = await Manganato.chapters(m.src, last.src);
      for (var r in newChapters) {
        m.addChapter(Chapter(
          id: 0,
          mangaID: 0,
          title: r.title,
          src: r.src,
          uploadedAt: r.uploadedAt,
          downloaded: false,
          imgCnt: 0,
        ));
      }
      if (newChapters.isNotEmpty) {
        await DatabaseHelper.db.updateManga(m);
      }
      pd.update(value: ++count);
    }
    snack.show('Finished looking for new chapters');
    _load();
  }

  _discardChapters() async {
    var snack = Snack(context: context);

    final ProgressDialog pd = ProgressDialog(context: context);
    var mangas = await DatabaseHelper.db.getMangas();
    pd.show(max: mangas.length, msg: 'Discarding old chapters...');
    var count = 0;
    for (var manga in mangas) {
      pd.update(value: ++count);
      var chapters = manga.getChaptersToDiscard();
      for (var c in chapters) {
        await MyFS.deleteChapter(manga.src, c.src);
        c.discarded();
      }
      if (chapters.isNotEmpty) {
        DatabaseHelper.db.updateManga(manga);
      }
    }
    snack.show('Finished discarding old chapters');
  }

  @override
  Widget build(BuildContext context) {
    const title = 'Mangas';

    return Scaffold(
      appBar: AppBar(
        title: const Text(title),
        actions: [
          // Navigate to the Search Screen
          IconButton(onPressed: () => _lookForNewChapters(), icon: const Icon(Icons.refresh)),
          IconButton(onPressed: () => _discardChapters(), icon: const Icon(Icons.recycling)),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.only(bottom: 56),
        itemCount: mangas.length,
        separatorBuilder: (context, index) => const SizedBox(
          height: 2,
        ),
        itemBuilder: (context, index) {
          var manga = mangas[index];
          var formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
          return InkWell(
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (_) => ReaderPage(mangaID: manga.id)))
                  .then((value) => _load()),
              child: IntrinsicHeight(
                  child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  const SizedBox(
                    width: 4,
                  ),
                  FutureBuilder<File>(
                    future: MyFS.loadMangaCover(manga.src, manga.img),
                    builder:
                        (BuildContext context, AsyncSnapshot<File> snapshot) {
                      if (snapshot.hasData) {
                        return Image.file(
                          snapshot.requireData,
                          height: 90,
                          width: 61,
                        );
                      } else if (snapshot.hasError) {
                        return Image.asset(
                          'images/error.png',
                          height: 90,
                          width: 61,
                        );
                      } else {
                        return Image.asset(
                          'images/hourglass.png',
                          height: 90,
                          width: 61,
                        );
                      }
                    },
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
                        manga.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          const Text('Viewed: '),
                          Text(manga.viewedChapter),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Current: '),
                          Text(
                            manga.lastChapter +
                                (manga.missingDownloads > 0
                                    ? ' (${manga.missingDownloads})'
                                    : ''),
                            style: TextStyle(
                              fontWeight:
                                  manga.viewedChapter != manga.lastChapter
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              color: manga.viewedChapter != manga.lastChapter
                                  ? Colors.green
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Last updated: ${formatter.format(manga.lastUploadedAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  )),
                  PopupMenuButton(
                    onSelected: (value) async {
                      switch (value) {
                        case 'delete':
                          return _deleteManga(context, manga);
                        case 'download':
                          _downloadFromViewed(context, manga);
                        // default:
                        //   throw UnimplementedError();
                      }
                    },
                    itemBuilder: (context) {
                      return [
                        PopupMenuItem(
                          onTap: () {
                            _chooseCurrentChapter(context, manga).then((value) {
                              _load();
                            });
                          },
                          value: 'set_viewed',
                          child: const Text('Select Viewed'),
                        ),
                        PopupMenuItem(
                          value: 'download',
                          child: Text(
                              'Download${manga.missingDownloads > 0 ? ' (${manga!.missingDownloads})' : ''}'),
                        ),
                        const PopupMenuItem(
                          value: 'recycle',
                          child: Text('Recycle'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ];
                    },
                  )
                ],
              )));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SearchPage()))
            .then((value) => _load()),
        tooltip: 'Add new Manga',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
