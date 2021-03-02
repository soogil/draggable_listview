import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter/animation.dart';

const defaultScrollDistanceOffset = 100.0;
const defaultDurationUnit = 40;

const _millisecond = Duration(milliseconds: 1);
const _highlightDuration = const Duration(seconds: 3);
const scrollAnimationDuration = Duration(milliseconds: 250);

typedef Rect ViewportBoundaryGetter();
typedef double AxisValueGetter(Rect rect);

Rect defaultViewportBoundaryGetter() => Rect.zero;
abstract class AutoScrollController implements ScrollController {
  factory AutoScrollController({
    double initialScrollOffset: 0.0,
    bool keepScrollOffset: true,
    double suggestedRowHeight,
    ViewportBoundaryGetter viewportBoundaryGetter: defaultViewportBoundaryGetter,
    Axis axis,
    String debugLabel,
    AutoScrollController copyTagsFrom
  }) {
    return SimpleAutoScrollController(
        initialScrollOffset: initialScrollOffset,
        keepScrollOffset: keepScrollOffset,
        suggestedRowHeight: suggestedRowHeight,
        viewportBoundaryGetter: viewportBoundaryGetter,
        beginGetter: axis == Axis.horizontal ? (r) => r.left : (r) => r.top,
        endGetter: axis == Axis.horizontal ? (r) => r.right : (r) => r.bottom,
        copyTagsFrom: copyTagsFrom,
        debugLabel: debugLabel
    );
  }

  double get suggestedRowHeight;

  ViewportBoundaryGetter get viewportBoundaryGetter;

  AxisValueGetter get beginGetter;

  AxisValueGetter get endGetter;

  bool get isAutoScrolling;

  Map<int, AutoScrollTagState> get tagMap;

  Map<int, double> get sizedMap;

  bool get hasParentController;

  int get currentIndex;

  Future scrollToIndex(int index, {Duration duration: scrollAnimationDuration,
    AutoScrollPosition preferPosition});
  Future highlight(int index, {bool cancelExistHighlights: true,
    Duration highlightDuration: _highlightDuration, bool animated: true});
  void cancelAllHighlights();

  bool isIndexStateInLayoutRange(int index);

  double maxScrollExtent();

  offsetToIndex(double offset, double barOffset);
}

class SimpleAutoScrollController extends ScrollController with AutoScrollControllerMixin {
  @override
  final double suggestedRowHeight;
  @override
  final ViewportBoundaryGetter viewportBoundaryGetter;
  @override
  final AxisValueGetter beginGetter;
  @override
  final AxisValueGetter endGetter;

  SimpleAutoScrollController({
    double initialScrollOffset: 0.0,
    bool keepScrollOffset: true,
    this.suggestedRowHeight,
    this.viewportBoundaryGetter: defaultViewportBoundaryGetter,
    @required this.beginGetter,
    @required this.endGetter,
    AutoScrollController copyTagsFrom,
    String debugLabel
  }) : super(initialScrollOffset: initialScrollOffset, keepScrollOffset: keepScrollOffset, debugLabel: debugLabel) {
    if (copyTagsFrom != null)
      tagMap.addAll(copyTagsFrom.tagMap);

  }
}

class PageAutoScrollController extends PageController with AutoScrollControllerMixin {
  @override
  final double suggestedRowHeight;
  @override
  final ViewportBoundaryGetter viewportBoundaryGetter;
  @override
  final AxisValueGetter beginGetter = (r) => r.left;
  @override
  final AxisValueGetter endGetter = (r) => r.right;

  PageAutoScrollController({
    int initialPage: 0,
    bool keepPage: true,
    double viewportFraction: 1.0,
    this.suggestedRowHeight,
    this.viewportBoundaryGetter: defaultViewportBoundaryGetter,
    AutoScrollController copyTagsFrom,
    String debugLabel
  }) : super(initialPage: initialPage, keepPage: keepPage, viewportFraction: viewportFraction) {
    if (copyTagsFrom != null)
      tagMap.addAll(copyTagsFrom.tagMap);
  }
}

