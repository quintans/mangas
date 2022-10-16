import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mangas/services/filesystem.dart';
import 'package:mangas/services/manganato.dart';
import 'package:mangas/services/persistence.dart';
import 'package:mangas/services/scrappers.dart';
import 'package:mangas/utils/utils.dart';
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
  static const int _downloadThreshold = 10;

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
                title: const Text('Choose current chapter'),
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
                          var bookmarked = manga.getBookmarkedChapter();
                          mangaView.bookmarkedChapter = bookmarked.title;
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

  _confirmAllDownload() async {
    var missingDownloads = 0;
    for (var m in mangas) {
      missingDownloads += m.missingDownloads;
    }
    if (missingDownloads <= _downloadThreshold) {
      _downloadAllMissingChaptersFromBookmarked(missingDownloads);
      return;
    }

    _confirm(
        "You will be downloading $missingDownloads chapters.\nWould you like to proceed?",
        () {
      _downloadAllMissingChaptersFromBookmarked(missingDownloads);
    });
  }

  _downloadAllMissingChaptersFromBookmarked(int missingDownloads) async {
    var snack = Snack(context: context);
    final ProgressDialog pd = ProgressDialog(context: context);

    var mangas = await DatabaseHelper.db.getMangas();
    pd.show(max: missingDownloads, msg: 'Chapter Downloading...');
    var count = 0;
    for (var m in mangas) {
      count = await _downloadChapters(pd, m, count);
    }

    await _load();
    snack.show("Finished Downloading");
  }

  _confirmDownload(MangaView mangaView) async {
    if (mangaView.missingDownloads <= _downloadThreshold) {
      _downloadMissingChaptersFromBookmarked(mangaView.id);
      return;
    }

    _confirm(
        "You will be downloading ${mangaView.missingDownloads} chapters.\nWould you like to proceed?",
        () {
      _downloadMissingChaptersFromBookmarked(mangaView.id);
    });
  }

  _downloadMissingChaptersFromBookmarked(int mangaID) async {
    var snack = Snack(context: context);
    final ProgressDialog pd = ProgressDialog(context: context);

    var manga = await DatabaseHelper.db.getManga(mangaID);
    var chapters = manga!.getChaptersToDownload();
    pd.show(max: chapters.length, msg: 'Chapter Downloading...');
    await _downloadChapters(pd, manga, 0);
    pd.close();

    await _load();
    snack.show("Finished Downloading");
  }

  Future<int> _downloadChapters(
      ProgressDialog pd, Manga manga, int count) async {
    var chapters = manga.getChaptersToDownload();

    var provider = Scrappers.getScrapper(manga.scrapperID);

    for (var ch in chapters) {
      var imgs = await provider.chapterImages(ch.src);
      List<Future<File>> futures = [];
      for (var i = 0; i < imgs.length; i++) {
        var subDir = ch.src.split('/');
        var f = MyFS.downloadChapterImages(manga.scrapperID,
            subDir[subDir.length - 2], subDir.last, i, imgs[i]);
        futures.add(f);
      }
      await Future.wait(futures);
      ch.markDownloaded(imgs.length);
      await DatabaseHelper.db.updateManga(manga);
      pd.update(value: ++count);
    }
    return count;
  }

  _deleteManga(BuildContext context, MangaView mangaView) async {
    _confirm("Would you like to delete ${mangaView.title}?", () {
      DatabaseHelper.db.deleteManga(mangaView.id).then((value) {
        var subDir = mangaView.src.split('/').last;
        _load().then((value) => MyFS.deleteManga(mangaView.scrapperID, subDir));
      });
    });
  }

  Future<void> _lookForNewChapters() async {
    var snack = Snack(context: context);
    final ProgressDialog pd = ProgressDialog(context: context);

    var mng = await DatabaseHelper.db.getMangas();
    pd.show(max: mng.length, msg: 'Looking for new chapters...');
    var count = 0;
    for (var m in mng) {
      var provider = Scrappers.getScrapper(m.scrapperID);
      var last = m.getChapters().last;
      var newChapters = await provider.chapters(m.src, last.src);
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
    return _load();
  }

  _scrubAllMangas() async {
    var snack = Snack(context: context);

    var mangas = await DatabaseHelper.db.getMangas();
    var count = 0;
    for (var manga in mangas) {
      count += await _scrubChapters(manga);
    }
    snack.show('Discarded $count chapter(s)');
  }

  _scrubManga(MangaView view) async {
    var snack = Snack(context: context);
    var manga = await DatabaseHelper.db.getManga(view.id);
    if (manga != null) {
      var count = await _scrubChapters(manga);
      snack.show('Discarded $count chapter(s)');
    }
  }

  Future<int> _scrubChapters(Manga manga) async {
    var chapters = manga.getChaptersToDiscard();
    for (var c in chapters) {
      var subDir = c.src.split('/');
      await MyFS.deleteChapter(manga.scrapperID, subDir[subDir.length - 2], subDir.last);
      c.discarded();
    }
    if (chapters.isNotEmpty) {
      DatabaseHelper.db.updateManga(manga);
    }
    return chapters.length;
  }

  String _formatDate(MangaView manga) {
    var now = DateTime.now();
    var diff = now.difference(manga.lastUploadedAt);
    if (diff > const Duration(days: 3)) {
      var formatter = DateFormat('yyyy-MM-dd');
      return formatter.format(manga.lastUploadedAt);
    }
    if (diff > const Duration(hours: 24)) {
      return '${diff.inDays} day(s)';
    }
    if (diff > const Duration(minutes: 60)) {
      return '${diff.inHours} hour(s)';
    }
    if (diff > const Duration(seconds: 60)) {
      return '${diff.inMinutes} minutes(s)';
    }
    return "now";
  }

  @override
  Widget build(BuildContext context) {
    const title = 'Mangas';

    return Scaffold(
      appBar: AppBar(
        title: const Text(title),
        actions: [
          // Navigate to the Search Screen
          IconButton(
              onPressed: () => _lookForNewChapters(),
              icon: const Icon(Icons.refresh)),
          IconButton(
              onPressed: () => _confirmAllDownload(),
              icon: const Icon(Icons.download)),
          IconButton(
              onPressed: () => _scrubAllMangas(),
              icon: const Icon(Icons.recycling)),
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
          var subDir = manga.src.split('/').last;
          return InkWell(
              onTap: () {
                DatabaseHelper.db
                    .getManga(manga.id)
                    .then((value) => Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => ReaderPage(
                                  manga: value!,
                                )))
                        .then((value) => _load()));
              },
              child: IntrinsicHeight(
                  child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  const SizedBox(
                    width: 4,
                  ),
                  FutureBuilder<File>(
                    future: MyFS.loadMangaCover(manga.scrapperID, subDir, manga.img),
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
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          const Text('Current: '),
                          Expanded(child: Text(manga.bookmarkedChapter, overflow: TextOverflow.ellipsis,),),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Last: '),
                          Expanded(child:Text(
                            manga.lastChapter +
                                (manga.missingDownloads > 0
                                    ? ' (${manga.missingDownloads})'
                                    : ''),
                            style: TextStyle(
                              fontWeight:
                                  manga.bookmarkedChapter != manga.lastChapter
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              color:
                                  manga.bookmarkedChapter != manga.lastChapter
                                      ? (manga.missingDownloads > 0
                                          ? Colors.orange
                                          : Colors.green)
                                      : Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),),
                        ],
                      ),
                      Text(
                        'Last updated: ${_formatDate(manga)}',
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
                          _deleteManga(context, manga);
                          break;
                        case 'download':
                          _confirmDownload(manga);
                          break;
                        case 'set_bookmarked':
                          _chooseCurrentChapter(context, manga).then((value) {
                            _load();
                          });
                          break;
                        case 'recycle':
                          _scrubManga(manga);
                          break;
                        // default:
                        //   throw UnimplementedError();
                      }
                    },
                    itemBuilder: (context) {
                      return [
                        const PopupMenuItem(
                          value: 'set_bookmarked',
                          child: Text('Select Current'),
                        ),
                        PopupMenuItem(
                          value: 'download',
                          child: Text(
                              'Download${manga.missingDownloads > 0 ? ' (${manga.missingDownloads})' : ''}'),
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

  _confirm(String message, Function okFunc) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm"),
          content: Text(message),
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
                Navigator.pop(context);
                okFunc();
              },
            ),
          ],
        );
      },
    );
  }
}
