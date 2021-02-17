import 'dart:math';

import 'package:draggable_listview/listview/indexed_scroll_view.dart';

class MainPageViewModel {

  MainPageViewModel() {
    _randomList = [
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
  }
  
  final double itemHeight = 100;
  final AutoScrollController autoScrollController =  AutoScrollController();

  List<double> _randomList;

  List<double> get randomList => _randomList;
}