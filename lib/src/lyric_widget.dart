import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'lyric.dart';
import 'lyric_controller.dart';
import 'lyric_painter.dart';

class LyricWidget extends StatefulWidget {
  final List<Lyric> lyrics;
  final List<Lyric>? remarkLyrics;
  final Size size;
  final LyricController controller;
  TextStyle? lyricStyle;
  TextStyle? remarkStyle;
  TextStyle? currLyricStyle;
  TextStyle? currRemarkLyricStyle;
  TextStyle? draggingLyricStyle;
  TextStyle? draggingRemarkLyricStyle;
  final double lyricGap;
  final double remarkLyricGap;
  bool enableDrag;

  //歌词画笔数组
  List<TextPainter> lyricTextPaints = [];

  //翻译/音译歌词画笔数组
  List<TextPainter> subLyricTextPaints = [];

  //字体最大宽度
  double? lyricMaxWidth;

  LyricWidget(
      {Key? key,
      required this.lyrics,
      this.remarkLyrics,
      required this.size,
      required this.controller,
      this.lyricStyle,
      this.remarkStyle,
      this.currLyricStyle,
      this.lyricGap = 10,
      this.remarkLyricGap = 20,
      this.draggingLyricStyle,
      this.draggingRemarkLyricStyle,
      this.enableDrag = true,
      this.lyricMaxWidth,
      this.currRemarkLyricStyle})
      : assert(enableDrag != null),
        assert(lyrics != null && lyrics.isNotEmpty),
        assert(size != null),
        assert(controller != null) {
    this.lyricStyle ??= TextStyle(color: Colors.grey, fontSize: 14);
    this.remarkStyle ??= TextStyle(color: Colors.black, fontSize: 14);
    this.currLyricStyle ??= TextStyle(color: Colors.red, fontSize: 14);
    this.currRemarkLyricStyle ??= this.currLyricStyle;
    this.draggingLyricStyle ??= lyricStyle!.copyWith(color: Colors.greenAccent);
    this.draggingRemarkLyricStyle ??= remarkStyle!.copyWith(color: Colors.greenAccent);

    //歌词转画笔
    lyricTextPaints.addAll(lyrics
        .map(
          (l) =>
              TextPainter(text: TextSpan(text: l.lyric, style: lyricStyle), textAlign: TextAlign.center, textDirection: TextDirection.ltr),
        )
        .toList());

    //翻译/音译歌词转画笔
    if (remarkLyrics != null && remarkLyrics!.isNotEmpty) {
      subLyricTextPaints.addAll(remarkLyrics!
          .map((l) => TextPainter(text: TextSpan(text: l.lyric, style: remarkStyle), textDirection: TextDirection.ltr))
          .toList());
    }
  }

  @override
  _LyricWidgetState createState() => _LyricWidgetState();
}

class _LyricWidgetState extends State<LyricWidget> {
  LyricPainter? _lyricPainter;
  double totalHeight = 0;

  @override
  void initState() {
    widget.controller.draggingComplete = () {
      cancelTimer();
      widget.controller.progress = widget.controller.draggingProgress ?? const Duration();
      _lyricPainter?.draggingLine = null;
      widget.controller.isDragging = false;
    };
    WidgetsBinding.instance.addPostFrameCallback((call) {
      totalHeight = computeScrollY(widget.lyrics.length - 1);
    });
    widget.controller.addListener(_onControllerChange);

    var curLine = findLyricIndexByDuration(widget.controller.progress, widget.lyrics);
    animatingOffset = -computeScrollY(curLine);
    widget.controller.previousRowOffset = -animatingOffset;

    super.initState();
  }

