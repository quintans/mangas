import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manganato/models/persistence.dart';
import 'package:manganato/services/filesystem.dart';
import 'package:manganato/services/persistence.dart';

class ReaderPage extends StatefulWidget {
  final int mangaID;

  const ReaderPage({
    Key? key,
    required this.mangaID,
  }) : super(key: key);

  @override
  State<ReaderPage> createState() => _ReaderPage();
}

const double _bottomNavBarHeight = 60;

class _ReaderPage extends State<ReaderPage> with RouteAware {
  bool fullScreen = true;
  bool showBars = false;

  final _controller = ScrollController();

  Manga? manga;
  Chapter? chapter;

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

    DatabaseHelper.db.getManga(widget.mangaID).then((value) {
      setState(() {
        manga = value;
        chapter = manga!.getBookmarkedChapter();
      });
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
    return Scaffold(
        appBar: showBars
            ? AppBar(
                toolbarHeight: 120,
                title: Row(
                  children: [
                    Expanded(child: Text(manga?.title ?? '', maxLines: 3,),),
                    Column(
                      children: [
                        DropdownButton<Chapter>(
                          value: chapter,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                          ),
                          onChanged: (Chapter? newValue) {
                            setState(() {
                              chapter = newValue;
                              manga?.bookmark(chapter!);
                              DatabaseHelper.db.updateManga(manga!);
                            });
                          },
                          underline: Container(
                            height: 3,
                            color: Colors.white,
                          ),
                          selectedItemBuilder: (BuildContext context) {
                            return manga!
                                .getChapters()
                                .reversed
                                .map<Widget>((Chapter value) {
                              return Text(
                                value.title,
                                style: const TextStyle(color: Colors.white),
                              );
                            }).toList();
                          },
                          items: manga
                              ?.getChapters()
                              .reversed
                              .map((Chapter chapter) {
                            return DropdownMenuItem(
                              value: chapter,
                              child: Text(chapter.title,
                                  style: TextStyle(color: chapter.isDownloaded() ? Colors.black : Colors.grey)),
                            );
                          }).toList(),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios),
                              onPressed: manga?.hasPreviousChapter(chapter!) ??
                                  false
                                  ? () {
                                setState(() {
                                  _controller.jumpTo(0);
                                  chapter =
                                      manga!.moveToPreviousChapter(chapter!);
                                  DatabaseHelper.db.updateManga(manga!);
                                });
                              }
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios),
                              onPressed: manga?.hasNextChapter(chapter!) ?? false
                                  ? () {
                                setState(() {
                                  _controller.jumpTo(0);
                                  chapter =
                                      manga!.moveToNextChapter(chapter!);
                                  DatabaseHelper.db.updateManga(manga!);
                                });
                              }
                                  : null,
                            ),
                          ],
                        )
                      ],
                    ),
                  ],
                ))
            : null,
        body: InkWell(
            onTap: _toggleFullscreen,
            child: ListView.builder(
              padding: EdgeInsets.only(
                  bottom: fullScreen
                      ? 2 * _bottomNavBarHeight
                      : 3 * _bottomNavBarHeight),
              itemCount: chapter?.imgCnt ?? 0,
              itemBuilder: (context, index) {
                return FutureBuilder<File>(
                  future:
                      MyFS.loadChapterImage(manga!.src, chapter!.src, index),
                  builder:
                      (BuildContext context, AsyncSnapshot<File> snapshot) {
                    if (snapshot.hasData) {
                      return Image.file(snapshot.requireData);
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
                );
              },
              controller: _controller,
            )),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _scrollUp();
        },
        backgroundColor: Colors.blueGrey.withOpacity(0.3),
        child: const Icon(Icons.arrow_upward),
      ),
    );
  }
}
