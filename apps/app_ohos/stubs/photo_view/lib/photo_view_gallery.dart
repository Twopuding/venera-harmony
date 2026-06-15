import 'package:flutter/material.dart';
import 'photo_view.dart';

class PhotoViewGalleryPageOptions {
  PhotoViewGalleryPageOptions({
    required this.imageProvider,
    this.minScale,
    this.maxScale,
    this.heroAttributes,
    this.controller,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.medium,
    this.onTapUp,
    this.errorBuilder,
  }) : child = null,
       childSize = null;

  PhotoViewGalleryPageOptions.customChild({
    required this.child,
    this.childSize,
    this.minScale,
    this.maxScale,
    this.controller,
  })  : imageProvider = null,
        heroAttributes = null,
        fit = BoxFit.contain,
        filterQuality = FilterQuality.medium,
        onTapUp = null,
        errorBuilder = null;

  final ImageProvider? imageProvider;
  final Widget? child;
  final Size? childSize;
  final double? minScale;
  final double? maxScale;
  final PhotoViewHeroAttributes? heroAttributes;
  final PhotoViewController? controller;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final PhotoViewTapUpCallback? onTapUp;
  final PhotoViewImageErrorBuilder? errorBuilder;
}

class PhotoViewGallery extends StatefulWidget {
  const PhotoViewGallery.builder({
    required this.builder,
    required this.itemCount,
    this.backgroundDecoration,
    this.loadingBuilder,
    this.pageController,
    this.onPageChanged,
    this.scrollDirection = Axis.horizontal,
    this.reverse = false,
    super.key,
  });

  final PhotoViewGalleryBuilder builder;
  final int itemCount;
  final BoxDecoration? backgroundDecoration;
  final PhotoViewGalleryLoadingBuilder? loadingBuilder;
  final PageController? pageController;
  final ValueChanged<int>? onPageChanged;
  final Axis scrollDirection;
  final bool reverse;

  @override
  State<PhotoViewGallery> createState() => _PhotoViewGalleryState();
}

typedef PhotoViewGalleryBuilder = PhotoViewGalleryPageOptions Function(
  BuildContext context,
  int index,
);

typedef PhotoViewGalleryLoadingBuilder = Widget Function(
  BuildContext context,
  ImageChunkEvent? event,
);

class _PhotoViewGalleryState extends State<PhotoViewGallery> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: widget.backgroundDecoration ??
          const BoxDecoration(color: Color(0xFF000000)),
      child: PageView.builder(
        controller: widget.pageController,
        itemCount: widget.itemCount,
        reverse: widget.reverse,
        scrollDirection: widget.scrollDirection,
        onPageChanged: widget.onPageChanged,
        itemBuilder: (context, index) {
          final options = widget.builder(context, index);
          if (options.imageProvider != null) {
            return PhotoView(
              imageProvider: options.imageProvider,
              minScale: options.minScale,
              maxScale: options.maxScale,
              heroAttributes: options.heroAttributes,
              backgroundDecoration: const BoxDecoration(),
              onTapUp: options.onTapUp,
              filterQuality: options.filterQuality,
              errorBuilder: options.errorBuilder,
            );
          }
          return PhotoView.customChild(
            child: options.child,
            childSize: options.childSize,
            minScale: options.minScale,
            maxScale: options.maxScale,
            backgroundDecoration: const BoxDecoration(),
            controller: options.controller,
          );
        },
      ),
    );
  }
}