enum AutoScrollPosition {begin, middle, end}
mixin AutoScrollControllerMixin on ScrollController implements AutoScrollController {
  @override
  final SplayTreeMap<int, AutoScrollTagState> tagMap = SplayTreeMap<int, AutoScrollTagState>();

  final SplayTreeMap<int, double> sizedMap = SplayTreeMap<int, double>();

  double get suggestedRowHeight;
  ViewportBoundaryGetter get viewportBoundaryGetter;
  AxisValueGetter get beginGetter;
  AxisValueGetter get endGetter;
  int _currentIndex = 0;

  bool __isAutoScrolling = false;
  set _isAutoScrolling(bool isAutoScrolling) {
    __isAutoScrolling = isAutoScrolling;
    if (!isAutoScrolling && hasClients) //after auto scrolling, we should sync final scroll position without flag on
      notifyListeners();
  }
  @override
  bool get isAutoScrolling => __isAutoScrolling;

  ScrollController _parentController;
  @override
  set parentController(ScrollController parentController) {
    if (_parentController == parentController)
      return;

    final isNotEmpty = positions.isNotEmpty;
    if (isNotEmpty && _parentController != null) {
      for (final p in _parentController.positions)
        if (positions.contains(p))
          _parentController.detach(p);
    }

    _parentController = parentController;

    if (isNotEmpty && _parentController != null)
      for (final p in positions)
        _parentController.attach(p);
  }

  @override
  bool get hasParentController => _parentController != null;

  @override
  void attach(ScrollPosition position) {
    super.attach(position);

    _parentController?.attach(position);
  }

  @override
  void detach(ScrollPosition position) {
    _parentController?.detach(position);

    super.detach(position);
  }

  static const maxBound = 30; // 0.5 second if 60fps

  @override
  Future scrollToIndex(int index, {Duration duration: scrollAnimationDuration,
    AutoScrollPosition preferPosition}) async {
    return co(this, () => _scrollToIndex(index, duration: duration, preferPosition: preferPosition));
  }

  Future _scrollToIndex(int index, {Duration duration: scrollAnimationDuration, AutoScrollPosition preferPosition}) async {
    assert(duration > Duration.zero);

    Future makeSureStateIsReady() async {
      for (var count = 0; count < maxBound; count++) {
        if (_isEmptyStates) {
          await _waitForWidgetStateBuild();
        } else
          return null;
      }

      return null;
    }

    await makeSureStateIsReady();

    if (index == null || !hasClients)
      return null;

    // two cases,
    // 1. already has state. it's in viewport layout
    // 2. doesn't have state yet. it's not in viewport so we need to start scrolling to make it into layout range.
    if (isIndexStateInLayoutRange(index)) {
      _isAutoScrolling = true;

      await _bringIntoViewportIfNeed(index, preferPosition, (double offset) async {
        await animateTo(offset, duration: duration, curve: Curves.ease);
        await _waitForWidgetStateBuild();
        return null;
      });

      _isAutoScrolling = false;
    } else {
      // the idea is scrolling based on either
      // 1. suggestedRowHeight or
      // 2. testDistanceOffset
      double prevOffset = offset - 1;
      double currentOffset = offset;
      bool contains = false;
      Duration spentDuration = const Duration();
      double lastScrollDirection = 0.5; // alignment, default center;
      final moveDuration = duration ~/ defaultDurationUnit;

      _isAutoScrolling = true;
      /// ideally, the suggest row height will move to the final corrent offset approximately in just one scroll(iteration).
      /// if the given suggest row height is the minimal/maximal height in variable row height enviroment,
      /// we can just use viewport calculation to reach the final offset in other iteration.
      bool usedSuggestedRowHeightIfAny = true;
      while (prevOffset != currentOffset && !(contains = isIndexStateInLayoutRange(index))) {
        prevOffset = currentOffset;
        final nearest = _getNearestIndex(index);
        final moveTarget = _forecastMoveUnit(index, nearest, usedSuggestedRowHeightIfAny);
        if (moveTarget < 0)//can't forecast the move range
          return null;
        // assume suggestRowHeight will move to correct offset in just one time.
        // if the rule doesn't work (in variable row height case), we will use backup solution (non-suggested way)
        final suggestedDuration = usedSuggestedRowHeightIfAny && suggestedRowHeight != null ? duration : null;
        usedSuggestedRowHeightIfAny = false;// just use once
        lastScrollDirection = moveTarget - prevOffset > 0 ? 1 : 0;
        currentOffset = moveTarget;
        spentDuration += suggestedDuration ?? moveDuration;
        final oldOffset = offset;
        await animateTo(currentOffset, duration: suggestedDuration ?? moveDuration, curve: Curves.ease);
        await _waitForWidgetStateBuild();
        if (!hasClients || offset == oldOffset) { // already scroll to begin or end
          contains = isIndexStateInLayoutRange(index);
          break;
        }
      }
      _isAutoScrolling = false;

      if (contains && hasClients) {
        await _bringIntoViewportIfNeed(index, preferPosition ?? _alignmentToPosition(lastScrollDirection), (finalOffset) async {
          if (finalOffset != offset) {
            _isAutoScrolling = true;
            final remaining = duration - spentDuration;
            await animateTo(finalOffset, duration: remaining <= Duration.zero ? _millisecond : remaining, curve: Curves.ease);
            await _waitForWidgetStateBuild();

            // not sure why it doesn't scroll to the given offset, try more within 3 times
            if (hasClients && offset != finalOffset) {
              final count = 3;
              for (var i = 0; i < count && hasClients && offset != finalOffset; i++) {
                await animateTo(finalOffset, duration: _millisecond, curve: Curves.ease);
                await _waitForWidgetStateBuild();
              }
            }
            _isAutoScrolling = false;
          }
        });
      }
    }

    return null;
  }

  @override
  Future highlight(int index, {bool cancelExistHighlights: true,
    Duration highlightDuration: _highlightDuration, bool animated: true}) async {
    final tag = tagMap[index];
    return tag == null ? null : await tag.highlight(cancelExisting: cancelExistHighlights, highlightDuration: highlightDuration, animated: animated);
  }

  @override
  void cancelAllHighlights() {
    _cancelAllHighlights();
  }

  @override
  bool isIndexStateInLayoutRange(int index) => tagMap[index] != null;
  bool get _isEmptyStates => tagMap.isEmpty;

  Future _waitForWidgetStateBuild() => SchedulerBinding.instance.endOfFrame;

  double _forecastMoveUnit(int targetIndex, int currentNearestIndex, bool useSuggested) {
    assert(targetIndex != currentNearestIndex);
    currentNearestIndex = currentNearestIndex ?? 0; //null as none of state

    final alignment = targetIndex > currentNearestIndex ? 1.0 : 0.0;
    double absoluteOffsetToViewport;

    if (tagMap[currentNearestIndex] == null)
      return -1;

    if (useSuggested && suggestedRowHeight != null) {
      final indexDiff = (targetIndex - currentNearestIndex);
      final offsetToLastState = _offsetToRevealInViewport(currentNearestIndex, indexDiff <= 0 ? 0 : 1);
      absoluteOffsetToViewport = math.max(offsetToLastState.offset + indexDiff * suggestedRowHeight, 0);
    } else {
      final offsetToLastState = _offsetToRevealInViewport(currentNearestIndex, alignment);
      assert((offsetToLastState?.offset ?? 0) >= 0,
      "ERROR: %%%%%%%%%%%%%%: $targetIndex, $currentNearestIndex, $alignment, $offsetToLastState, ${tagMap.keys.toList().join(',')}");
      absoluteOffsetToViewport = offsetToLastState?.offset;
      if (absoluteOffsetToViewport == null)
        absoluteOffsetToViewport = defaultScrollDistanceOffset;
    }

    return absoluteOffsetToViewport;
  }

  int _getNearestIndex(int index) {
    final list = tagMap.keys;
    if (list.isEmpty)
      return null;

    final sorted = list.toList()..sort((int first, int second) => first.compareTo(second));
    final min = sorted.first;
    final max = sorted.last;
    return (index - min).abs() < (index - max).abs() ? min : max;
  }

  Future _bringIntoViewportIfNeed(int index, AutoScrollPosition preferPosition,
      Future move(double offset)) async {
    final begin = _directionalOffsetToRevealInViewport(index, 0);
    final end = _directionalOffsetToRevealInViewport(index, 1);

    if (preferPosition != null) {
      double targetOffset = _directionalOffsetToRevealInViewport(index, _positionToAlignment(preferPosition));

      if (targetOffset < position.minScrollExtent)
        targetOffset = position.minScrollExtent;
      else if (targetOffset > position.maxScrollExtent)
        targetOffset = position.maxScrollExtent;

      await move(targetOffset);
    } else {
      final alreadyInViewport = offset < begin && offset > end;
      if (!alreadyInViewport) {
        double value;
        if (preferPosition != null) {
          value = preferPosition == AutoScrollPosition.begin
              ? begin : preferPosition == AutoScrollPosition.end
              ? end : _directionalOffsetToRevealInViewport(index, 0.5);
        } else if ((end - offset).abs() < (begin - offset).abs())
          value = end;
        else
          value = begin;

        await move(value > 0 ? value : 0);
      }
    }
  }

  double _positionToAlignment(AutoScrollPosition position) {
    if (position == null)
      return null;

    return position == AutoScrollPosition.begin ? 0 : position == AutoScrollPosition.end ? 1 : 0.5;
  }

  AutoScrollPosition _alignmentToPosition(double alignment)
  => alignment == 0 ? AutoScrollPosition.begin : alignment == 1 ? AutoScrollPosition.end : AutoScrollPosition.middle;

  double _directionalOffsetToRevealInViewport(int index, double alignment) {
    assert(alignment == 0 || alignment == 0.5 || alignment == 1);
    assert(beginGetter != null && endGetter != null);
    // 1.0 bottom, 0.5 center, 0.0 begin if list is vertically from begin to end
    final tagOffsetInViewport = _offsetToRevealInViewport(index, alignment);

    double absoluteOffsetToViewport = tagOffsetInViewport?.offset;

    if (tagOffsetInViewport == null) {
      return -1;
    } else {
      if (alignment == 0.5) {
        return absoluteOffsetToViewport;
      } else if (alignment == 0) {
        return absoluteOffsetToViewport - beginGetter(viewportBoundaryGetter());
      } else {
        return absoluteOffsetToViewport + endGetter(viewportBoundaryGetter());
      }
    }
  }

  RevealedOffset _offsetToRevealInViewport(int index, double alignment) {
    final ctx = tagMap[index]?.context;
    if (ctx == null)
      return null;

    final renderBox = ctx.findRenderObject();
    final ScrollableState scrollableState = Scrollable.of(ctx);
    assert(scrollableState != null);
    final RenderAbstractViewport viewport = RenderAbstractViewport.of(renderBox);
    final revealedOffset = viewport.getOffsetToReveal(renderBox, alignment);

    return revealedOffset;
  }

  maxScrollExtent() {
    double maxExtent = 0.0;
    tagMap.forEach((key, value) {
      if (!sizedMap.containsKey(key)) {
        sizedMap[key] = _offsetToRevealInViewport(key, 0).rect.size.height;
      }
    });

    sizedMap.keys.toList().forEach((key) {
      maxExtent += sizedMap[key];
    });

    return maxExtent;
  }

  offsetToIndex(double viewOffset, double barOffset) {
    _currentIndex = 0;
    double maxExtent = 0.0;

//    print(sizedMap.keys.toList());
    for (int key in sizedMap.keys.toList()) {
      maxExtent += sizedMap[key];

      double remainSize = maxExtent - viewOffset;
      if (remainSize < barOffset) {
        _currentIndex = key + 1;
      }
    }
  }

  @override
  int get currentIndex => _currentIndex;
}

