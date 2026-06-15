import 'dart:typed_data';

import 'package:image/image.dart' as img;

class LodepngEncoder {
  static Uint8List encodePng(Uint8List rgbaData, int width, int height) {
    var pixels = Uint32List.view(rgbaData.buffer);
    var image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var pixel = pixels[y * width + x];
        image.setPixelRgba(
          x,
          y,
          (pixel & 0xFF),
          ((pixel >> 8) & 0xFF),
          ((pixel >> 16) & 0xFF),
          ((pixel >> 24) & 0xFF),
        );
      }
    }
    var pngBytes = img.encodePng(image);
    return Uint8List.fromList(pngBytes);
  }
}
