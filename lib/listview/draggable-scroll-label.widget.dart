import 'package:draggable_listview/listview/indexed_scroll_view.dart';
import 'package:flutter/material.dart';


typedef Widget ScrollLabelBuilder(Animation<double> thumbAnimation);

typedef Widget ScrollLabelItemBuilder(int currentIndex);

class DraggableScrollLabel extends StatefulWidget {

  DraggableScrollLabel({
    Key key,
    this.autoScrollController,
    this.listLength,
    this.scrollLabelItemBuilder,
    this.width = 72,
    this.rightPadding = 12,
  }) : assert(listLength != 0),
        assert(autoScrollController != null),
        assert(scrollLabelItemBuilder != null);

  final ScrollLabelItemBuilder scrollLabelItemBuilder;
  final AutoScrollController autoScrollController;
  final int listLength;
  final double width;
  final double rightPadding;

  @override
  DraggableScrollLabelState createState() => DraggableScrollLabelState();
}

class DraggableScrollLabelState extends State<DraggableScrollLabel> {

  ScrollController _controller;

  @override
  void initState() {
    _controller = ScrollController();

    widget.autoScrollController.addListener((){
      if(!_controller.hasClients)
        return;

      _moveScroll();
    });

    WidgetsBinding.instance.addPostFrameCallback((_){
      _moveScroll();
    });

    super.initState();
  }

  _moveScroll(){
    final offset =  (_presumeOffset * _parentScrollIndex);

    _controller.jumpTo(_parentScrollIndex == widget.listLength - 1 ? _controller.position.maxScrollExtent : offset);
  }

  @override
  void didUpdateWidget(DraggableScrollLabel oldWidget) {
    // TODO: implement didUpdateWidget
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final scrollLabels = List<Widget>.generate(widget.listLength, (index) {
      return _getScrollLabelItem(index);
    });

    return Container(
        width: widget.width,
        margin: EdgeInsets.only(right: widget.rightPadding),
        color: Colors.white,
        child: ListView(
          controller: _controller,
          children: scrollLabels,
        )
    );
  }

  _getScrollLabelItem(int index) {
    return widget.scrollLabelItemBuilder(index);
  }


  int get _parentScrollIndex => widget.autoScrollController.currentIndex;

  double get _presumeOffset => _controller.position.maxScrollExtent / widget.listLength;

}
