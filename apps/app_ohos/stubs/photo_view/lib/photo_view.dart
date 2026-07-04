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
  Size? _imageSize;
  Size? _viewportSize;
  bool _hasAppliedInitialScale = false;
  double _containedScale = 1.0;

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

  double _computeContainedScale() {
    if (_imageSize == null || _viewportSize == null) return 1.0;
    if (_imageSize!.width <= 0 || _imageSize!.height <= 0) return 1.0;
    if (_viewportSize!.width <= 0 || _viewportSize!.height <= 0) return 1.0;
    double scaleX = _viewportSize!.width / _imageSize!.width;
    double scaleY = _viewportSize!.height / _imageSize!.height;
    return scaleX < scaleY ? scaleX : scaleY;
  }

  void _applyInitialScale() {
    if (_hasAppliedInitialScale) return;
    if (_imageSize == null || _viewportSize == null) return;

    _containedScale = _computeContainedScale();

    double initialScale;
    if (widget.initialScale != null) {
      initialScale = _resolveScale(widget.initialScale, fallback: _containedScale);
      if (initialScale == 1.0 && widget.initialScale is PhotoViewComputedScale) {
        initialScale = _containedScale;
      }
    } else {
      initialScale = _containedScale;
    }

    _currentScale = initialScale;
    _hasAppliedInitialScale = true;

    double offsetX = (_viewportSize!.width - _imageSize!.width * initialScale) / 2;
    double offsetY = (_viewportSize!.height - _imageSize!.height * initialScale) / 2;

    final Matrix4 matrix = Matrix4.identity()
      ..translate(offsetX, offsetY)
      ..scale(initialScale);
    _transformationController.value = matrix;

    _controller.getInitialScale = () => _containedScale;
    _controller.animateScale = (double scale, [Offset? position]) {
      if (_viewportSize == null || !mounted) return;
      double newOffsetX, newOffsetY;
      if (position != null) {
        newOffsetX = _viewportSize!.width / 2 - position.dx;
        newOffsetY = _viewportSize!.height / 2 - position.dy;
      } else {
        final imageSize = _imageSize ?? _viewportSize!;
        newOffsetX = (_viewportSize!.width - imageSize.width * scale) / 2;
        newOffsetY = (_viewportSize!.height - imageSize.height * scale) / 2;
      }
      final Matrix4 m = Matrix4.identity()
        ..translate(newOffsetX, newOffsetY)
        ..scale(scale);
      _transformationController.value = m;
      _currentScale = scale;
      _currentPosition = Offset(newOffsetX, newOffsetY);
      widget.onScaleUpdate?.call(scale);
    };
    _controller.onDoubleClick = () {
      if (_viewportSize == null || !mounted) return;
      _handleDoubleTap(TapDownDetails(
        globalPosition: _viewportSize!.center(Offset.zero),
        localPosition: _viewportSize!.center(Offset.zero),
      ));
    };
  }

  void _handleDoubleTap(TapDownDetails details) {
    double minScale = _containedScale;
    double maxScale = _resolveScale(widget.maxScale, fallback: 5.0);
    if (maxScale <= _containedScale) {
      maxScale = _containedScale * 5.0;
    }

    double targetScale;
    if (_currentScale > _containedScale * 1.1) {
      targetScale = _containedScale;
    } else {
      targetScale = maxScale * 0.5;
    }

    final Offset tapPosition = details.localPosition;
    double newOffsetX = _viewportSize!.width / 2 - (tapPosition.dx * targetScale);
    double newOffsetY = _viewportSize!.height / 2 - (tapPosition.dy * targetScale);

    final Matrix4 matrix = Matrix4.identity()
      ..translate(newOffsetX, newOffsetY)
      ..scale(targetScale);

    _transformationController.value = matrix;
    _currentScale = targetScale;
    _currentPosition = Offset(newOffsetX, newOffsetY);

    widget.onScaleUpdate?.call(targetScale);
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    _currentScale = _transformationController.value.getMaxScaleOnAxis();
    _currentPosition = details.focalPointDelta;
    widget.onScaleUpdate?.call(_currentScale);
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (widget.child != null) {
      content = widget.child!;
    } else if (widget.imageProvider != null) {
      content = _buildImageWidget();
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
          if (!_hasAppliedInitialScale && _imageSize != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _applyInitialScale();
              }
            });
          }
          double minScale = _containedScale > 0 ? _containedScale : 0.01;
          return InteractiveViewer(
            transformationController: _transformationController,
            minScale: minScale,
            maxScale: _resolveScale(widget.maxScale, fallback: minScale * 10.0),
            clipBehavior: Clip.hardEdge,
            constrained: false,
            onInteractionUpdate: _onInteractionUpdate,
            child: GestureDetector(
              onDoubleTapDown: _handleDoubleTap,
              child: heroWrapper,
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageWidget() {
    return Image(
      image: widget.imageProvider!,
      filterQuality: widget.filterQuality,
      errorBuilder: widget.errorBuilder != null
          ? (context, error, stackTrace) =>
              widget.errorBuilder!(context, error, stackTrace, () {})
          : null,
      fit: BoxFit.none,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null && !_hasAppliedInitialScale) {
          _resolveImageSize();
        }
        return child;
      },
    );
  }

  void _resolveImageSize() {
    if (_imageSize != null) return;
    final imageStream = widget.imageProvider!.resolve(
      ImageConfiguration.empty,
    );
    imageStream.addListener(_imageStreamListener);
  }

  late ImageStreamListener _imageStreamListener = ImageStreamListener(
    (ImageInfo info, bool synchronousCall) {
      _imageSize = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      info.image.dispose();
      if (!_hasAppliedInitialScale && _viewportSize != null) {
        _applyInitialScale();
      }
    },
  );
}
