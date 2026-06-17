import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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

/// Tracks laid-out item extents for variable-height lists.
class ItemExtentRegistry extends ChangeNotifier {
  ItemExtentRegistry({this.defaultExtent = 420});

  final Map<int, double> _extents = {};
  double defaultExtent;
  ScrollController? scrollController;
  Axis scrollDirection = Axis.vertical;

  Map<int, double> get extents => Map.unmodifiable(_extents);

  double extentFor(int index) {
    if (_extents.containsKey(index)) {
      return _extents[index]!;
    }
    return defaultExtent;
  }

  void reportExtent(int index, double extent) {
    if (!extent.isFinite || extent < 0) return;
    if (extent == 0) {
      if (_extents[index] == 0) return;
      _extents[index] = 0;
      notifyListeners();
      return;
    }
    final old = _extents[index];
    if (old != null && (old - extent).abs() < 0.5) return;

    final itemStart = offsetForIndex(index);
    final oldEnd = itemStart + (old ?? defaultExtent);
    _extents[index] = extent;
    _adjustScrollForExtentChange(oldEnd, old, extent);
    notifyListeners();
  }

  void _adjustScrollForExtentChange(
    double oldItemEnd,
    double? oldExtent,
    double newExtent,
  ) {
    final controller = scrollController;
    if (controller == null || !controller.hasClients || oldExtent == null) return;

    final delta = newExtent - oldExtent;
    if (delta.abs() < 0.5) return;

    final position = controller.position;
    final scrollOffset = position.pixels;
    if (scrollOffset > oldItemEnd - 0.5) {
      final newOffset = (scrollOffset + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((newOffset - scrollOffset).abs() > 0.5) {
        controller.jumpTo(newOffset);
      }
    }
  }

  double offsetForIndex(int index, {double alignment = 0, double viewport = 0}) {
    double offset = 0;
    for (int i = 0; i < index; i++) {
      offset += extentFor(i);
    }
    if (alignment > 0 && viewport > 0) {
      offset -= alignment * (viewport - extentFor(index));
    }
    return offset < 0 ? 0 : offset;
  }

  int? indexAtOffset(double scrollOffset, int itemCount) {
    if (itemCount <= 0) return null;
    double offset = 0;
    for (int i = 0; i < itemCount; i++) {
      final extent = extentFor(i);
      if (scrollOffset < offset + extent) {
        return i;
      }
      offset += extent;
    }
    return itemCount - 1;
  }

  Iterable<ItemPosition> positionsAtOffset({
    required double scrollOffset,
    required double viewportDimension,
    required int itemCount,
  }) {
    if (itemCount <= 0 || viewportDimension <= 0) {
      return const <ItemPosition>[];
    }

    final firstIndex = indexAtOffset(scrollOffset, itemCount) ?? 0;
    final positions = <ItemPosition>[];
    double itemStart = offsetForIndex(firstIndex);

    for (int i = firstIndex; i < itemCount; i++) {
      final extent = extentFor(i);
      final itemEnd = itemStart + extent;
      if (itemStart > scrollOffset + viewportDimension) break;

      final leadingEdge = (itemStart - scrollOffset) / viewportDimension;
      final trailingEdge = (itemEnd - scrollOffset) / viewportDimension;
      if (trailingEdge > 0 && leadingEdge < 1) {
        positions.add(ItemPosition(
          index: i,
          itemLeadingEdge: leadingEdge.clamp(0.0, 1.0),
          itemTrailingEdge: trailingEdge.clamp(0.0, 1.0),
        ));
      }
      itemStart = itemEnd;
    }
    return positions;
  }

  void seedExtent(int index, double extent) {
    if (!extent.isFinite || extent < 0) return;
    _extents[index] = extent;
  }

  void clear() {
    _extents.clear();
    notifyListeners();
  }
}

class ItemScrollController {
  ScrollController? _scrollController;
  ItemExtentRegistry? _registry;
  int _itemCount = 0;

  void attach({
    required ScrollController scrollController,
    required ItemExtentRegistry registry,
    required int itemCount,
  }) {
    _scrollController = scrollController;
    _registry = registry;
    _itemCount = itemCount;
    registry.scrollController = scrollController;
  }

  void detach() {
    _registry?.scrollController = null;
    _scrollController = null;
    _registry = null;
    _itemCount = 0;
  }

  Future<void> jumpTo({required int index, double alignment = 0}) async {
    final controller = _scrollController;
    final registry = _registry;
    if (controller == null || registry == null || !controller.hasClients) return;

    final viewport = controller.position.viewportDimension;
    final offset = registry
        .offsetForIndex(index, alignment: alignment, viewport: viewport)
        .clamp(0.0, controller.position.maxScrollExtent);
    controller.jumpTo(offset);
  }

