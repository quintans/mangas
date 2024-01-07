import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      var atBottom = shouldShowBars();
      if (showBars != atBottom) {
        setState(() {
          showBars = atBottom;
        });
      }
    });

    fullScreen = true;
    _enterFullScreen();
  }

  bool shouldShowBars() {
    if (_controller.position.userScrollDirection == ScrollDirection.forward) {
      return true;
    }

    var after = _controller.position.extentAfter;
    if (!showBars && after == 0 || showBars && after < 210) {
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
        showBars = shouldShowBars();
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
      duration: const Duration(seconds: 1),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    var manga = widget.manga;
    var chapter = manga.getBookmarkedChapter();

    return Scaffold(
      appBar: showBars
          ? AppBar(
              centerTitle: true,
              toolbarHeight: 40,
              backgroundColor: Colors.indigo,
              foregroundColor:Colors.white,
              title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manga.title,
                  style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                ),
              ],
            ))
          : null,
      body: InkWell(
          onDoubleTap: _toggleFullscreen,
          child: ListView.builder(
            padding: EdgeInsets.only(
                bottom: fullScreen
                    ? 2 * _bottomNavBarHeight
                    : 3 * _bottomNavBarHeight),
            controller: _controller,
            itemCount: chapter.imgCnt,
            itemBuilder: (_, int index) {
              return KeepAliveBuilder(
                builder: (_) {
                  return Image.file(MyFS.loadChapterImage(
                    manga.scraperID,
                      manga.folder, chapter.folder, index));
                }
              );
              // );
            },
          )),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          _scrollUp();
        },
        backgroundColor: Colors.blueGrey.withOpacity(0.3),
        foregroundColor: Colors.white.withOpacity(0.5),
        child: const Icon(Icons.arrow_upward),
      ),
      bottomNavigationBar: showBars
          ? BottomAppBar(
              height: 60,
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

class KeepAliveBuilder extends StatefulWidget {
  final WidgetBuilder builder;

  const KeepAliveBuilder({super.key,
    required this.builder
  });

  @override
  State<KeepAliveBuilder> createState() => _KeepAliveBuilderState();
}

class _KeepAliveBuilderState extends State<KeepAliveBuilder> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Builder(
      builder: widget.builder,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
