# HDS_UI 功能缺口盘点（未完全实现清单）

> 基线：分支 `HDS_UI` @ `e67236f`；原生 UI 90 个 `.ets`，Dart 数据层 153 文件 / 51 个 pages 文件。
> 配套文档：[API26_CONFORMANCE.md](API26_CONFORMANCE.md)（API 26 合规）、[NATIVE_MIGRATION_PLAN.md](NATIVE_MIGRATION_PLAN.md)（WS1–WS7 总计划）、[PORT_MAP.md](PORT_MAP.md)（逐模块归属）。
> 本文只记录「已核实」的缺口；未核实项一律标注「待对拍」。

## A.1 功能归属总览

| 分类 | 内容 |
|---|---|
| **原生已实现** | 主壳（4 Tab：Home/Favorites/Explore/Categories）、26 个页面、8 个设置大类、HdsTheme 设计系统、JsUiHost 脚本对话框、WebView 页、认证页、生物识别 + PIN 回退、图片收藏、追更、历史、评论（基础）、漫画源列表/编辑/登录 |
| **原生部分实现** | 阅读器（见 A.3）、收藏（本地/网络收藏合并为一个页面）、设置（8 类齐全但逐键覆盖待对拍）、漫画源（JS 编辑器无高亮）、评论（回复/点赞面）、导入（仅 cbz/zip 能力，文案含 7z） |
| **仍由 Dart 提供** | 全部数据层：JS 引擎与漫画源解析、SQLite 与磁盘格式、HTTP/CF/Cookie/缓存、下载与 WebDAV 同步、导出、图片处理……通过 7 条 MethodChannel + DataBridge 100+ 方法暴露（见 A.4） |
| **明确不做** | 7z/rar 本地漫画（原实现依赖外置 `7z`，鸿蒙不支持）、PDF/EPUB 导出（当前仅 cbz 可用） |

## A.2 页面级规模对比（Dart 行数 vs 原生行数）

行数是欠实现的近似指标，用于排优先级；不是验收标准。

| 模块 | Dart | 原生 | 判定 |
|---|---|---|---|
| 阅读器 | `reader/images.dart` 1570 + `scaffold.dart` 1234 + `reader.dart` 861 + `chapter_comments.dart` 877 ≈ **4542** | ReaderPage 842 + ReaderViewModel 713 + ReaderImage 215 + ImageDataSource 62 + ImageSizeCache 36 ≈ **1868** | **欠实现（第一优先级）** |
| 漫画源 | `comic_source_page.dart` **1293** | ComicSourcePage 602 + ComicSourceEditPage 87 + CodeEditor 56 = 745 | **欠实现** |
| 收藏 | `local_favorites_page` 1224 + `network_favorites_page` 597 + `favorite_actions` 510 + `side_bar` 303 ≈ **2634** | FavoritesPage 925 + MultiPagesFilter 290 = 1215 | **欠实现** |
| 设置 | `settings/*` ≈ **3000+** | SettingsCategoryContent 1323（8 大类齐全） | 逐键对拍后定 |
| 详情 | `comic_page` 1083 + `favorite` 626 + `actions` 423 | ComicDetailPage 852 + CoverViewerPage 191 + ChapterPickerSheet 59 | 欠实现（收藏/操作项） |
| 搜索 | `search_page` 706 + `search_result_page` 532 + `aggregated_search_page` | SearchPage 248 + SearchResultPage 172 + AggregatedSearchPage 187 = 607 | 欠实现 |
| 首页 | `home_page.dart` 1148 | HomePage 639 | 欠实现 |
| 本地漫画 | `local_comics_page.dart` 638 | LocalComicsPage 421 | 欠实现 |
| 追更 | `follow_updates_page.dart` 597 | FollowUpdatesPage 346 | 欠实现 |
| 图片收藏 | `image_favorites_page` 541 | ImageFavoritesPage 271 + PhotoPage 90 | 欠实现 |
| 历史 | `history_page.dart` 337 | HistoryPage 247 | 基本对齐 |
| WebView | `webview.dart` 547 | WebViewPage 265 + WebViewBridge 275 | 基本对齐 |

## A.3 已核实的原生缺陷（逐条进入 WS4/WS5）

