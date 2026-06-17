import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/history.dart';

/// UI-free data operations for ArkTS DataBridge handlers.
class DataService {
  static Map<String, dynamic> historyToJson(History history) {
    return {
      'id': history.id,
      'title': history.title,
      'subtitle': history.subtitle,
      'cover': history.cover,
      'ep': history.ep,
      'page': history.page,
      'group': history.group,
      'sourceKey': history.sourceKey,
      'time': history.time.millisecondsSinceEpoch,
      'maxPage': history.maxPage,
      'description': history.description,
    };
  }

  static Future<Map<String, dynamic>> exploreLoadPage(
    Map<dynamic, dynamic> args,
  ) async {
    final sourceKey = args['sourceKey']?.toString() ?? '';
    final pageTitle = args['pageTitle']?.toString() ?? '';
    final page = (args['page'] as num?)?.toInt() ?? 1;

    final source = ComicSource.find(sourceKey);
    if (source == null) {
      return {'error': 'Comic source not found: $sourceKey'};
    }

    ExplorePageData? data;
    for (final item in source.explorePages) {
      if (item.title == pageTitle) {
        data = item;
        break;
      }
    }
    if (data == null) {
      return {'error': 'Explore page not found: $pageTitle'};
    }

    if (data.loadPage != null) {
      final res = await data.loadPage!(page);
      if (res.error) {
        return {'error': res.errorMessage};
      }
      return {
        'comics': res.data.map((c) => c.toJson()).toList(),
        'hasMore': res.subData,
      };
    }

    if (data.loadNext != null) {
      final next = page <= 1 ? null : args['next']?.toString();
      final res = await data.loadNext!(next);
      if (res.error) {
        return {'error': res.errorMessage};
      }
      return {
        'comics': res.data.map((c) => c.toJson()).toList(),
        'hasMore': res.subData,
      };
    }

    return {'error': 'Explore page has no loader: $pageTitle'};
  }

  static Map<String, dynamic> getHistory() {
    final histories = HistoryManager().getAll();
    return {
      'histories': histories.map(historyToJson).toList(),
    };
  }

  static Map<String, dynamic> getSettings() {
    return Map<String, dynamic>.from(
      appdata.toJson()['settings'] as Map<String, dynamic>,
    );
  }

  static Map<String, dynamic> setSetting(Map<dynamic, dynamic> args) {
    final key = args['key']?.toString();
    if (key == null || key.isEmpty) {
      return {'error': 'Missing setting key'};
    }
    appdata.settings[key] = args['value'];
    appdata.saveData();
    return {'ok': true};
  }
}
