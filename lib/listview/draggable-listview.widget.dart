import 'package:draggable_listview/listview/indexed_scroll_view.dart';
import 'package:flutter/material.dart';


typedef Widget AnalysisViewBuilder(BuildContext context, int index,);

class DraggableListView extends BoxScrollView {

  const DraggableListView({
    this.autoScrollController,
    this.itemList,
    this.viewItemBuilder,
  }) : assert(autoScrollController != null),
        assert(itemList != null && itemList.length != 0);

  final AutoScrollController autoScrollController;
  final List<double> itemList;
  final AnalysisViewBuilder viewItemBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
        child: ListView.builder(
          controller: autoScrollController,
          itemCount: itemList.length,
          itemBuilder: (context, index) {
            return _getScreen(context, index);
          },
        )
    );
  }

  _getScreen(BuildContext context, int index,) {
    return AutoScrollTag(
      key: ValueKey(index),
      controller: autoScrollController,
      index: index,
      child: viewItemBuilder(
        context,
        index,
      ),
    );
  }

  @override
  Widget buildChildLayout(BuildContext context) {
    return null;
  }

  int get screenCount => itemList.length;
}
