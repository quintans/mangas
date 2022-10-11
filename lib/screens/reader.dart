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

class _ReaderPage extends State<ReaderPage> {
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
      setState(() {
        showBars = isAtTheBottom();
        if (!showBars) {
          return;
        }
        if (!manga!.isBookmarked(chapter!)) {
          manga!.bookmark(chapter!);
        }
      });
    });

    DatabaseHelper.db.getManga(widget.mangaID).then((value) {
      setState(() {
        manga = value;
        chapter = manga!.getViewedChapter();
        if (chapter != null) {
          chapter = manga!.nextChapter(chapter!);
        }
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
    if (manga != null) {
      DatabaseHelper.db.updateManga(manga!);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: showBars
            ? AppBar(
                toolbarHeight: 120,
                title: Column(
                  children: [
                    Row(
                      children: [
                        Text(manga?.title ?? ''),
                        const Spacer(),
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
                            });
                          },
                          underline: Container(
                            height: 3,
                            color: Colors.white,
                          ),
                          selectedItemBuilder: (BuildContext context) {
                            return manga!
                                .getDownloadedChapters()
                                .reversed
                                .map<Widget>((Chapter value) {
                              return Text(
                                value.title,
                                style: const TextStyle(color: Colors.white),
                              );
                            }).toList();
                          },
                          items: manga
                              ?.getDownloadedChapters()
                              .reversed
                              .map((Chapter chapter) {
                            return DropdownMenuItem(
                              value: chapter,
                              child: Text(chapter.title,
                                  style: const TextStyle(color: Colors.black)),
                            );
                          }).toList(),
                        )
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(manga?.isBookmarked(chapter!) ?? false ? Icons.remove_red_eye_outlined : Icons.remove_red_eye),
                          onPressed: () {
                            setState(() {
                              manga!.bookmark(chapter!);
                            });
                          },
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios),
                          onPressed: manga?.hasPreviousChapter(chapter!) ??
                                  false
                              ? () {
                                  setState(() {
                                    manga!.bookmark(chapter!);
                                    chapter = manga!.previousChapter(chapter!);
                                  });
                                }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios),
                          onPressed: manga?.hasNextChapter(chapter!) ?? false
                              ? () {
                                  setState(() {
                                    manga!.bookmark(chapter!);
                                    chapter = manga!.nextChapter(chapter!);
                                  });
                                }
                              : null,
                        ),
                      ],
                    )
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
            )));
  }
}