  Future<void> scrollTo({
    required int index,
    double alignment = 0,
    required Duration duration,
    required Curve curve,
  }) async {
    final controller = _scrollController;
    final registry = _registry;
    if (controller == null || registry == null || !controller.hasClients) return;

    final viewport = controller.position.viewportDimension;
    final offset = registry
        .offsetForIndex(index, alignment: alignment, viewport: viewport)
        .clamp(0.0, controller.position.maxScrollExtent);
    await controller.animateTo(offset, duration: duration, curve: curve);
  }
}

class ScrollablePositionedList extends StatefulWidget {
  const ScrollablePositionedList.builder({
    required this.itemCount,
    required this.itemBuilder,
    this.itemScrollController,
    this.itemPositionsListener,
    this.itemExtentRegistry,
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
  final ItemExtentRegistry? itemExtentRegistry;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollPhysics? physics;
  final int initialScrollIndex;
  final void Function(ScrollController)? scrollControllerCallback;
  final bool addSemanticIndexes;

  @override
  State<ScrollablePositionedList> createState() =>
      _ScrollablePositionedListState();
}

class _ScrollablePositionedListState extends State<ScrollablePositionedList> {
  final ScrollController _scrollController = ScrollController();
  late final ItemExtentRegistry _extentRegistry;
  bool _initialScrollApplied = false;

  @override
  void initState() {
    super.initState();
    _extentRegistry = widget.itemExtentRegistry ?? ItemExtentRegistry();
    _extentRegistry.scrollDirection = widget.scrollDirection;
    widget.itemScrollController?.attach(
      scrollController: _scrollController,
      registry: _extentRegistry,
      itemCount: widget.itemCount,
    );
    widget.scrollControllerCallback?.call(_scrollController);
    _extentRegistry.addListener(_onExtentsChanged);
    _scrollController.addListener(_onScroll);
    SchedulerBinding.instance.addPostFrameCallback((_) => _applyInitialScroll());
  }

  @override
  void didUpdateWidget(ScrollablePositionedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) {
      widget.itemScrollController?.attach(
        scrollController: _scrollController,
        registry: _extentRegistry,
        itemCount: widget.itemCount,
      );
    }
  }

  @override
  void dispose() {
    _extentRegistry.removeListener(_onExtentsChanged);
    _scrollController.removeListener(_onScroll);
    widget.itemScrollController?.detach();
    _scrollController.dispose();
    super.dispose();
  }

  void _applyInitialScroll() {
    if (_initialScrollApplied || !mounted) return;
    if (!_scrollController.hasClients || widget.initialScrollIndex <= 0) {
      _initialScrollApplied = true;
      return;
    }
    widget.itemScrollController?.jumpTo(index: widget.initialScrollIndex);
    _initialScrollApplied = true;
    _onScroll();
  }

  void _onExtentsChanged() {
    if (!_initialScrollApplied && widget.initialScrollIndex > 0) {
      _applyInitialScroll();
    }
    _onScroll();
  }

  void _onScroll() {
    final listener = widget.itemPositionsListener;
    if (listener == null || !_scrollController.hasClients) return;

    final position = _scrollController.position;
    final viewportDimension = position.viewportDimension;
    if (viewportDimension == 0 || widget.itemCount == 0) return;

    listener.itemPositions.value = _extentRegistry.positionsAtOffset(
      scrollOffset: position.pixels,
      viewportDimension: viewportDimension,
      itemCount: widget.itemCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    if (widget.scrollDirection == Axis.vertical) {
      _extentRegistry.defaultExtent = viewportWidth * 1.4;
    } else {
      _extentRegistry.defaultExtent = viewportHeight * 0.7;
    }

    final cacheExtent = widget.scrollDirection == Axis.vertical
        ? viewportHeight
        : viewportWidth;

    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.itemCount,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      physics: widget.physics,
      addSemanticIndexes: widget.addSemanticIndexes,
      cacheExtent: cacheExtent,
      itemBuilder: (context, index) {
        return _ExtentReporting(
          index: index,
          registry: _extentRegistry,
          scrollDirection: widget.scrollDirection,
          child: widget.itemBuilder(context, index),
        );
      },
    );
  }
}

class _ExtentReporting extends StatefulWidget {
  const _ExtentReporting({
    required this.index,
    required this.registry,
    required this.scrollDirection,
    required this.child,
  });

  final int index;
  final ItemExtentRegistry registry;
  final Axis scrollDirection;
  final Widget child;

  @override
  State<_ExtentReporting> createState() => _ExtentReportingState();
}

class _ExtentReportingState extends State<_ExtentReporting> {
  double? _lastReported;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportExtent());
  }

  @override
  void didUpdateWidget(_ExtentReporting oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportExtent());
  }

  void _reportExtent() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final extent = widget.scrollDirection == Axis.vertical
        ? box.size.height
        : box.size.width;
    if (_lastReported != null && (_lastReported! - extent).abs() < 0.5) return;
    _lastReported = extent;
    widget.registry.reportExtent(widget.index, extent);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _reportExtent());
        return false;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }
}
