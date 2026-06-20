export interface SettingCategory {
  key: string;
  icon: Resource;
  iconColor: ResourceColor;
}

export const PROJECT_REPO_URL = 'https://github.com/Twopuding/venera-harmony/tree/HDS_UI';

export const APP_VERSION_FALLBACK = '0.1.0';

export const DEFAULT_COMIC_SOURCE_LIST_URL =
  'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/index.json';

export const COMIC_SOURCE_HELP_URL =
  'https://github.com/venera-app/venera/blob/master/doc/comic_source.md';

export const IMPORT_COMIC_HELP_URL =
  'https://github.com/venera-app/venera/blob/master/doc/import_comic.md';

export const SETTING_CATEGORIES: SettingCategory[] = [
  { key: 'Explore', icon: $r('sys.symbol.compass'), iconColor: '#317AF7' },
  { key: 'Reading', icon: $r('sys.symbol.book'), iconColor: '#64BB5C' },
  { key: 'Appearance', icon: $r('sys.symbol.paintbrush'), iconColor: '#FF7500' },
  { key: 'Local Favorites', icon: $r('sys.symbol.bookmark'), iconColor: '#AC49F5' },
  { key: 'APP', icon: $r('sys.symbol.square_grid_2x2'), iconColor: '#E84026' },
  { key: 'Network', icon: $r('sys.symbol.link'), iconColor: '#0A59F7' },
  { key: 'About', icon: $r('sys.symbol.info_circle'), iconColor: '#999999' },
  { key: 'Debug', icon: $r('sys.symbol.exclamationmark_triangle'), iconColor: '#F7CE00' }
];
