import 'package:flutter/material.dart';

class ItemPosition {
  final int index;
  final double itemLeadingEdge;
  final double itemTrailingEdge;

  const ItemPosition({
    required this.index,
    required this.itemLeadingEdge,
    required this.itemTrailingEdge,
  });
}

class ItemPositionsListener {
  ItemPositionsListener() : itemPositions = ValueNotifier(const <ItemPosition>[]);

  factory ItemPositionsListener.create() => ItemPositionsListener();

  final ValueNotifier<Iterable<ItemPosition>> itemPositions;
}

class ItemScrollController {
  final ScrollController _scrollController = ScrollController();

  Future<void> jumpTo({required int index, double alignment = 0}) async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final viewportDimension = position.viewportDimension;
    final estimatedExtent = position.maxScrollExtent;
    if (estimatedExtent > 0 && viewportDimension > 0) {
      final itemHeight = estimatedExtent / 1000;
      final offset = (index * itemHeight - alignment * viewportDimension)
          .clamp(0.0, position.maxScrollExtent);
      _scrollController.jumpTo(offset);
    }
  }

  Future<void> scrollTo({
    required int index,
    double alignment = 0,
    required Duration duration,
    required Curve curve,
  }) async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final viewportDimension = position.viewportDimension;
    final estimatedExtent = position.maxScrollExtent;
    if (estimatedExtent > 0 && viewportDimension > 0) {
      final itemHeight = estimatedExtent / 1000;
      final offset = (index * itemHeight - alignment * viewportDimension)
          .clamp(0.0, position.maxScrollExtent);
      _scrollController.animateTo(offset, duration: duration, curve: curve);
    }
  }
}

class ScrollablePositionedList extends StatefulWidget {
  const ScrollablePositionedList.builder({
    required this.itemCount,
    required this.itemBuilder,
    this.itemScrollController,
    this.itemPositionsListener,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    this.initialScrollIndex = 0,
    this.scrollControllerCallback,
    this.addSemanticIndexes = true,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ItemScrollController? itemScrollController;
  final ItemPositionsListener? itemPositionsListener;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollPhysics? physics;
  final int initialScrollIndex;
  final void Function(ScrollController)? scrollControllerCallback;
  final bool addSemanticIndexes;

  @override
  State<ScrollablePositionedList> createState() => _ScrollablePositionedListState();
}

class _ScrollablePositionedListState extends State<ScrollablePositionedList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.scrollControllerCallback?.call(_scrollController);
    _updatePositions();
  }

  void _updatePositions() {
    if (widget.itemPositionsListener == null) return;
    _scrollController.addListener(_onScroll);
    _onScroll();
  }

  void _onScroll() {
    if (widget.itemPositionsListener == null || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final viewportDimension = position.viewportDimension;
    final scrollOffset = position.pixels;
    if (viewportDimension == 0 || widget.itemCount == 0) return;

    final estimatedItemExtent = (position.maxScrollExtent + viewportDimension) / widget.itemCount;
    if (estimatedItemExtent <= 0) return;

    final firstVisible = (scrollOffset / estimatedItemExtent).floor().clamp(0, widget.itemCount - 1);
    final lastVisible = ((scrollOffset + viewportDimension) / estimatedItemExtent).ceil().clamp(0, widget.itemCount - 1);

    final positions = <ItemPosition>[];
    for (int i = firstVisible; i <= lastVisible; i++) {
      final leadingEdge = (i * estimatedItemExtent - scrollOffset) / viewportDimension;
      final trailingEdge = ((i + 1) * estimatedItemExtent - scrollOffset) / viewportDimension;
      positions.add(ItemPosition(
        index: i,
        itemLeadingEdge: leadingEdge.clamp(0.0, 1.0),
        itemTrailingEdge: trailingEdge.clamp(0.0, 1.0),
      ));
    }
    widget.itemPositionsListener!.itemPositions.value = positions;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.itemCount,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      physics: widget.physics,
      addSemanticIndexes: widget.addSemanticIndexes,
      itemBuilder: widget.itemBuilder,
    );
  }
}
