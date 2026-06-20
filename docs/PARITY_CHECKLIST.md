# HarmonyOS Native UI vs Flutter Parity Checklist

Use with `devecocli build` → `devecocli run` (`useNativeUi=true`).

## Shell

| Route | Core checks |
|-------|-------------|
| Index / MainShell | 4 tabs, initial tab from settings, Search/Settings header actions, all tabs load within ~30s (no infinite spinner) |
| AuthPage / AuthGate | Biometric gate, back exits app |

## Tabs

| Page | Core checks |
|------|-------------|
| HomePage | History/local/follow-up/source/image-fav cards, WebDAV sync, search bar, source update badge, image-fav chart keywords, cold start must not spin forever |
| FavoritesPage | Local + network folders, reorder, multi-select, export, download |
| ExplorePage | Multi-tab feeds, pagination, filter dialog, scroll-to-top on re-tap |
| CategoriesPage | Category parts, ranking link, random refresh, filter dialog |

## Search

| Page | Core checks |
|------|-------------|
| SearchPage | Per-source / aggregated toggle, history, tags, URL resolve |
| SearchResultPage | Filters, pagination |
| AggregatedSearchPage | Grouped results, drill-down |

## Comic

| Page | Core checks |
|------|-------------|
| ComicDetailPage | Metadata, grouped chapters, like, favorite, download, comments preview |
| CoverViewerPage | Fullscreen cover, save to file |
| CommentsPage | Load/post/reply, vote |

## Reader

| Page | Core checks |
|------|-------------|
| ReaderPage | 6 modes, multi-image layout settings, zoom, volume keys, chapter comments, image collect |

## Library

| Page | Core checks |
|------|-------------|
| HistoryPage | Multi-select delete, refresh item, resume reading |
| LocalComicsPage | Import CBZ/folder, export, delete, open reader |
| DownloadingPage | Pause/resume/cancel, reorder |
| FollowUpdatesPage | Folder filter, check updates |
| ImageFavoritesPage | Sort/filter, multi-delete |
| ImageFavoritesPhotoPage | Open reader at page |

## Settings & sources

| Page | Core checks |
|------|-------------|
| SettingsPage | 8 categories, 50+ toggles, WebDAV, DNS, JS console |
| AboutPage | Version, check update, links |
| LogsPage | Log viewer |
| ComicSourcePage | Add/import/update, comic source list page, per-source settings, WebView login, batch updates |
| ComicSourceListPage | Default index.json URL, catalog add/checkmark, repo URL edit |
| ComicSourceEditPage | Edit/save script |
| ComicSourceLoginPage | Password/cookie/WebView login |
| WebViewPage | Navigation, cookies, Cloudflare |

## Bridge / system

| Area | Core checks |
|------|-------------|
| Deep link | `onNewWant` URI → ComicDetail |
| Share text | `onNewWant` text → AggregatedSearch |
| Reader settings sync | 5 advanced reader settings apply in reader |
| JS UI | showMessage/showDialog from comic source scripts |
| Block keywords | Blocked comics hidden; long-press block adds word |
