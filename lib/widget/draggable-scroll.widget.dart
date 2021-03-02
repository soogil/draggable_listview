import 'dart:async';
import 'package:draggable_listview/listview/draggable-listview.widget.dart';
import 'package:draggable_listview/listview/draggable-scroll-label.widget.dart';
import 'package:draggable_listview/listview/indexed_scroll_view.dart';
import 'package:draggable_listview/widget/slide-fade.widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';


typedef Widget ScrollThumbBuilder(Animation<double> thumbAnimation);

class DraggableScrollbar extends StatefulWidget {

  DraggableScrollbar({
    Key key,
    Key scrollThumbKey,
    bool alwaysVisibleScrollThumb = false,
    @required this.draggableListView,
    @required this.thumbWidget,
    @required this.controller,
    @required this.scrollLabelBuilder,
    this.scrollLabelPosition = Alignment.topRight,
    this.scrollbarAnimationDuration = const Duration(milliseconds: 800),
    this.scrollbarTimeToFade = const Duration(milliseconds: 600),
  })  : assert(draggableListView.scrollDirection == Axis.vertical),
        assert(draggableListView != null),
        assert(controller != null),
        assert(scrollLabelBuilder != null),
        assert(thumbWidget != null),
        scrollThumbBuilder = _thumbSemicircleBuilder(thumbWidget, scrollThumbKey, alwaysVisibleScrollThumb),
        super(key: key);

  final DraggableListView draggableListView;

  final ScrollThumbBuilder scrollThumbBuilder;

  final ScrollLabelBuilder scrollLabelBuilder;

  final PreferredSize thumbWidget;

  final Duration scrollbarAnimationDuration;

  final Duration scrollbarTimeToFade;

  final AutoScrollController controller;

  final Alignment scrollLabelPosition;

  @override
  _DraggableScrollbarState createState() => _DraggableScrollbarState();

  static buildScrollThumbAndLabel({
    @required Widget scrollThumb,
    @required Animation<double> thumbAnimation,
    @required bool alwaysVisibleScrollThumb,
  }) {

    if (alwaysVisibleScrollThumb) {
      return scrollThumb;
    }

    return SlideFadeTransition(
      animation: thumbAnimation,
      child: scrollThumb,
    );
  }

  static ScrollThumbBuilder _thumbSemicircleBuilder(
      Widget thumbWidget, Key scrollThumbKey, bool alwaysVisibleScrollThumb,) {
    return (Animation<double> thumbAnimation,) {
      return buildScrollThumbAndLabel(
        scrollThumb: thumbWidget,
        thumbAnimation: thumbAnimation,
        alwaysVisibleScrollThumb: alwaysVisibleScrollThumb,
      );
    };
  }
}

class _DraggableScrollbarState extends State<DraggableScrollbar> with TickerProviderStateMixin {
  
  double _barOffset;
  double _viewOffset;
  bool _isDragInProcess;
  bool _isTapInProcess;

  double _tmpBarOffset = 0.0;
  int _correctionCount = 0;
  DateTime _dragStartDateTime;

  AnimationController _thumbAnimationController;
  Animation<double> _thumbAnimation;
  Timer _fadeoutTimer;

