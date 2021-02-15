import 'dart:math';
import 'package:draggable_listview/listview/draggable-listview.widget.dart';
import 'package:draggable_listview/listview/draggable-scroll-label.widget.dart';
import 'package:draggable_listview/listview/draggable-scroll.widget.dart';
import 'package:draggable_listview/listview/indexed_scroll_view.dart';
import 'package:flutter/material.dart';


class MainPageView extends StatelessWidget {

  final AutoScrollController autoScrollController =  AutoScrollController();
  final double itemHeight = 100;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _getAppBar(),
      body: _getBody(),
    );
  }

  _getAppBar() {
    return AppBar();
  }

  _getBody() {
    final List<double> randomList = [
      itemHeight + Random().nextInt(1000),
      itemHeight + Random().nextInt(1000),
      itemHeight + Random().nextInt(1000),
      itemHeight + Random().nextInt(1000),
      itemHeight + Random().nextInt(1000),
      itemHeight + Random().nextInt(1000),
      itemHeight + Random().nextInt(1000),
      itemHeight + Random().nextInt(1000),
      itemHeight + Random().nextInt(1000),
      itemHeight + Random().nextInt(1000),
      itemHeight + Random().nextInt(1000),
      itemHeight + Random().nextInt(1000),
      itemHeight + Random().nextInt(1000),
      itemHeight + Random().nextInt(1000),
      itemHeight + Random().nextInt(1000),
    ];

    return DraggableScrollbar(
        controller: autoScrollController,
        thumbWidget: _getThumbWidget(),
        alwaysVisibleScrollThumb: true,
        scrollLabelBuilder: (thumbAnimation) {
          return SlideFadeTransition(
            animation: thumbAnimation,
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.only(
                  right: 20
              ),
              child: DraggableScrollLabel(
                scrollLabelItemBuilder:  (index) {
                  final bool isSelect = index == autoScrollController.currentIndex;

                  return _getScrollLabelItem(index, isSelect);
                },
                listLength: randomList.length,
                autoScrollController: autoScrollController,
              ),
            ),
          );
        },
        draggableListView: DraggableListView(
          viewItemBuilder: (context, index) {
            return Container(
              height: randomList[index],
              alignment: Alignment.center,
              margin: EdgeInsets.all(2.0),
              color: Colors.grey,
              child: Text(index.toString()),
            );
          },
          itemList: randomList,
          autoScrollController: autoScrollController,
        )
    );
  }

  _getThumbWidget() {
    final double thumbHeight = 70;

    return PreferredSize(
      preferredSize: Size(thumbHeight * 0.6, thumbHeight),
      child: CustomPaint(
        foregroundPainter: ArrowCustomPainter(Colors.grey),
        child: Material(
          elevation: 10.0,
          color: Colors.white,
          child: Container(
              constraints: BoxConstraints.tight(Size(thumbHeight * 0.6, thumbHeight),)
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(thumbHeight),
            bottomLeft: Radius.circular(thumbHeight),
            topRight: Radius.circular(4.0),
            bottomRight: Radius.circular(4.0),
          ),
        ),
      ),
    );
  }

  _getScrollLabelItem(int index, bool isSelect) {
    return GestureDetector(
      onTap: () {
        autoScrollController.scrollToIndex(
            index, preferPosition: AutoScrollPosition.begin);
      },
      child: Container(
          margin: EdgeInsets.all(5),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: isSelect ? Colors.red : Colors.transparent
          ),
          height: 30,
          child: Center(
              child: Text(
                index.toString(),
                style: TextStyle(
                    color: isSelect ? Colors.white : Colors.black,
                    fontSize: isSelect ? 20 : 15,
                    fontWeight: isSelect ? FontWeight.bold : FontWeight.normal
                ),
              )
          )
      ),
    );
  }
}
