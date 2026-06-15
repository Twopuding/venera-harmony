import 'package:flutter/foundation.dart';

class PlatformDetector {
  static bool get isOhos =>
      defaultTargetPlatform == TargetPlatform.fuchsia;
}
