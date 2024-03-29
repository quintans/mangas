import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mangas/services/filesystem.dart';
import 'package:mangas/services/navigation_service.dart';
import 'package:mangas/services/persistence.dart';
import 'package:mangas/services/scrapers.dart';
import 'package:mangas/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './search.dart';
import './reader.dart';
import '../models/persistence.dart';
import 'package:intl/intl.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';
import 'package:path/path.dart';
import 'package:dio/dio.dart';
import 'package:p_limit/p_limit.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  State<FavoritesPage> createState() => _FavoritesPage();
}

class _FavoritesPage extends State<FavoritesPage> {
  final String _lastReadKey = 'last_read';
  final String _sortByNameKey = 'sort_by_name';
  static const int _downloadThreshold = 10;

  static const timeLimit = Duration(seconds: 5);

  List<MangaView> mangas = [];
  int _lastRead = -1;
  bool _sortByName = false;

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    var prefs = await SharedPreferences.getInstance();

    var last = prefs.getInt(_lastReadKey) ?? -1;
    var sort = prefs.getBool(_sortByNameKey) ?? false;

    var value = await DatabaseHelper.db.getMangaReadingOrder(sort);
    // check if file exists in FS
    setState(() {
      mangas = value;
      _lastRead = last;
      _sortByName = sort;
    });
  }

  Future<void> _toggleSortByName() async {
    var prefs = await SharedPreferences.getInstance();

    var sort = prefs.getBool(_sortByNameKey) ?? false;
    prefs.setBool(_sortByNameKey, !sort);

    await _load();
  }

  _readManga(int mangaID) async {
    var prefs = await SharedPreferences.getInstance();
    prefs.setInt(_lastReadKey, mangaID);

    DatabaseHelper.db.getManga(mangaID).then((value) => NavigationService()
            .navigateToScreen(ReaderPage(
          manga: value!,
        ))
            .then((value) {
          _load();
        }));
  }

  Future<Chapter?> _chooseCurrentChapter(
      BuildContext context, MangaView mangaView) async {
    var manga = await DatabaseHelper.db.getManga(mangaView.id);

    return showDialog<Chapter>(
        context: this.context,
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
    var snack = Snack(context: this.context);
    final ProgressDialog pd = ProgressDialog(context: this.context);
    try {
      var mangas = await DatabaseHelper.db.getMangas();
      pd.show(max: missingDownloads, msg: 'Chapter Downloading...');
      var count = 0;
      for (var m in mangas) {
        count = await _downloadChapters(snack, pd, m, count);
      }
    } finally {
      pd.close();
    }
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
    var snack = Snack(context: this.context);
    final ProgressDialog pd = ProgressDialog(context: this.context);

    var manga = await DatabaseHelper.db.getManga(mangaID);
    var chapters = manga!.getChaptersToDownload();
    pd.show(max: chapters.length, msg: manga.title);
    try {
      await _downloadChapters(snack, pd, manga, 0);
    } finally {
      pd.close();
    }

    snack.show("Finished Downloading");
  }

  Future<int> _downloadChapters(
    Snack snack, ProgressDialog pd, Manga manga, int count) async {
    var chapters = manga.getChaptersToDownload();

    final dioClient = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 60),
    ));

    var chCnt = 1;
    var msg = "($chCnt/${chapters.length}) ${manga.title}";
    pd.update(value: count, msg: msg);
    try {
      var scraper = Scrapers.getScraper(manga.scraperID);
      final limit = PLimit<void>(5);
      var futures = <Future<void>>[];
      for (var ch in chapters) {
        var f = limit(() {
          return _downloadChapterImages(snack, pd, dioClient, scraper, manga, ch, () {
            chCnt++;
            count++;
            msg = "($chCnt/${chapters.length}) ${manga.title}";
            pd.update(value: count, msg: msg);
          });
        });
        futures.add(f);
      }
      await Future.wait(futures);
    } catch (e) {
      final snackBar = SnackBar(
        duration: const Duration(days: 1),
        backgroundColor: Colors.red,
        showCloseIcon: true,
        content: Text('ERROR on ($chCnt/${chapters.length}) ${manga.title}: $e'),
      );
      ScaffoldMessenger.of(this.context).showSnackBar(snackBar);
    } finally {
      dioClient.close();
    }

    return count;
  }

  Future<void> _downloadChapterImages(Snack snack, ProgressDialog pd, Dio dioClient, Scraper scraper, Manga manga, Chapter ch, Function() done) async {
    try {
      var imgs = await scraper.chapterImages(ch.src);
      List<Future> futures = [];
      for (var i = 0; i < imgs.length; i++) {
        var f = MyFS.downloadChapterImages(
            dioClient, manga.scraperID, manga.folder, ch.folder, i, imgs[i], scraper.headers());
        futures.add(f);
      }

      await Future.wait(futures);
      ch.markDownloaded(imgs.length);
      await DatabaseHelper.db.updateManga(manga);
      await _load();
    } on TimeoutException catch (_) {
      snack.show('Timeout downloading "${manga.title}/${ch.title}"');
    } catch (e) {
      snack.error('Failed for "${manga.title}/${ch.title}": $e');
    }
    done();
  }

  _deleteManga(BuildContext context, MangaView mangaView) async {
    _confirm("Would you like to delete ${mangaView.title}?", () {
      DatabaseHelper.db.deleteManga(mangaView.id).then((value) {
        _load().then(
            (value) => MyFS.deleteManga(mangaView.scraperID, mangaView.folder));
      });
    });
  }

  Future<void> _lookForAllNewChapters() async {
    var mng = await DatabaseHelper.db.getMangas();
    _lookForNewChaptersInMangas(mng, false);
  }

  Future<void> _lookForNewChapters(MangaView manga) async {
    var mng = await DatabaseHelper.db.getManga(manga.id);
    _lookForNewChaptersInMangas([mng!], false);
  }

  Future<void> _rescanAllAndLookForNewChapters() async {
    var mngs = await DatabaseHelper.db.getMangas();
    _lookForNewChaptersInMangas(mngs, true);
  }

  Future<void> _dropAndReload(BuildContext context, MangaView mv) async {
    var scraper = Scrapers.getScraper(mv.scraperID);
    var res = await scraper.search(mv.title);
    if (res.length != 1) {
      var snack = Snack(context: this.context);
      var extra = "\nNothing was found";
      if (res.isNotEmpty) {
        extra = "Found:";
        for (var i = 0; i < 3 || i < res.length; i++) {
          extra = "\n${res[i]}";
        }
      }
      snack.show("Couldn't find unique result for ${mv.title}. $extra");
      return;
    }

    var item = res.first;

    var original = await DatabaseHelper.db.getManga(mv.id);

    var manga = Manga(
        id: 0,
        title: item.title,
        img: item.img,
        src: item.src,
        scraperID: mv.scraperID,
        bookmarkedChapterID: original?.bookmarkedChapterID ?? 1,
        lastChapterID: 0,
        folder: item.folder,
        chapters: []);

    var result = await scraper.chapters(manga, false);
    for (var r in result) {
      manga.upsertChapter(r);
    }

    _confirm("Would you like to drop and rescan ${mv.title}?", () {
      DatabaseHelper.db.deleteManga(mv.id).then((value) {
        _load().then(
                (value) {
                  MyFS.deleteManga(mv.scraperID, mv.folder);
                  // save image to directory
                  MyFS.downloadMangaCover(Dio(), mv.scraperID, manga.folder, manga.img).
                    then((value) => DatabaseHelper.db.insertManga(manga));
                });
      });
    });

    await _load();
  }

  Future<void> _lookForNewChaptersInMangas(List<Manga> mng, bool rescan) async {
    var snack = Snack(context: this.context);
    final ProgressDialog pd = ProgressDialog(context: this.context);
    pd.show(max: mng.length, msg: 'Looking for new chapters...');

    var count = 0;
    for (var m in mng) {
      var scraper = Scrapers.getScraper(m.scraperID);

      try {
        var newChapters = await scraper.chapters(m, rescan).timeout(timeLimit);

        for (var r in newChapters) {
          m.upsertChapter(r);
        }
        if (newChapters.isNotEmpty) {
          await DatabaseHelper.db.updateManga(m);
          await _load();
        }
      } on TimeoutException catch (_) {
        snack.show('Timed out while looking for new chapters for "${m.title}"');
      } catch (e) {
        snack.show('Failed for "${m.title}": $e');
      }

      pd.update(value: ++count);
    }
    snack.show('Finished looking for new chapters');
  }

  _scrubAllMangas() async {
    var snack = Snack(context: this.context);

    var mangas = await DatabaseHelper.db.getMangas();
    var count = 0;
    for (var manga in mangas) {
      count += await _scrubChapters(manga);
    }
    snack.show('Discarded $count chapter(s)');
  }

  _scrubManga(MangaView view) async {
    var snack = Snack(context: this.context);
    var manga = await DatabaseHelper.db.getManga(view.id);
    if (manga != null) {
      var count = await _scrubChapters(manga);
      snack.show('Discarded $count chapter(s)');
    }
  }

  Future<int> _scrubChapters(Manga manga) async {
    var chapters = manga.getChaptersToDiscard();
    for (var c in chapters) {
      await MyFS.deleteChapter(manga.scraperID, manga.folder, c.folder);
      c.discarded();
    }
    if (chapters.isNotEmpty) {
      await DatabaseHelper.db.updateManga(manga);
    }
    return chapters.length;
  }

  _exportData() async {
    String? expFolder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Please select an output folder:',
    );

    if (expFolder == null) {
      return;
    }
    var snack = Snack(context: this.context);
    final ProgressDialog pd = ProgressDialog(context: this.context);
    pd.show(max: 1, msg: 'exporting database...');

    var expFile = join(expFolder, DatabaseHelper.dbName);
    var ok = await DatabaseHelper.db.exportDatabase(expFile);
    if (ok) {
      snack.show('Database exported to $expFile');
    } else {
      snack.show('No permission granted');
    }
    pd.close();
  }

  _importData() async {
    _confirm('Importing will erase existing data.\nDo you wish to proceed?',
        () async {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Please select an file to import:',
      );

      if (result == null) {
        return;
      }
      var impFile = result.files.single.path!;
      var snack = Snack(context: this.context);
      final ProgressDialog pd = ProgressDialog(context: this.context);
      pd.show(max: 1, msg: 'importing database...');

      var ok = await DatabaseHelper.db.importDatabase(impFile);
      if (ok) {
        MyFS.deleteMangas();
        var mangas = await DatabaseHelper.db.getMangas();
        final dio = Dio();
        try {
          for (var manga in mangas) {
            await MyFS.downloadMangaCover(
                dio, manga.scraperID, manga.folder, manga.img);
          }
        } finally {
          dio.close();
        }
        snack.show('Database imported from $impFile');
      } else {
        snack.show('No permission granted');
      }
      pd.close();
      await _load();
    });
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
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'download':
                  _confirmAllDownload();
                  break;
                case 'recycle':
                  _scrubAllMangas();
                  break;
                case 'refresh':
                  _lookForAllNewChapters();
                  break;
                case 'rescan':
                  _rescanAllAndLookForNewChapters();
                  break;
                case 'sortByName':
                  _toggleSortByName();
                  break;
                case 'export':
                  _exportData();
                  break;
                case 'import':
                  _importData();
                  break;
              }
            },
            itemBuilder: (context) {
              return [
                const PopupMenuItem(
                  value: 'refresh',
                  child: ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Refresh'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'rescan',
                  child: ListTile(
                    leading: Icon(Icons.document_scanner_outlined),
                    title: Text('Rescan'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'download',
                  child: ListTile(
                    leading: Icon(Icons.download),
                    title: Text('Download'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'recycle',
                  child: ListTile(
                    leading: Icon(Icons.recycling),
                    title: Text('Recycle'),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'sortByName',
                  child: ListTile(
                    leading: _sortByName ? const Icon(Icons.check_box_outlined) : const Icon(Icons.check_box_outline_blank),
                    title: const Text('Sort by name'),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.save),
                    title: Text('Export'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.file_open),
                    title: Text('Import'),
                  ),
                ),
              ];
            },
          ),
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
          return ColoredBox(
            color:
                _lastRead == manga.id ? Colors.lightBlue.shade50 : Colors.white,
            child: InkWell(
                onTap: () {
                  _readManga(manga.id);
                },
                child: IntrinsicHeight(
                    child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    const SizedBox(
                      width: 4,
                    ),
                    FutureBuilder<File>(
                      future: MyFS.loadMangaCover(
                          Dio(), manga.scraperID, manga.folder, manga.img),
                      builder:
                          (BuildContext context, AsyncSnapshot<File> snapshot) {
                        if (snapshot.hasData) {
                          return Image.file(
                            snapshot.requireData,
                            height: 108,
                            width: 73,
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
                            Expanded(
                              child: Text(
                                manga.bookmarkedChapter,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('Last: '),
                            Expanded(
                              child: Text(
                                manga.lastChapter +
                                    (manga.missingDownloads > 0
                                        ? ' (${manga.missingDownloads})'
                                        : ''),
                                style: TextStyle(
                                  fontWeight: manga.bookmarkedChapter !=
                                          manga.lastChapter
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: manga.missingDownloads > 0
                                      ? Colors.orange
                                      : (manga.bookmarkedChapter !=
                                              manga.lastChapter
                                          ? Colors.green
                                          : Colors.black),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Last updated: ${_formatDate(manga)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          'source: ${manga.scraperID}',
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
                          case 'refresh':
                            _lookForNewChapters(manga);
                            break;
                          case 'drop_reload':
                            _dropAndReload(context, manga);
                            break;
                          // default:
                          //   throw UnimplementedError();
                        }
                      },
                      itemBuilder: (context) {
                        return [
                          const PopupMenuItem(
                            value: 'set_bookmarked',
                            child: ListTile(
                              leading: Icon(Icons.bookmark),
                              title: Text('Select Current'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'refresh',
                            child: ListTile(
                              leading: Icon(Icons.refresh),
                              title: Text('Refresh'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'drop_reload',
                            child: ListTile(
                              leading: Icon(Icons.restart_alt_outlined),
                              title: Text('Drop & Reload'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'download',
                            child: ListTile(
                              leading: const Icon(Icons.download),
                              title: Text(
                                  'Download${manga.missingDownloads > 0 ? ' (${manga.missingDownloads})' : ''}'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'recycle',
                            child: ListTile(
                              leading: Icon(Icons.recycling),
                              title: Text('Recycle'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete),
                              title: Text('Delete'),
                            ),
                          ),
                        ];
                      },
                    )
                  ],
                ))),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => NavigationService()
            .navigateToScreen(const SearchPage())
            .then((value) => _load()),
        tooltip: 'Add new Manga',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  _confirm(String message, VoidCallback okFunc) async {
    return showDialog<void>(
      context: this.context,
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
