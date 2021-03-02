import 'package:draggable_listview/listview/draggable-listview.widget.dart';
import 'package:draggable_listview/listview/draggable-scroll-label.widget.dart';
import 'package:draggable_listview/widget/draggable-scroll.widget.dart';
import 'package:draggable_listview/listview/indexed_scroll_view.dart';
import 'package:draggable_listview/listview/painter/arrow-painter.dart';
import 'package:draggable_listview/page/main-page.viewmodel.dart';
import 'package:draggable_listview/widget/slide-fade.widget.dart';
import 'package:flutter/material.dart';


class MainPageView extends StatelessWidget {

  MainPageViewModel _viewModel;

  @override
  Widget build(BuildContext context) {
    _viewModel ??= MainPageViewModel();

    return Scaffold(
      appBar: _getAppBar(),
      body: _getBody(),
    );
  }

  _getAppBar() {
    return AppBar(
      title: Text(
        'DraggableListView'
      ),
    );
  }

  _getBody() {
    return DraggableScrollbar(
        controller: _viewModel.autoScrollController,
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
                  final bool isSelect = index == _viewModel.autoScrollController.currentIndex;

                  return _getScrollLabelItem(index, isSelect);
                },
                listLength: _viewModel.randomList.length,
                autoScrollController: _viewModel.autoScrollController,
              ),
            ),
          );
        },
        draggableListView: DraggableListView(
          listItemBuilder: (context, index) {
            return Container(
              height: _viewModel.randomList[index],
              alignment: Alignment.center,
              margin: EdgeInsets.all(2.0),
              color: Colors.grey,
              child: Text(index.toString()),
            );
          },
          itemList: _viewModel.randomList,
          autoScrollController: _viewModel.autoScrollController,
        )
    );
  }

  _getThumbWidget() {
    final double thumbHeight = 70;

    return PreferredSize(
      preferredSize: Size(thumbHeight * 0.6, thumbHeight),
      child: CustomPaint(
        foregroundPainter: ArrowPainter(Colors.grey),
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
        _viewModel.autoScrollController.scrollToIndex(
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
