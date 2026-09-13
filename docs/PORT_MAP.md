# PORT_MAP：Dart 数据层 → ArkTS/API 26 原生实现归属表

配合 [NATIVE_MIGRATION_PLAN.md](NATIVE_MIGRATION_PLAN.md) 使用。本表是「哪个 Dart 文件迁到哪个 ets 模块、由哪个 WS 负责」的唯一对照，用于拆分任务与验收。
原则：**原生 UI/桥接保持 HDS_UI 现状；本表覆盖的是仍需原生化（进而删除）的 Dart 逻辑**。

## 1. 模块映射

| Dart（apps/app_ohos/lib） | 行数 | ArkTS 目标 | WS | 要点 |
|---|---|---|---|---|
| foundation/appdata.dart | 378 | core/SettingsStore.ets + core/ImplicitStore.ets | WS1 | 60+ 设置键、三级覆盖（comic "cid@sourceKey" / device deviceId / global）、appdata.json + syncdata.json + implicitData.json |
| foundation/log.dart | 80 | core/Log.ets | WS1 | logs.txt，500 条环形缓冲 |
| foundation/cache_manager.dart | 230 | store/CacheDao.ets + net/CacheManager.ets | WS2 | cache/<00..99>/<md5(key)>，TTL 7d（命中续期），按 cacheSize(默认 2048MB) 淘汰，启动扫描对账 |
| foundation/history.dart | 470 | store/HistoryDao.ets | WS1 | history 表 + chapter_group 迁移；ep/page 1-based；readEpisode 逗号集合 |
| foundation/favorites.dart | 900 | store/FavoriteDao.ets | WS1 | folder_order / folder_sync / 每文件夹一表 + 4 个 ALTER 迁移；重排/搜索/分组事务 |
| foundation/local.dart | 560 | store/LocalDao.ets + net/DownloadManager.ets | WS5 | local.db(comics)、local_path、downloading_tasks.json、章节文件 <index><ext>、.nomedia |
| foundation/image_favorites.dart | 420 | store/ImageFavoriteDao.ets | WS5 | image_favorites 表（image_favorites_ep / other 为 JSON） |
| foundation/follow_updates.dart | 130 | store/FollowUpdates.ets | WS5 | 追更扫描、has_new_update/last_check_time |
| foundation/js_engine.dart | 758 | jsrt/JsRuntime.ets + cpp/qjs | WS3 | sendMessage 全 method、Promise/A promise 桥、看门狗与内存上限 |
| foundation/js_pool.dart | 163 | jsrt/JsPool.ets | WS3 | 4 个 worker，最少待办调度，仅服务 JS compute() |
| foundation/comic_source/models.dart | 561 | source/models.ets | WS3 | Comic / ComicDetails / ComicChapters（平铺或分组）/ Comment |
| foundation/comic_source/parser.dart | 1301 | source/ComicSourceParser.ets | WS3 | class X extends ComicSource 发现、key 正则、minAppVersion、settings/translation/category/favorites/account/explore/ranking/archive/link/tag |
| foundation/comic_source/comic_source.dart | 546 | source/ComicSourceManager.ets | WS3 | 源注册表、load/save/delete data、reload、URL/目录更新 |
| foundation/comic_source/category.dart / favorites.dart / types.dart | 302 | source/category.ets / source/favorites.ets / source/types.ets | WS3 | 分类部件（fixed/random/dynamic）、收藏契约 |
| network/app_dio.dart | 210 | net/HttpClient.ets | WS2 | 超时 15s、拦截器链（Cookie → ResponseCache → Cloudflare → Log）、prevent-parallel 串行 |
| network/ohos_http_adapter.dart | 226 | net/HttpClient.ets | WS2 | 代理、ignoreBadCertificate、DNS 覆盖 + Host、表单编码、流式响应 |
| network/cookie_jar.dart | 240 | net/CookieJar.ets + store/CookieDao.ets | WS2 | cookie.db、域/路径匹配、Set-Cookie 解析、WebView 注入（HttpOnly cf_clearance） |
| network/cache.dart | 200 | net/ResponseCache.ets | WS2 | 10MB 内存缓存、cache-time 语义、HEAD 复核、venera-cache 头 |
| network/cloudflare.dart | 400 | net/Cloudflare.ets | WS2 | cf-mitigated: challenge 侦测、WebView 轮询收割、placeholder 回退 |
| network/webview_fetch.dart | 430 | net/WebviewFetch.ets | WS2 | 同源 fetch() 兜底、base64 上限 12MB、导航读页回退 |
| network/images.dart | 400 | net/ImageDownloader.ets | WS2/WS4 | 缓存键 imageKey@sourceKey@cid@eid、去重、onImageLoad 配置、onLoadFailed 重试 ≤5、CF 兜底 |
| network/download.dart + file_downloader.dart | 800 | net/DownloadManager.ets + net/FileDownloader.ets | WS5 | 章节/压缩包任务、并发 downloadThreads、.download 边车续传、downloading_tasks.json |
| network/proxy.dart | 60 | net/Proxy.ets | WS2 | direct/system/自定义；connection.getDefaultHttpProxy |
| utils/data.dart | 300 | net/WebDAV.ets + utils/AppDataExport.ets | WS5 | .venera ZIP 导出/导入、dataVersion、保留 10 份 |
| utils/data_sync.dart | 200 | net/WebDAV.ets | WS5 | WebDAV 上传/下载、同日去重 |
| utils/io.dart | 280 | utils/Io.ets（部分已原生：PlatformBridge） | WS5 | 分享/保存/选择器/打开链接（直接调用 @kit 能力，去掉通道） |
| utils/image.dart | 321 | jsrt/ImageScript.ets | WS3 | modifyImage / processImage 精简引擎（RGBA 位图 + 编解码） |
| utils/cbz.dart / ohos_zip.dart / epub.dart / pdf.dart | 900 | utils/Archive.ets（@ohos.zlib） | WS5 | CBZ 导入导出、EPUB/PDF（现状仅 cbz 可用，不扩） |
| utils/import_comic.dart | 420 | utils/ImportComic.ets | WS5 | file/directory/multipleCbz/localDownloads/scan/ehViewer |
| utils/opencc.dart / tags_translation.dart / translations.dart | 300 | core/I18n.ets + core/OpenCC.ets | WS1 | rawfile/opencc.txt、tags.json、translation.json |
| platform/ohos_platform_services.dart | 240 | 已原生（PlatformBridge.ets） | WS2 | 去掉通道，页面/服务直接调用 |
| platform/ohos_super_resolution.dart | 100 | reader/SuperResolution.ets | WS4 | CoreVisionKit（API 26 门控），缓存键 sr_cv@... |
| bridge/*（data_bridge、reader_channel、js_ui_channel、native_ui_bootstrap 等） | 700 | 删除（改为进程内调用） | WS6 | 方法名作为 DataService 门面的迁移期别名 |
| services/data_service.dart | 2360 | 拆分到 store/net/source/* | WS2–WS5 | 100+ 方法的业务实现，逐域下沉 |
| services/reader_service.dart | 318 | reader/ReaderService.ets | WS4 | 章节图片、历史、设置、自定义图片处理 |

## 2. 通道方法清单（按域）→ 原生归属

删除的通道：com.venera.data、com.venera.reader、com.venera.jsui、com.venera.settings、com.venera.webview、venera/method_channel、venera/{text_share,volume}。
下表按域列出需要原生化实现的方法（方法名即迁移期 DataService 门面的别名）。

| 域 | 方法（读/写） | 目标模块 |
|---|---|---|
| 设置 | getSettings, getSettingsJson, setSetting, setReaderSetting, setComicSpecificSettingsEnabled | core/SettingsStore |
| 探索/搜索 | pingBackend, exploreLoadPage, getExploreConfig, getCategoryConfig, getCategoryParts, categoryLoadPage, randomCategoryRefresh, search, aggregatedSearch, getSearchOptions, getSearchHistory, clearSearchHistory, getSearchTagSuggestions, resolveComicLink, loadRanking | source/* + store/HistoryDao |
| 详情 | loadComicInfo, likeComic | source/ComicSourceManager |
| 章节/图片（阅读器） | onLoadData, onLoadChapterImages, onLoadImage, onUpdateHistory, onGetSettings, onRead, onClosed | reader/ReaderService + reader/SuperResolution |
| 收藏 | getFavoriteFolders, getFavorites, loadNetworkFavorites, loadFavoriteFoldersRemote, getFavoriteFolderCounts, getLocalFavoriteFolderNames, getNetworkFavoriteSources, createFavoriteFolder, deleteFavoriteFolder, addFavorite, removeFavorite, reorderFavorites, updateFavoriteInfo, markFavoriteAsRead, removeInvalidFavorites | store/FavoriteDao + source/favorites |
| 历史/追更 | getHistory, deleteHistory, clearHistory, refreshHistory, getComicTileStatuses, getFollowUpdatesSummary, getFollowUpdatesList, checkFollowUpdates, setFollowUpdatesFolder | store/HistoryDao + store/FollowUpdates |
| 本地漫画 | getLocalComics, deleteLocalComic, importComicFromPath, importLocalComic | store/LocalDao + utils/ImportComic |
| 下载/导出 | getDownloadTasks, pauseDownload, resumeDownload, cancelDownload, moveDownloadToFirst, startDownload, getComicArchives, downloadComicArchive, downloadFavoriteComics, exportComics | net/DownloadManager + utils/Archive |
| 图片收藏 | getImageFavorites, getImageFavoriteImages, addImageFavorite, deleteImageFavorites, computeImageFavoritesChart | store/ImageFavoriteDao |
| 漫画源 | getComicSources, checkComicSourceUpdates, removeComicSource, addComicSourceFromUrl, importComicSourceFromContent, updateComicSource, readComicSourceFile, saveComicSourceFile, reloadJsEngine, getComicSourceSettings, setComicSourceSetting, getComicSourceAccountConfig, comicSourceLogin, comicSourceLogout, comicSourceRelogin, comicSourceWebViewLoginCheck, invokeComicSourceCallback, fetchComicSourceCatalog | source/ComicSourceManager + jsrt/* |
| 评论 | loadComments, postComment, loadChapterComments, likeComment, voteComment | source/ComicSourceManager |
| 同步/导出 | getSyncStatus, webdavUpload, webdavDownload, exportAppData, importAppData | net/WebDAV + utils/AppDataExport |
| 杂项 | getAppInfo, clearCache, getAppLogs, runJsCode, checkForUpdate, loadCoverImage | core/* + jsrt/JsRuntime |
| JS-UI（jsui） | showMessage, showDialog, showInputDialog, showSelectDialog, showLoading, cancelLoading（+ 回调 onDialogAction/onInputResult/onSelectResult/onLoadingCancel） | jsrt/JsUi（已原生，改为进程内调用） |
| WebView | open, evaluateJs/evalJs, getCurrentUrl, getCookies, loadUrl, clearCookies, close（+ onCookiesReceived/onCloudflareDetected/onCloudflareResolved/onUserAgentReceived/onClosed） | net/Cloudflare + webviewability（已原生） |

## 3. 已在原生侧完成、无需再迁的部分

- 全部页面与组件（pages/components/design/navigation，共 86 个 .ets）。
- 认证（userAuth ATL2→ATL3/PIN 回退）、文件选择/保存、分享、打开链接、电池、屏幕常亮、代理读写、缓存统计/清理、内存查询。
- WebView 能力：WebViewAbility + WebViewPage（CF 侦测、cookie 抓取、登录检查）、WebViewBridge（open/close/evaluateJs/evalJs/getCookies/getCurrentUrl/loadUrl/clearCookies）。
- 本轮合并新增：PlatformBridge.getWebCookies（WebCookieManager.saveCookieAsync → fetchCookieSync）；WebViewBridge.onCloudflareResolved 载荷 {url, cookies: 字符串, userAgent} + WebViewPage.getUserAgent()。
- JS-UI 宿主：JsUiHost.ets + JsUiBridge.ets。

## 4. 删除清单（WS6）

apps/app_ohos/lib、assets、stubs、test、pubspec.yaml、pubspec.lock、.dart_tool、build、ohos/entry/src/main/resources/rawfile/flutter_assets、entry/libs/**/libapp.so、entry/libs/**/libflutter.so、plugins/{flutter_qjs,flutter_inappwebview_repo,sqlite3_ohos}、flutter-hvigor-plugin 依赖（hvigorfile.ts / package.json）、scripts/build-hap-release.*（改写为纯 devecocli 流程）。
保留：entry/libs/**/libqjs.so、libsqlite3.so、libc++_shared.so（供 NAPI 模块链接）与 rawfile 下的 assets（init.js 等）。
