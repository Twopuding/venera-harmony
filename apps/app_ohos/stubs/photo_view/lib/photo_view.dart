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

class PhotoViewController extends ChangeNotifier {
  Offset _position = Offset.zero;
  double _scale = 1.0;
  double _rotation = 0.0;

  Offset get position => _position;
  double get scale => _scale;
  double get rotation => _rotation;

  VoidCallback? onDoubleClick;
  double Function()? getInitialScale;
  void Function(double scale, [Offset? position])? animateScale;

  void updateMultiple({
    Offset? position,
    double? scale,
    double? rotation,
  }) {
    if (position != null) _position = position;
    if (scale != null) _scale = scale;
    if (rotation != null) _rotation = rotation;
    notifyListeners();
  }

  void reset() {
    _position = Offset.zero;
    _scale = 1.0;
    _rotation = 0.0;
    notifyListeners();
  }
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
    // customChild 模式下没有 imageProvider，无法通过 _resolveImageSize 获取尺寸。
    // 用 widget.childSize 初始化 _imageSize，使 _computeContainedScale、
    // _applyInitialScale 与 animateScale 能正确计算缩放与偏移，
    // 否则连续模式 _containedScale 恒为 1.0，放大后图片显示位置与范围异常。
    if (widget.childSize != null) {
      _imageSize = widget.childSize;
    }
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
    // 同步外部 controller 的初始 scale/position。
    _controller.updateMultiple(
      position: Offset(offsetX, offsetY),
      scale: initialScale,
    );

    _controller.getInitialScale = () => _containedScale;
    // position 参数语义：希望该 content 坐标点出现在 viewport 中心。
    // 渲染矩阵 = translate(position) ∘ scale(scale)，content 像素 p 映射到
    // 屏幕 p*scale + position。要使 location 出现在 viewport 中心：
    //   location*scale + position = viewport/2 → position = viewport/2 - location*scale
    _controller.animateScale = (double scale, [Offset? position]) {
      if (_viewportSize == null || !mounted) return;
      double newOffsetX, newOffsetY;
      // 缩小/复原到初始缩放时忽略传入的双击位置偏移，强制居中铺满。
      bool isResetToInitial =
          (scale - _containedScale).abs() < 0.001;
      if (position != null && !isResetToInitial) {
        newOffsetX = _viewportSize!.width / 2 - position.dx * scale;
        newOffsetY = _viewportSize!.height / 2 - position.dy * scale;
      } else {
        final imageSize = _imageSize ?? _viewportSize!;
        newOffsetX = (_viewportSize!.width - imageSize.width * scale) / 2;
        newOffsetY = (_viewportSize!.height - imageSize.height * scale) / 2;
      }
      // 只更新 controller，渲染由 AnimatedBuilder 监听 controller 触发。
      _currentScale = scale;
      _currentPosition = Offset(newOffsetX, newOffsetY);
      _controller.updateMultiple(
        position: Offset(newOffsetX, newOffsetY),
        scale: scale,
      );
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
    // 缩小/复原到 containedScale 时忽略双击位置，强制居中铺满，
    // 否则缩小后内容偏移，不再铺满 viewport。
    bool isResetToInitial =
        (targetScale - _containedScale).abs() < 0.001;
    double newOffsetX, newOffsetY;
    if (isResetToInitial) {
      final imageSize = _imageSize ?? _viewportSize!;
      newOffsetX = (_viewportSize!.width - imageSize.width * targetScale) / 2;
      newOffsetY = (_viewportSize!.height - imageSize.height * targetScale) / 2;
    } else {
      // 渲染矩阵 = translate ∘ scale, content 像素 p 映射到 p*scale + position。
      // 让 tapPosition 出现在 viewport 中心：position = viewport/2 - tap*scale。
      newOffsetX = _viewportSize!.width / 2 - (tapPosition.dx * targetScale);
      newOffsetY = _viewportSize!.height / 2 - (tapPosition.dy * targetScale);
    }

    final Matrix4 matrix = Matrix4.identity()
      ..translate(newOffsetX, newOffsetY)
      ..scale(targetScale);

    _transformationController.value = matrix;
    _currentScale = targetScale;
    _currentPosition = Offset(newOffsetX, newOffsetY);
    // 同步外部 controller，使阅读器 gallery 模式下放大后手动拖动可用，
    // 否则 photoViewController.scale 恒为初始值，onPointerMove 被忽略。
    _controller.updateMultiple(
      position: Offset(newOffsetX, newOffsetY),
      scale: targetScale,
    );

    widget.onScaleUpdate?.call(targetScale);
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    _currentScale = _transformationController.value.getMaxScaleOnAxis();
    _currentPosition = details.focalPointDelta;
    // 同步外部 controller，使用 InteractiveViewer 双指缩放后也能正常拖动。
    _controller.updateMultiple(scale: _currentScale);
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
          // 用 AnimatedBuilder 监听 controller，以 Transform 驱动渲染。
          // 移除 InteractiveViewer，避免其内置手势与外层 Listener.onPointerMove
          // 同时修改 _transformationController 导致放大后拖动抖动。
          // 外层阅读器已自行处理单指拖动与双指滚动禁用逻辑。
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform(
                transform: Matrix4.identity()
                  ..translate(
                    _controller.position.dx,
                    _controller.position.dy,
                  )
                  ..scale(_controller.scale),
                child: child,
              );
            },
            child: _buildChildGestureWrapper(heroWrapper),
          );
        },
      ),
    );
  }

  /// customChild 模式下不注册双击识别器，避免与阅读器外层
  /// _ReaderGestureDetector 的双击处理同时触发，导致连续模式双击放大失效。
  /// imageProvider 模式仍保留内置双击（gallery 模式依赖此路径）。
  Widget _buildChildGestureWrapper(Widget child) {
    if (widget.child != null) {
      return child;
    }
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTap,
      child: child,
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