  void _onControllerChange() {
    var curLine = findLyricIndexByDuration(widget.controller.progress, widget.lyrics);
    if (widget.controller.oldLine != curLine) {
      _lyricPainter?.currentLyricIndex = curLine;
      if (!widget.controller.isDragging) {
        if (widget.controller.vsync == null) {
          _lyricPainter?.offset = -computeScrollY(curLine);
        } else {
          animationScrollY(curLine, widget.controller.vsync);
        }
      }
      widget.controller.oldLine = curLine;
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  ///因空行高度与非空行高度不一致，获取非空行的位置
  int getNotEmptyLineHeight(List<Lyric> lyrics) =>
      lyrics.indexOf(lyrics.firstWhere((lyric) => lyric.lyric.trim().isNotEmpty, orElse: () => lyrics.first));

  void _initPainter() {
    _lyricPainter = LyricPainter(widget.lyrics, widget.lyricTextPaints, widget.subLyricTextPaints,
        vsync: widget.controller.vsync,
        subLyrics: widget.remarkLyrics,
        lyricTextStyle: widget.lyricStyle!,
        subLyricTextStyle: widget.remarkStyle!,
        currLyricTextStyle: widget.currLyricStyle!,
        lyricGapValue: widget.lyricGap,
        lyricMaxWidth: widget.lyricMaxWidth!,
        subLyricGapValue: widget.remarkLyricGap,
        draggingLyricTextStyle: widget.draggingLyricStyle!,
        draggingSubLyricTextStyle: widget.draggingRemarkLyricStyle!,
        currSubLyricTextStyle: widget.currRemarkLyricStyle!);
    _lyricPainter!.currentLyricIndex = findLyricIndexByDuration(widget.controller.progress, widget.lyrics);
    if (widget.controller.isDragging) {
      _lyricPainter!.draggingLine = widget.controller.draggingLine;
      _lyricPainter!.offset = widget.controller.draggingOffset;
    } else {
      _lyricPainter!.curLineScale = curLineScale;
      _lyricPainter!.prevLineScale = prevLineScale;
      _lyricPainter!.offset = animatingOffset;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyricMaxWidth == null || widget.lyricMaxWidth == double.infinity) {
      widget.lyricMaxWidth = MediaQuery.of(context).size.width;
    }
    _initPainter();
    return widget.enableDrag
        ? GestureDetector(
            onVerticalDragUpdate: (e) {
              cancelTimer();
              double temOffset = (_lyricPainter!.offset + e.delta.dy);
              if (temOffset < 0 && temOffset >= -totalHeight) {
                widget.controller.draggingOffset = temOffset;
                widget.controller.draggingLine = getCurrentDraggingLine(temOffset + widget.lyricGap);
                _lyricPainter!.draggingLine = widget.controller.draggingLine;
                widget.controller.draggingProgress =
                    widget.lyrics[widget.controller.draggingLine].startTime ?? Duration.zero + const Duration(milliseconds: 1);
                widget.controller.isDragging = true;
                _lyricPainter!.offset = temOffset;
              }
            },
            onVerticalDragEnd: (e) {
              cancelTimer();
              widget.controller.draggingTimer = Timer(widget.controller.draggingTimerDuration ?? const Duration(seconds: 3), () {
                resetDragging();
              });
            },
            child: buildCustomPaint(),
          )
        : buildCustomPaint();
  }

  Widget buildCustomPaint() {
    return RepaintBoundary(
        child: CustomPaint(
      painter: _lyricPainter,
      size: widget.size,
    ));
  }

  void resetDragging() {
    _lyricPainter?.currentLyricIndex = findLyricIndexByDuration(widget.controller.progress, widget.lyrics);

    widget.controller.previousRowOffset = -widget.controller.draggingOffset;
    animationScrollY(_lyricPainter!.currentLyricIndex, widget.controller.vsync);
    _lyricPainter?.draggingLine = null;
    widget.controller.isDragging = false;
  }

  int getCurrentDraggingLine(double offset) {
    for (int i = 0; i < widget.lyrics.length; i++) {
      var scrollY = computeScrollY(i);
      if (offset > -1) {
        offset = 0;
      }
      if (offset >= -scrollY) {
        return i;
      }
    }
    return widget.lyrics.length;
  }

  void cancelTimer() {
    if (widget.controller.draggingTimer != null) {
      if (widget.controller.draggingTimer!.isActive) {
        widget.controller.draggingTimer!.cancel();
        widget.controller.draggingTimer = null;
      }
    }
  }

  double animatingOffset = 0;
  double curLineScale = 1;
  double prevLineScale = 1;
  AnimationController? _animationController;
  animationScrollY(currentLyricIndex, TickerProvider tickerProvider) {
    if (_animationController != null && _animationController!.isAnimating) {
      _animationController!.stop();
    }
    _animationController = AnimationController(vsync: tickerProvider, duration: const Duration(milliseconds: 300))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationController?.dispose();
          _animationController = null;
        }
      });
    // 计算当前行偏移量
    var currentRowOffset = computeScrollY(currentLyricIndex);
    //如果偏移量相同不执行动画
    if (currentRowOffset == widget.controller.previousRowOffset) {
      return;
    }

