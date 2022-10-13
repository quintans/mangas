import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mangas/models/persistence.dart';
import 'package:mangas/services/filesystem.dart';
import 'package:mangas/services/persistence.dart';

class ReaderPage extends StatefulWidget {
  final Manga manga;

  const ReaderPage({
    Key? key,
    required this.manga,
  }) : super(key: key);

  @override
  State<ReaderPage> createState() => _ReaderPage();
}

const double _bottomNavBarHeight = 60;

class _ReaderPage extends State<ReaderPage> with RouteAware {
  bool fullScreen = true;
  bool showBars = false;

  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();

    // Setup the listener.
    _controller.addListener(() {
      var atBottom = isAtTheBottom();
      if (showBars != atBottom) {
        setState(() {
          showBars = atBottom;
        });
      }
    });

    fullScreen = true;
    _enterFullScreen();
  }

  bool isAtTheBottom() {
    var pos = _controller.position;
    if (pos.pixels == pos.maxScrollExtent) {
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() {
      fullScreen = !fullScreen;
      if (fullScreen) {
        _enterFullScreen();
        showBars = isAtTheBottom();
      } else {
        _exitFullScreen();
        showBars = true;
      }
    });
  }

  void _enterFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _scrollUp() {
    _controller.animateTo(
      0,
      duration: const Duration(seconds: 2),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    var manga = widget.manga;
    var chapter = manga.getBookmarkedChapter();
    var subDir = chapter.src.split('/');
    List<Widget> widgets = [];
    for(var i =0; i < chapter.imgCnt; i++) {
      var w = Image.file(MyFS.loadChapterImage(
          subDir[subDir.length - 2], subDir.last, i),
        fit: BoxFit.fitWidth,
      );
      widgets.add(w);
    }

    return Scaffold(
      appBar: showBars
          ? AppBar(
              title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manga.title,
                ),
              ],
            ))
          : null,
      body: InkWell(
          onDoubleTap: _toggleFullscreen,
          child: ListView(
            padding: EdgeInsets.only(
                bottom: fullScreen
                    ? 2 * _bottomNavBarHeight
                    : 3 * _bottomNavBarHeight),
            controller: _controller,
            children: widgets,
          )),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _scrollUp();
        },
        backgroundColor: Colors.blueGrey.withOpacity(0.3),
        child: const Icon(Icons.arrow_upward),
      ),
      bottomNavigationBar: showBars
          ? BottomAppBar(
              color: Colors.indigo,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 6,
                    child: DropdownButton<Chapter>(
                      isExpanded: true,
                      value: chapter,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                      ),
                      onChanged: (Chapter? newValue) {
                        setState(() {
                          manga.bookmark(newValue!);
                          DatabaseHelper.db.updateManga(manga);
                        });
                      },
                      selectedItemBuilder: (BuildContext context) {
                        return manga
                            .getChapters()
                            .reversed
                            .map<Widget>((Chapter chapter) {
                          return Container(
                            alignment: Alignment.centerLeft,
                            constraints: const BoxConstraints(minWidth: 100),
                            child: Text(
                              chapter.title,
                              style: chapter.isDownloaded()
                                  ? const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)
                                  : const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList();
                      },
                      items:
                          manga.getChapters().reversed.map((Chapter chapter) {
                        return DropdownMenuItem(
                          value: chapter,
                          child: Text(chapter.title,
                              style: TextStyle(
                                  color: chapter.isDownloaded()
                                      ? Colors.black
                                      : Colors.grey)),
                        );
                      }).toList(),
                    ),
                  ),
                  Expanded(
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      color: Colors.white,
                      onPressed: manga.hasPreviousChapter(chapter)
                          ? () {
                              setState(() {
                                _controller.jumpTo(0);
                                chapter =
                                    manga.moveToPreviousChapter(chapter);
                                DatabaseHelper.db.updateManga(manga);
                              });
                            }
                          : null,
                    ),
                  ),
                  Expanded(
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      color: Colors.white,
                      onPressed: manga.hasNextChapter(chapter)
                          ? () {
                              setState(() {
                                _controller.jumpTo(0);
                                chapter = manga.moveToNextChapter(chapter);
                                DatabaseHelper.db.updateManga(manga);
                              });
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
