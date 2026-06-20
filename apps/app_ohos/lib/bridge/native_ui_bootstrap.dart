import 'package:venera/bridge/data_bridge.dart';
import 'package:venera/bridge/js_ui_channel.dart';
import 'package:venera/bridge/reader_channel.dart';
import 'package:venera/bridge/webview_channel.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/foundation/js_engine.dart';
import 'package:venera/services/reader_service.dart';

/// Registers MethodChannel handlers when ArkTS renders the native shell.
class NativeUiBootstrap {
  static void _saveWebViewCookies(List<Map<String, String>> cookies) {
    if (cookies.isEmpty) {
      return;
    }
    final url = cookies.first['domain'] ?? '';
    if (url.isEmpty) {
      return;
    }
    JsEngine().handleCookieCallback({
      'function': 'set',
      'url': url,
      'cookies': cookies,
    });
  }

  static Future<void> registerWebViewHandlers() async {
    WebViewChannel.registerHandlers(
      onCookiesReceived: _saveWebViewCookies,
      onCloudflareDetected: (_) {},
      onCloudflareResolved: _saveWebViewCookies,
    );
  }

  static Future<void> registerReaderHandlers() async {
    ReaderChannel.registerHandlers(
      onLoadData: ReaderService.loadData,
      onLoadChapterImages: ReaderService.loadChapterImages,
      onLoadImage: ReaderService.loadImageFromArgs,
      onUpdateHistory: ReaderService.updateHistory,
      onGetSettings: ReaderService.getSettings,
      onAddImageFavorite: (_) async => {'ok': false},
      onRead: (args) async {
        final id = args['id']?.toString() ?? '';
        final sourceKey = args['sourceKey']?.toString() ?? '';
        if (id.isNotEmpty) {
          LocalFavoritesManager().onRead(id, ComicType.fromKey(sourceKey));
        }
      },
      onClosed: () async {},
    );
  }

  static Future<void> start() async {
    DataBridge.registerHandlers();
    installDataBridgeSettingsListener();
    JsUiChannel.registerHandlers();
    await registerWebViewHandlers();
    await registerReaderHandlers();
  }
}
