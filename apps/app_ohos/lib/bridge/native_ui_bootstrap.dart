import 'package:venera/bridge/data_bridge.dart';
import 'package:venera/bridge/reader_channel.dart';
import 'package:venera/services/reader_service.dart';

/// Registers MethodChannel handlers when ArkTS renders the native shell.
class NativeUiBootstrap {
  static Future<void> start() async {
    DataBridge.registerHandlers();
    installDataBridgeSettingsListener();
    ReaderChannel.registerHandlers(
      onLoadData: ReaderService.loadData,
      onLoadChapterImages: ReaderService.loadChapterImages,
      onLoadImage: ReaderService.loadImage,
      onUpdateHistory: ReaderService.updateHistory,
      onGetSettings: ReaderService.getSettings,
      onAddImageFavorite: (_) async => {'ok': false},
      onRead: (_) async {},
      onClosed: () async {},
    );
  }
}
