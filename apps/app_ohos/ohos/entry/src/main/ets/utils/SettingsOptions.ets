export class SettingsOptions {
  static comicDisplay(): Map<string, string> {
    let m: Map<string, string> = new Map();
    m.set('detailed', 'Detailed');
    m.set('brief', 'Brief');
    return m;
  }

  static initialPage(): Map<string, string> {
    let m: Map<string, string> = new Map();
    m.set('0', 'Home Page');
    m.set('1', 'Favorites Page');
    m.set('2', 'Explore Page');
    m.set('3', 'Categories Page');
    return m;
  }

  static comicListDisplay(): Map<string, string> {
    let m: Map<string, string> = new Map();
    m.set('paging', 'Paging');
    m.set('Continuous', 'Continuous');
    return m;
  }

  static readerMode(): Map<string, string> {
    let m: Map<string, string> = new Map();
    m.set('galleryLeftToRight', 'Gallery (Left to Right)');
    m.set('galleryRightToLeft', 'Gallery (Right to Left)');
    m.set('galleryTopToBottom', 'Gallery (Top to Bottom)');
    m.set('continuousLeftToRight', 'Continuous (Left to Right)');
    m.set('continuousRightToLeft', 'Continuous (Right to Left)');
    m.set('continuousTopToBottom', 'Continuous (Top to Bottom)');
    return m;
  }

  static themeMode(): Map<string, string> {
    let m: Map<string, string> = new Map();
    m.set('system', 'System');
    m.set('light', 'Light');
    m.set('dark', 'Dark');
    return m;
  }

  static color(): Map<string, string> {
    let m: Map<string, string> = new Map();
    m.set('system', 'System');
    m.set('red', 'Red');
    m.set('pink', 'Pink');
    m.set('purple', 'Purple');
    m.set('green', 'Green');
    m.set('orange', 'Orange');
    m.set('blue', 'Blue');
    return m;
  }

  static favoriteAddTo(): Map<string, string> {
    let m: Map<string, string> = new Map();
    m.set('start', 'Start');
    m.set('end', 'End');
    return m;
  }

  static moveFavoriteAfterRead(): Map<string, string> {
    let m: Map<string, string> = new Map();
    m.set('none', 'None');
    m.set('end', 'End');
    m.set('start', 'Start');
    return m;
  }

  static onClickFavorite(): Map<string, string> {
    let m: Map<string, string> = new Map();
    m.set('viewDetail', 'View Detail');
    m.set('read', 'Read');
    return m;
  }

  static language(): Map<string, string> {
    let m: Map<string, string> = new Map();
    m.set('system', 'System');
    m.set('zh-CN', '简体中文');
    m.set('zh-TW', '繁體中文');
    m.set('en-US', 'English');
    return m;
  }

  static autoAddLanguageFilter(): Map<string, string> {
    let m: Map<string, string> = new Map();
    m.set('none', 'None');
    m.set('chinese', 'Chinese');
    m.set('english', 'English');
    m.set('japanese', 'Japanese');
    return m;
  }

  static quickCollectImage(): Map<string, string> {
    let m: Map<string, string> = new Map();
    m.set('No', 'Not enable');
    m.set('DoubleTap', 'Double Tap');
    m.set('Swipe', 'Swipe');
    return m;
  }

  static longPressZoomPosition(): Map<string, string> {
    let m: Map<string, string> = new Map();
    m.set('press', 'Press position');
    m.set('center', 'Screen center');
    return m;
  }

  static proxy(): Map<string, string> {
    let m: Map<string, string> = new Map();
    m.set('direct', 'Direct');
    m.set('system', 'System');
    return m;
  }

  static labelFor(options: Map<string, string>, value: string, tl: (key: string) => string): string {
    let label: string | undefined = options.get(value);
    if (label === undefined) {
      return value;
    }
    return tl(label);
  }

  static keys(options: Map<string, string>): string[] {
    let result: string[] = [];
    options.forEach((_value: string, key: string) => {
      result.push(key);
    });
    return result;
  }
}