void _cancelAllHighlights([AutoScrollTagState state]) {
  for (final tag in _highlights.keys)
    tag._cancelController(reset: tag != state);

  _highlights.clear();
}

class AutoScrollTag extends StatefulWidget {
  final AutoScrollController controller;
  final int index;
  final Widget child;
  final Color color;
  final Color highlightColor;
  final bool disabled;

  AutoScrollTag({@required Key key, @required this.controller, @required this.index, @required
  this.child, this.color, this.highlightColor, this.disabled: false}) : super(key: key);

  @override
  AutoScrollTagState createState() {
    return new AutoScrollTagState<AutoScrollTag>();
  }
}

Map<AutoScrollTagState, AnimationController> _highlights = <AutoScrollTagState, AnimationController>{};
class AutoScrollTagState<W extends AutoScrollTag> extends State<W> with TickerProviderStateMixin {
  AnimationController _controller;

  @override
  void initState() {
    super.initState();
    if (!widget.disabled) {
      register(widget.index);
    }
  }

  @override
  void dispose() {
    _cancelController();
    if (!widget.disabled) {
      unregister(widget.index);
    }
    _controller = null;
    _highlights.remove(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(W oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index || oldWidget.key != widget.key || oldWidget.disabled != widget.disabled) {
      if (!oldWidget.disabled)
        unregister(oldWidget.index);

      if (!widget.disabled)
        register(widget.index);
    }
  }

  void register(int index) {
    widget.controller.tagMap[index] = this;
  }

  void unregister(int index) {
    _cancelController();
    _highlights.remove(this);
    if (widget.controller.tagMap[index] == this)
      widget.controller.tagMap.remove(index);
  }

  @override
  Widget build(BuildContext context) {
    return new DecoratedBoxTransition(
        decoration: new DecorationTween(
            begin: widget.color != null ?
            new BoxDecoration(color: widget.color) :
            new BoxDecoration(),
            end: widget.color != null ?
            new BoxDecoration(color: widget.color) :
            new BoxDecoration(color: widget.highlightColor)
        ).animate(_controller ?? kAlwaysDismissedAnimation),
        child: widget.child
    );
  }

  //used to make sure we will drop the old highlight
  //it's rare that we call it more than once in same millisecond, so we just make the time stamp as the unique key
  DateTime _startKey;
  /// this function can be called multiple times. every call will reset the highlight style.
  Future highlight({bool cancelExisting: true, Duration highlightDuration: _highlightDuration, bool animated: true}) async {
    if (!mounted)
      return null;

    if (cancelExisting) {
      _cancelAllHighlights(this);
    }

    if (_highlights.containsKey(this)) {
      assert(_controller != null);
      _controller.stop();
    }

    if (_controller == null) {
      _controller = new AnimationController(vsync: this);
      _highlights[this] = _controller;
    }

    final startKey0 = _startKey = DateTime.now();
    const animationShow = 1.0;
    setState((){});
    if (animated)
      await catchAnimationCancel(_controller.animateTo(animationShow, duration: scrollAnimationDuration));
    else
      _controller.value = animationShow;
    await Future.delayed(highlightDuration);

    if (startKey0 == _startKey) {
      if (mounted) {
        setState((){});
        const animationHide = 0.0;
        if (animated)
          await catchAnimationCancel(_controller.animateTo(animationHide, duration: scrollAnimationDuration));
        else
          _controller.value = animationHide;
      }

      if (startKey0 == _startKey) {
        _controller = null;
        _highlights.remove(this);
      }
    }
    return null;
  }

  void _cancelController({bool reset: true}) {
    if (_controller != null) {
      if (_controller.isAnimating)
        _controller.stop();

      if (reset && _controller.value != 0.0)
        _controller.value = 0.0;
    }
  }
}

Future<T> co<T>(key, FutureOr<T> action()) async {
  for (;;) {
    final c = _locks[key];
    if (c == null) break;
    try {
      await c.future;
    } catch (_) {} //ignore error (so it will continue)
  }

  final c = _locks[key] = new Completer<T>();
  void then(T result) {
    final c2 = _locks.remove(key);
    c.complete(result);

    assert(identical(c, c2));
  }
  void catchError(ex, StackTrace st) {
    final c2 = _locks.remove(key);
    c.completeError(ex, st);

    assert(identical(c, c2));
  }

  try {
    final result = action();
    if (result is Future<T>) {
      result
          .then(then)
          .catchError(catchError);
    } else {
      then(result as T);
    }
  } catch (ex, st) {
    catchError(ex, st);
  }

  return c.future;
}

final _locks = new HashMap<dynamic, Completer>();

/// skip the TickerCanceled exception
Future catchAnimationCancel(TickerFuture future) async {
  return future.orCancel.catchError((_) async {
    // do nothing, skip TickerCanceled exception
    return null;
  }, test: (ex) => ex is TickerCanceled);
}