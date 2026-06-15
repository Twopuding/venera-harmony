import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/network/proxy.dart';
import 'package:venera/platform/ohos_platform_services.dart';
import 'package:venera/utils/ext.dart';
import 'package:venera/utils/translations.dart';

typedef WebviewOnTitleChange = void Function(String title);
typedef WebviewOnNavigation = bool Function(String url);
typedef WebviewOnStarted = void Function();
typedef WebviewOnLoadStop = void Function();

class AppWebview extends StatefulWidget {
  AppWebview({
    super.key,
    this.initialUrl,
    this.initialData,
    this.onTitleChange,
    this.onNavigation,
    this.onStarted,
    this.onLoadStop,
    this.userAgent,
    this.singlePage = false,
  });

  final String? initialUrl;
  final String? initialData;
  final WebviewOnTitleChange? onTitleChange;
  final WebviewOnNavigation? onNavigation;
  final WebviewOnStarted? onStarted;
  final WebviewOnLoadStop? onLoadStop;
  final String? userAgent;
  final bool singlePage;

  static String? webViewEnvironment;

  static final _activeStates = <AppWebviewState>[];

  static AppWebviewState? get activeState =>
      _activeStates.isNotEmpty ? _activeStates.last : null;

  @override
  State<AppWebview> createState() => AppWebviewState();
}

class AppWebviewState extends State<AppWebview> {
  static const MethodChannel _channel = MethodChannel('com.venera.webview');

  String _title = '';
  String _currentUrl = '';
  bool _isLoading = true;

  String get title => _title;
  String get currentUrl => _currentUrl;
  bool get isLoading => _isLoading;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl ?? '';
    AppWebview._activeStates.add(this);
    _setupMethodCallHandler();
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _loadUrlInternal(widget.initialUrl!);
    }
  }

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onTitleChanged':
          var t = call.arguments as String?;
          if (t != null && mounted) {
            _title = t;
            widget.onTitleChange?.call(t);
          }
          return null;
        case 'onUrlChanged':
          var u = call.arguments as String?;
          if (u != null && mounted) {
            var shouldCancel = widget.onNavigation?.call(u) ?? false;
            if (!shouldCancel) {
              _currentUrl = u;
            }
          }
          return null;
        case 'onLoadStop':
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            widget.onLoadStop?.call();
          }
          return null;
        default:
          return null;
      }
    });
  }

  void _loadUrlInternal(String url) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _currentUrl = url;
      });
    }
    try {
      await _channel.invokeMethod<void>('loadUrl', {'url': url});
      if (widget.onStarted != null) {
        widget.onStarted!();
      }
    } on MissingPluginException {
      if (widget.onStarted != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onStarted!();
        });
      }
    }
  }

  Future<String> getCurrentUrl() async {
    try {
      var url = await _channel.invokeMethod<String>('getCurrentUrl');
      if (url != null) {
        _currentUrl = url;
      }
      return url ?? _currentUrl;
    } on MissingPluginException {
      return _currentUrl;
    }
  }

  Future<void> loadUrl(String url) async {
    _loadUrlInternal(url);
  }

  Future<void> loadData(String data, {String mimeType = 'text/html'}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
  }

  Future<dynamic> evaluateJavascript(String source) async {
    try {
      return await _channel.invokeMethod<dynamic>('evalJs', {'jsCode': source});
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> clearCache() async {}

  Future<Map<String, String>> getCookies(String url) async {
    try {
      var result =
          await _channel.invokeMethod<List<dynamic>>('getCookies', {'url': url});
      if (result == null) return {};
      var cookies = <String, String>{};
      for (var item in result) {
        if (item is Map<dynamic, dynamic>) {
          var map = item.map((k, v) => MapEntry(k.toString(), v.toString()));
          cookies[map['name'] ?? ''] = map['value'] ?? '';
        }
      }
      cookies.removeWhere((key, value) => key.isEmpty);
      return cookies;
    } on MissingPluginException {
      return {};
    }
  }

  @override
  void dispose() {
    AppWebview._activeStates.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  _currentUrl,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'WebView is handled by native page'.tl,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(),
        ],
      ),
    );
  }
}

class DesktopWebview {
  static Future<bool> isAvailable() async => true;

  final WebviewOnTitleChange? onTitleChange;
  final WebviewOnNavigation? onNavigation;
  final WebviewOnStarted? onStarted;
  final VoidCallback? onClose;

  final String initialUrl;

  DesktopWebview({
    required this.initialUrl,
    this.onTitleChange,
    this.onNavigation,
    this.onStarted,
    this.onClose,
  });

  static const MethodChannel _channel = MethodChannel('com.venera.webview');

  String? _title;
  String? _ua;

  String? get userAgent => _ua;
  String? get title => _title;

  void open() async {
    _setupMethodCallHandler();
    try {
      await _channel.invokeMethod<void>('open', {'url': initialUrl});
    } on MissingPluginException {
      //
    }
    Future.delayed(const Duration(milliseconds: 200), () {
      onStarted?.call();
    });
  }

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onTitleChanged':
          var t = call.arguments as String?;
          if (t != null) {
            _title = t;
            onTitleChange?.call(t);
          }
          return null;
        case 'onUrlChanged':
          var u = call.arguments as String?;
          if (u != null) {
            onNavigation?.call(u);
          }
          return null;
        case 'onLoadStop':
          return null;
        case 'onClosed':
          onClose?.call();
          return null;
        default:
          return null;
      }
    });
  }

  Future<String?> evaluateJavascript(String source) async {
    try {
      return await _channel.invokeMethod<String>('evalJs', {'jsCode': source});
    } on MissingPluginException {
      return null;
    }
  }

  Future<Map<String, String>> getCookies(String url) async {
    try {
      var result =
          await _channel.invokeMethod<List<dynamic>>('getCookies', {'url': url});
      if (result == null) return {};
      var cookies = <String, String>{};
      for (var item in result) {
        if (item is Map<dynamic, dynamic>) {
          var map = item.map((k, v) => MapEntry(k.toString(), v.toString()));
          cookies[map['name'] ?? ''] = map['value'] ?? '';
        }
      }
      cookies.removeWhere((key, value) => key.isEmpty);
      return cookies;
    } on MissingPluginException {
      return {};
    }
  }

  void close() async {
    try {
      await _channel.invokeMethod<void>('close');
    } on MissingPluginException {
      //
    }
    onClose?.call();
  }
}

Future<void> openUrlInBrowser(String url) async {
  await OhosUrlLauncher.launchUrlString(url);
}