| # | 缺陷 | 证据（文件:行） | 要求行为 | 归属 |
|---|---|---|---|---|
| 1 | 阅读器状态栏**只有时钟、无电池**；时钟 30s 刷新、居中 y=4、fontSize 12，均与 Flutter 规格不符 | `ReaderPage.ets:663-672`、`61-64` | `Positioned(bottom:13,right:25)`、HH:mm 1s 刷新、电池 SOC/充电阈值文案（充电/≥96/84/72/60/48/36/24/12/<12 红），受 `enableClockAndBatteryInfoInReader` 控制；读取逻辑复用 `PlatformBridge.ets:490-520`，抽成 `utils/BatteryUtil.ets` | WS4 |
| 2 | 启动参数**类型/语义错乱**：`RouterUtil.openReader` 写 `initialEp: string`（默认 `'1'`）、`initialPage` 默认 1；`ReaderPage` 用 `@StorageLink initialEp: number = 0`、`initialPage: number = 0` | `RouterUtil.ets:222-229`、`ReaderPage.ets:21-22,55-56` | 统一为 `initialEp: string`（与 ReaderBridge/DataBridge 一致）+ `initialPage: number` 1-based；与 Dart `reader.dart`/`app_page_route.dart` 对拍确认基准 | WS4 |
| 3 | 阅读模式切换**不落盘**（只改内存） | `ReaderPage.ets:692-698` | 经 DataService 写回设置并触发 settingsVersion，重启后保持 | WS4 |
| 4 | 假进度条：加载态固定 `Progress({ value: 40 })` | `ReaderImage.ets:143` | 用真实下载/解码进度或尺寸探测结果 | WS4 |
| 5 | **无列表虚拟化**（全仓 `LazyForEach` 0 命中；`ImageDataSource.ets` 已存在但未用于阅读器） | grep `LazyForEach` = 0 | 连续模式改 `LazyForEach` + IDataSource，长章节不卡顿 | WS4 |
| 6 | 连续 LR/RL 实为竖排（与规格「横向」不符） | `ReaderPage.ets:420,681-686` | 横向排布 + 160vp 过滚翻章 + 进度药丸 | WS4 |
| 7 | 章节入口疑似把 chapter id 当 ep/索引传递 | `ComicDetailPage.ets:679,704` → `openReader(id, sourceKey, id, 1)` | WS4 用 Dart 相同入参对拍，确认 ep 语义后修正 | WS4 |
| 8 | 缩放/平移能力未证实（仅传入 `enableDoubleTapZoom`/`enableLongPressZoom`，无平移实现证据） | `ReaderPage.ets:173-223,431-432`；Dart `reader/gesture.dart` 373 行 | 双击 1.75×、长按（press/center）、双指 1.0–2.5、缩放后平移 | WS4 |
| 9 | 章末评论/评论面欠实现（回复、点赞、分页） | 原生 ReaderPage 内联 + CommentsPage 262 vs Dart `chapter_comments` 877 + `comments_page` 578 | 按 Dart 行为补齐 | WS5 |
| 10 | 漫画源 JS 编辑器无语法高亮 | `CodeEditor.ets`（行号 + TextArea，56 行）；Dart 用 syntax_highlight（HAP 内已有 themes/grammars） | 引入高亮或明确降级并记录 | WS5 |
| 11 | 导入对话框文案声称支持 `cbz, zip, 7z, cb7`，实际委托 Dart（鸿蒙无 7z） | `ImportComicsDialog.ets:71`；Dart `ohos_7zip.dart` | 文案与实际能力对齐（cbz/zip） | WS5 |
| 12 | 硬编码英文与颜色（未走 i18n/主题资源）；`safeAreaTop` 传入阅读器但未用于布局 | grep | 清理为 TranslationUtil/主题资源 | WS4/WS5 |

## A.4 仍由 Dart 承担的能力（映射到 WS）

| 领域 | 原生入口（ArkTS） | WS |
|---|---|---|
| 设置读写、appdata/syncdata/implicitData | `DataBridge.getSettings/updateSetting`、`SettingsMirror` | WS1 |
| SQLite（cookie/cache/local_favorite/history/local） | `DataBridge.*History/*Favorite/*Cache` | WS1 |
| HTTP、Cookie、CF、图片下载与缓存 | `DataBridge.*`、`PlatformBridge.getWebCookies` | WS2 |
| 漫画源 JS（loadInfo/loadEp/search/explore/category/modifyImage） | `DataBridge.*`、`ComicSourcePage` | WS3 |
| 下载队列、WebDAV 同步、.venera 导入导出 | `DataBridge.pauseDownload/resumeDownload/webdav*` | WS5 |
| 标签翻译（opencc） | `TranslationUtil` + `rawfile/translation.json` | 部分原生（WS5 校核） |

## A.5 明确不做（继承既有假设）

1. 7z/rar 本地漫画（原实现 `Process.run("7z")`，鸿蒙无对应能力）。
2. PDF/EPUB 导出（当前仅 cbz）。
