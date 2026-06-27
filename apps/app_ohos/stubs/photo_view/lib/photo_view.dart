import 'package:flutter/material.dart';

export 'photo_view_gallery.dart';

class PhotoViewComputedScale {
  final double _value;
  const PhotoViewComputedScale._(this._value);

  static const PhotoViewComputedScale contained = PhotoViewComputedScale._(1.0);
  static const PhotoViewComputedScale covered = PhotoViewComputedScale._(1.0);

  double get value => _value;
  double toDouble() => _value;
  double operator *(num multiplier) => _value * multiplier;
}

class PhotoViewHeroAttributes {
  final Object tag;
  const PhotoViewHeroAttributes({required this.tag});
}

class PhotoViewController {
  Offset position = Offset.zero;
  double scale = 1.0;
  double rotation = 0.0;

  VoidCallback? onDoubleClick;
  double Function()? getInitialScale;
  void Function(double scale, [Offset? position])? animateScale;

  void updateMultiple({
    Offset? position,
    double? scale,
    double? rotation,
  }) {
    if (position != null) this.position = position;
    if (scale != null) this.scale = scale;
    if (rotation != null) this.rotation = rotation;
  }

  void reset() {
    position = Offset.zero;
    scale = 1.0;
    rotation = 0.0;
  }

  void dispose() {}
}

class PhotoView extends StatefulWidget {
  const PhotoView({
    required this.imageProvider,
    this.minScale,
    this.maxScale,
    this.initialScale,
    this.heroAttributes,
    this.backgroundDecoration,
    this.gestureDetectorBehavior,
    this.onTapUp,
    this.loadingBuilder,
    this.filterQuality = FilterQuality.medium,
    this.errorBuilder,
    this.controller,
    this.onScaleUpdate,
    this.strictScale = false,
    super.key,
  })  : child = null,
        childSize = null;

  const PhotoView.customChild({
    required this.child,
    this.childSize,
    this.minScale,
    this.maxScale,
    this.initialScale,
    this.backgroundDecoration,
    this.controller,
    this.onScaleUpdate,
    this.strictScale = false,
    super.key,
  })  : imageProvider = null,
        heroAttributes = null,
        gestureDetectorBehavior = null,
        onTapUp = null,
        loadingBuilder = null,
        filterQuality = FilterQuality.medium,
        errorBuilder = null;

  final ImageProvider? imageProvider;
  final Widget? child;
  final Size? childSize;
  final Object? minScale;
  final Object? maxScale;
  final Object? initialScale;
  final PhotoViewHeroAttributes? heroAttributes;
  final BoxDecoration? backgroundDecoration;
  final HitTestBehavior? gestureDetectorBehavior;
  final PhotoViewTapUpCallback? onTapUp;
  final ImageLoadingBuilder? loadingBuilder;
  final FilterQuality filterQuality;
  final PhotoViewImageErrorBuilder? errorBuilder;
  final PhotoViewController? controller;
  final PhotoViewScaleUpdateCallback? onScaleUpdate;
  final bool strictScale;

  @override
  State<PhotoView> createState() => _PhotoViewState();
}

typedef PhotoViewTapUpCallback = void Function(
  BuildContext context,
  TapUpDetails details,
  PhotoViewControllerValue controllerValue,
);

typedef PhotoViewImageErrorBuilder = Widget Function(
  BuildContext context,
  Object error,
  StackTrace? stackTrace,
  VoidCallback retry,
);

typedef PhotoViewScaleUpdateCallback = void Function(double? scale);

class PhotoViewControllerValue {
  final Offset position;
  final double scale;
  final double rotation;

  const PhotoViewControllerValue({
    this.position = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
  });
}

double _resolveScale(Object? scale, {required double fallback}) {
  if (scale == null) return fallback;
  if (scale is double) return scale;
  if (scale is int) return scale.toDouble();
  if (scale is PhotoViewComputedScale) return scale.value;
  if (scale is num) return scale.toDouble();
  return fallback;
}

class _PhotoViewState extends State<PhotoView> {
  late PhotoViewController _controller;
  late TransformationController _transformationController;
  double _currentScale = 1.0;
  Offset _currentPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? PhotoViewController();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final double minScale = _resolveScale(widget.minScale, fallback: 1.0);
    final double maxScale = _resolveScale(widget.maxScale, fallback: 5.0);
    final double targetScale = _currentScale > 1.5 ? minScale : maxScale * 0.8;
    
    final Offset tapPosition = details.localPosition;
    final Offset centerOffset = Offset(
      tapPosition.dx * (1 - targetScale),
      tapPosition.dy * (1 - targetScale),
    );
    
    final Matrix4 matrix = Matrix4.identity()
      ..translate(centerOffset.dx, centerOffset.dy)
      ..scale(targetScale);
    
    _transformationController.value = matrix;
    _currentScale = targetScale;
    _currentPosition = centerOffset;
    
    widget.onScaleUpdate?.call(targetScale);
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    _currentScale = details.scale;
    _currentPosition = details.focalPointDelta;
    widget.onScaleUpdate?.call(details.scale);
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (widget.child != null) {
      content = widget.child!;
    } else if (widget.imageProvider != null) {
      content = Image(
        image: widget.imageProvider!,
        filterQuality: widget.filterQuality,
        errorBuilder: widget.errorBuilder != null
            ? (context, error, stackTrace) =>
                widget.errorBuilder!(context, error, stackTrace, () {})
            : null,
        fit: BoxFit.contain,
      );
    } else {
      content = const SizedBox.shrink();
    }

    Widget heroWrapper = content;
    if (widget.heroAttributes != null) {
      heroWrapper = Hero(
        tag: widget.heroAttributes!.tag,
        child: content,
      );
    }

    return Container(
      decoration: widget.backgroundDecoration ??
          const BoxDecoration(color: Color(0xFF000000)),
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: _resolveScale(widget.minScale, fallback: 1.0),
        maxScale: _resolveScale(widget.maxScale, fallback: double.infinity),
        clipBehavior: Clip.hardEdge,
        constrained: false,
        onInteractionUpdate: _onInteractionUpdate,
        child: GestureDetector(
          onDoubleTapDown: _handleDoubleTap,
          child: heroWrapper,
        ),
      ),
    );
  }
}
