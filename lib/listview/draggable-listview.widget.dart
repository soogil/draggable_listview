import 'package:draggable_listview/listview/indexed_scroll_view.dart';
import 'package:flutter/material.dart';


typedef Widget ListItemBuilder(BuildContext context, int index,);

class DraggableListView extends BoxScrollView {

  const DraggableListView({
    this.autoScrollController,
    this.itemList,
    this.listItemBuilder,
  }) : assert(autoScrollController != null),
        assert(itemList != null && itemList.length != 0);

  final AutoScrollController autoScrollController;
  final List<double> itemList;
  final ListItemBuilder listItemBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
        child: ListView.builder(
          controller: autoScrollController,
          itemCount: itemList.length,
          itemBuilder: (context, index) {
            return _getItem(context, index);
          },
        )
    );
  }

  _getItem(BuildContext context, int index,) {
    return AutoScrollTag(
      key: ValueKey(index),
      controller: autoScrollController,
      index: index,
      child: listItemBuilder(
        context,
        index,
      ),
    );
  }

  @override
  Widget buildChildLayout(BuildContext context) {
    return null;
  }
}
