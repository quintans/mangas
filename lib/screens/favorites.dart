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

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  State<FavoritesPage> createState() => _FavoritesPage();
}

class _FavoritesPage extends State<FavoritesPage> {
  final String _lastReadKey = 'last_read';
  final String _currentReadKey = 'current_read';
  static const int _downloadThreshold = 10;

  List<MangaView> mangas = [];
  int _lastRead = -1;

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    var prefs = await SharedPreferences.getInstance();
    /*
    var current = prefs.getInt(_currentReadKey);
    if (current != null) {
      _readManga(current);
      return;
    }
     */

    var last = prefs.getInt(_lastReadKey);

    DatabaseHelper.db.getMangaReadingOrder().then((value) {
      // check if file exists in FS
      setState(() {
        mangas = value;
        _lastRead = last ?? -1;
      });
    });
  }

  _readManga(int mangaID) async {
    var prefs = await SharedPreferences.getInstance();
    prefs.setInt(_lastReadKey, mangaID);
    prefs.setInt(_currentReadKey, mangaID);

    DatabaseHelper.db.getManga(mangaID).then((value) => NavigationService()
            .navigateToScreen(ReaderPage(
          manga: value!,
        ))
            .then((value) {
          prefs.remove(_currentReadKey);
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
    var snack = Snack(context: this.context);
    final ProgressDialog pd = ProgressDialog(context: this.context);

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

    var scraper = Scrapers.getScraper(manga.scraperID);
    for (var ch in chapters) {
      var imgs = await scraper.chapterImages(ch.src);
      List<Future<File>> futures = [];
      for (var i = 0; i < imgs.length; i++) {
        var f = MyFS.downloadChapterImages(
            manga.scraperID, manga.folder, ch.folder, i, imgs[i]);
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
        _load().then(
            (value) => MyFS.deleteManga(mangaView.scraperID, mangaView.folder));
      });
    });
  }

  Future<void> _lookForAllNewChapters() async {
    var mng = await DatabaseHelper.db.getMangas();
    _lookForNewChaptersInMangas(mng);
  }

  Future<void> _lookForNewChapters(MangaView manga) async {
    var mng = await DatabaseHelper.db.getManga(manga.id);
    _lookForNewChaptersInMangas([mng!]);
  }

  Future<void> _lookForNewChaptersInMangas(List<Manga> mng) async {
    var snack = Snack(context: this.context);
    final ProgressDialog pd = ProgressDialog(context: this.context);
    pd.show(max: mng.length, msg: 'Looking for new chapters...');

    var count = 0;
    for (var m in mng) {
      var scraper = Scrapers.getScraper(m.scraperID);
      var last = m.getChapters().last;
      var newChapters = await scraper.chapters(m);
      for (var r in newChapters) {
        m.addChapter(Chapter(
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
      if (newChapters.isNotEmpty) {
        await DatabaseHelper.db.updateManga(m);
      }
      pd.update(value: ++count);
    }
    snack.show('Finished looking for new chapters');
    _load();
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
      DatabaseHelper.db.updateManga(manga);
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
        for (var manga in mangas) {
          await MyFS.downloadMangaCover(
              manga.scraperID, manga.folder, manga.img);
        }
        snack.show('Database imported from $impFile');
      } else {
        snack.show('No permission granted');
      }
      pd.close();
      _load();
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
                          manga.scraperID, manga.folder, manga.img),
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