    // 起始为上一行，结束点为当前行
    Animation animation = Tween<double>(begin: widget.controller.previousRowOffset, end: currentRowOffset).animate(_animationController!);
    final Animation<double> curve = CurvedAnimation(parent: _animationController!, curve: Interval(0, 1.0, curve: Curves.easeInOut));
    double bigFontSize = widget.currLyricStyle?.fontSize ?? 14;
    double smallFontSize = widget.lyricStyle?.fontSize ?? 14;
    Animation scaleDownAnimation = Tween<double>(begin: bigFontSize / smallFontSize, end: 1.0).animate(curve);
    Animation scaleUpAnimation = Tween<double>(begin: 1.0, end: bigFontSize / smallFontSize).animate(curve);
    widget.controller.previousRowOffset = currentRowOffset;
    _animationController!.addListener(() {
      _lyricPainter?.curLineScale = curLineScale = scaleUpAnimation.value;
      _lyricPainter?.prevLineScale = prevLineScale = scaleDownAnimation.value;
      _lyricPainter?.offset = animatingOffset = -animation.value;
    });
    _animationController!.forward();
  }

  //根据当前时长获取歌词位置
  int findLyricIndexByDuration(Duration curDuration, List<Lyric> lyrics) {
    for (int i = 0; i < lyrics.length; i++) {
      if (curDuration >= (lyrics[i].startTime ?? Duration.zero) && curDuration <= (lyrics[i].endTime ?? Duration.zero)) {
        return i;
      }
      if (i == lyrics.length - 1 && curDuration > (lyrics[i].endTime ?? Duration.zero)) {
        return i;
      }
    }
    return 0;
  }

  /// 计算传入行和第一行的偏移量
  double computeScrollY(int curLine) {
    double totalHeight = 0;
    for (var i = 0; i < curLine; i++) {
      var currPaint = widget.lyricTextPaints[i]..text = TextSpan(text: widget.lyrics[i].lyric, style: widget.lyricStyle);
      currPaint.layout(maxWidth: widget.lyricMaxWidth!);
      totalHeight += currPaint.height + widget.lyricGap;
    }
    if (widget.remarkLyrics != null) {
      //增加 当前行之前的翻译歌词的偏移量
      widget.remarkLyrics!
          .where((subLyric) => (subLyric.endTime ?? Duration.zero) <= (widget.lyrics[curLine].endTime ?? Duration.zero))
          .toList()
          .forEach((subLyric) {
        var currentPaint = widget.subLyricTextPaints[widget.remarkLyrics!.indexOf(subLyric)]
          ..text = TextSpan(text: subLyric.lyric, style: widget.remarkStyle);
        currentPaint.layout(maxWidth: widget.lyricMaxWidth!);
        totalHeight += widget.remarkLyricGap + currentPaint.height;
      });
    }
    return totalHeight;
  }
}