  @override
  void initState() {
    super.initState();
    _barOffset = 0.0;
    _viewOffset = 0.0;
    _isDragInProcess = false;
    _isTapInProcess = false;

    _thumbAnimationController = AnimationController(
      vsync: this,
      duration: widget.scrollbarAnimationDuration,
    );

    _thumbAnimation = CurvedAnimation(
      parent: _thumbAnimationController,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    _thumbAnimationController.dispose();
    _fadeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget scrollLabel;
    if (_isDragInProcess || _isTapInProcess) {
      scrollLabel = widget.scrollLabelBuilder(_thumbAnimation);
    }

    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              _changePosition(notification);
              return false;
            },
            child: Stack(
              children: <Widget>[
                RepaintBoundary(
                  child: widget.draggableListView,
                ),
                RepaintBoundary(
                  child: Container(
                      alignment: widget.scrollLabelPosition,
                      child: scrollLabel
                  ),
                ),
                RepaintBoundary(
                    child: GestureDetector(
                      onTap: (){
                        if(_isTapInProcess && _fadeoutTimer != null)
                          return;

                        setState(() {
                          _isTapInProcess = true;
                          if (_thumbAnimationController.status != AnimationStatus.forward) {
                            _thumbAnimationController.forward().whenComplete((){
                              _isTapInProcess = false;
                              Future.delayed(Duration(milliseconds: 500)).then((_){
                              _thumbAnimationController.reverse();
                            });
                            });
                          }
                        });
                      },
                      onVerticalDragStart: _onVerticalDragStart,
                      onVerticalDragUpdate: _onVerticalDragUpdate,
                      onVerticalDragEnd: _onVerticalDragEnd,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 100),
                        alignment: Alignment.topRight,
                        margin: EdgeInsets.only(top: _barOffset),
                        child: widget.scrollThumbBuilder(_thumbAnimation),
                      ),
                    )
                ),
              ],
            ),
          );
        }
     );
  }

  _changePosition(ScrollNotification notification) {
    if (_isDragInProcess) return;

    setState(() {
      if (notification is ScrollUpdateNotification) {

        final double barScaleFactor = barMaxScrollExtent / viewMaxScrollExtent;
        final double scrollScaleFactor = viewMaxScrollExtent / widget.controller.position.maxScrollExtent;

        _barOffset = widget.controller.offset * barScaleFactor * scrollScaleFactor;

        if (_barOffset < barMinScrollExtent) {
          _barOffset = barMinScrollExtent;
        }
        if (_barOffset > barMaxScrollExtent) {
          _barOffset = barMaxScrollExtent;
        }

        _viewOffset += notification.scrollDelta;

        if (_viewOffset < viewMinScrollExtent) {
          _viewOffset = viewMinScrollExtent;
        }
        if (_viewOffset > widget.controller.position.maxScrollExtent) {
          _viewOffset = widget.controller.position.maxScrollExtent;
        }

        widget.controller.offsetToIndex(_viewOffset + widget.thumbWidget.preferredSize.height / 2, _barOffset);
      }

      if (notification is ScrollUpdateNotification ||
          notification is OverscrollNotification) {
        if (_thumbAnimationController.status != AnimationStatus.forward) {
          _thumbAnimationController.forward();
        }

        _fadeoutTimer?.cancel();
        _fadeoutTimer = Timer(widget.scrollbarTimeToFade, () {
          _thumbAnimationController.reverse();
          _fadeoutTimer = null;
        });
      }
    });
  }

  double _getScrollViewDelta(double barDelta, double barMaxScrollExtent, double viewMaxScrollExtent,) =>
      barDelta * viewMaxScrollExtent / barMaxScrollExtent;

  _onVerticalDragStart(DragStartDetails details) {
    setState(() {
      _isDragInProcess = true;
      _fadeoutTimer?.cancel();
    });

    _dragStartDateTime = DateTime.now();
    _correctionCount = 1;
    _tmpBarOffset = _barOffset;
  }

  _onVerticalDragUpdate(DragUpdateDetails details){
    _changePositionByBar(details.delta.dy);
    _correctionCount++;
  }

  _changePositionByBar(double dy, [int cIdx = 0]) async{
    Completer completer = Completer();

    _isDragInProcess = true;
    setState(() {
      if (_thumbAnimationController.status != AnimationStatus.forward) {
        _thumbAnimationController.forward();
      }

      if (_isDragInProcess) {
        _barOffset += (dy);

        if (_barOffset < barMinScrollExtent) {
          _barOffset = barMinScrollExtent;
        }
        if (_barOffset > barMaxScrollExtent) {
          _barOffset = barMaxScrollExtent;
        }

        double viewDelta = _getScrollViewDelta(
            dy, barMaxScrollExtent, viewMaxScrollExtent);

        double newScrollDelta = (viewDelta / viewMaxScrollExtent)
            * widget.controller.position.maxScrollExtent;

        _viewOffset = widget.controller.position.pixels + newScrollDelta;

        if (_viewOffset < viewMinScrollExtent) {
          _viewOffset = viewMinScrollExtent;
        }
        if (_viewOffset > widget.controller.position.maxScrollExtent) {
          _viewOffset = widget.controller.position.maxScrollExtent;
        }

        if(cIdx == 0) {
          widget.controller.jumpTo(_viewOffset);
          widget.controller.offsetToIndex(_viewOffset + widget.thumbWidget.preferredSize.height / 2, _barOffset);
          completer.complete();
        } else {
          widget.controller.animateTo(_viewOffset, duration: Duration(milliseconds: (100 / cIdx).ceil()), curve: Curves.ease).then((_) {
            widget.controller.offsetToIndex(_viewOffset + widget.thumbWidget.preferredSize.height / 2,  _barOffset);
            completer.complete();
          });
        }
      }
    });

    return completer.future;
  }

  _onVerticalDragEnd(DragEndDetails details) async {
    if(details == null) return;

    final DateTime dragFinishDateTime = DateTime.now();
    final velocity  = ((_barOffset - _tmpBarOffset) / ((dragFinishDateTime.millisecondsSinceEpoch - _dragStartDateTime.millisecondsSinceEpoch))).abs();
    final double distance = (_barOffset - _tmpBarOffset) / _correctionCount;
    final int countScaleFactor = 15;
    final int unitCount = velocity.ceil() * countScaleFactor;

    for(int i = 1; i <= unitCount; i ++) {
      await _changePositionByBar(distance / i, i);
    }

    _hideIndexList();
  }

  _hideIndexList() {
    _isDragInProcess = false;
    _fadeoutTimer?.cancel();
    _fadeoutTimer = Timer(widget.scrollbarTimeToFade, () {
      _thumbAnimationController?.reverse();
      _fadeoutTimer = null;
    });
  }

  double get barMaxScrollExtent => context.size.height - widget.thumbWidget.preferredSize.height;

  double get barMinScrollExtent => 0.0;

  double get viewMaxScrollExtent => widget.controller.maxScrollExtent();

  double get viewMinScrollExtent => widget.controller.position.minScrollExtent;
}
