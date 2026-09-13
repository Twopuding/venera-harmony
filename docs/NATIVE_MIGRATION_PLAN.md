# Venera HarmonyOS：以 API 26 原生实现替代 Flutter（迁移计划）

> 状态快照：Git 收敛（A1/A2/A3）已在本地完成，见本文末尾「Git 收敛记录」。
> 本文件是唯一权威计划；配合 [PORT_MAP.md](PORT_MAP.md)（逐模块/逐接口归属）与 [PARITY_CHECKLIST.md](PARITY_CHECKLIST.md)（回归清单）使用。

## 1. 目标与成功标准

**目标**：在 HDS_UI 基线上把仍由 Dart（headless）承担的数据层全部原生化（ArkTS / API 26），最终删除 Flutter/Dart，产出单一原生应用；保持功能与磁盘数据格式与 Flutter 版（1.6.5）兼容。

**成功标准（可验证）**

1. HAP 内无 libflutter.so / libapp.so / flutter_assets；仓库无 dart / pubspec。
2. HarmonyOS 7.0.0(26.0.0)（模拟器 Pura 90 Pro / PuddingTest + 1 台真机）冷启动进主壳。
3. 阅读器与参考截图逐项对齐：章名 + 页码（page/maxPage）+ 时钟 + 电池、六种阅读模式、缩放与平移、过滚翻章；设备截图并排比对通过。
4. 真实漫画源端到端：更新源 → 搜索 → 详情 → 阅读 → 收藏 → 历史恢复。
5. .venera 可双向导入导出；appdata.json / cookie.db / cache / local 目录与旧版互操作。
6. devecocli build（debug/release）与 devecocli check lint 全绿；阅读器滚动 ≥55fps；图片缓存跨重启零重下。

## 2. 现状（已核实）

| 事实 | 说明 |
|---|---|
| Dart 代码量 | apps/app_ohos/lib 共 45,851 行 / 148 文件（pages 22.5k、components 7.8k、foundation 8.3k 含 comic_source 2.3k、network 2.8k、utils 3.0k、platform 0.4k、bridge 0.3k） |
| 原生 UI 已完成 | HDS_UI 分支 86 个 .ets / 18,955 行：MainShell、26 个页面、HdsTheme(UIDesignKit)、原生 ReaderPage/ReaderViewModel/ReaderImage、DataBridge/DataService（门面）、JsUiHost、RouterUtil |
| 剩余范围 | 仅 Dart 数据层（约 15k 行逻辑）未原生化：JS 引擎、解析器、存储、网络、下载、同步、导出 |
| 通信 | 7 条 MethodChannel/EventChannel：com.venera.data、com.venera.reader、com.venera.jsui、com.venera.settings、com.venera.webview、venera/method_channel、venera/{text_share,volume}；DataBridge/DataService 暴露 100+ 读写方法 |
| SDK | API 26（platformVersion 26.0.0 / 26.0.0.32 Beta2）；NAPI 头文件位于 sdk/default/openharmony/native/sysroot/usr/include/napi |
| 随包原生库 | entry/libs/{arm64-v8a,x86_64}/：libqjs.so、libsqlite3.so、libc++_shared.so（libapp.so / libflutter.so 待删） |
| 参考截图 | 底部「章名 + 页码 + 时钟 + 电池」与 Flutter scaffold.dart 的 buildPageInfoText()/buildStatusInfo() 一致；HDS 原生阅读器只有时钟无电池 → 截图为 Flutter 版，作为阅读器验收基准 |

## 3. 工作流（WS）与验收门

| WS | 内容 | 关键交付物 | 验收门 | 估算 |
|---|---|---|---|---|
| WS1 原生核心 | 路径（filesDir/cacheDir，弃用 OHOS_APP_* 环境变量）、SettingsStore（60+ 键 + 三级覆盖 + appdata/syncdata/implicitData）、Log、rawfile 资产、I18n、Crypto/Convert（GBK 用 util.TextDecoder）、NAPI sqlite3 包装 + Db 门面 + 5 库 DDL/迁移 | core/*、store/*、cpp/sqlite3_napi.c | GBK 往返、AES-CFB(blockSize)、RSA 解密、设置三级解析、sqlite_master 与 Dart 建库一致 | 5–8d |
| WS2 网络与 CF | @ohos.net.http + connection（代理/超时/Host/Range）、CookieJar（cookie.db）、ResponseCache、Cloudflare 拦截 + 原生 getWebCookies/evalJs/getCookies/WebviewFetch、ImageDownloader + CacheManager（md5 分桶 / 7d TTL / cacheSize 淘汰） | net/* | 真实抓页、Cookie 跨重启、缓存命中免网、CF 源可过、淘汰生效 | 8–12d |
| WS3 漫画源引擎（关键路径） | NAPI QuickJS（迁入 quickjs-ng + ffi.cpp 语义）、sendMessage 全 method、看门狗/内存上限、JS 侧 DOM（rawfile/dom.js 取代 Dart package:html）、JsPool(4)、models/parser/comic_source/category/favorites、modifyImage 精简引擎 | cpp/qjs、jsrt/*、source/* | ≥10 个真实源在原生引擎下 loadInfo/loadEp/search/explore/category 回调与 Flutter 版 JSON 一致；死循环被中止；modifyImage 可跑 | 15–25d |
| WS4 阅读器闭环（截图验收） | 原生章节图片（远程源 + 本地文件）、尺寸探测列表高度、LRU、SR（CoreVisionKit）、历史读写、三级阅读设置；补齐 HDS 阅读器缺陷（连续 LR/RL 横向、缩放平移、电池、LazyForEach 虚拟化、真进度、错误重试、六模式、章节/设置/评论抽屉、浮动词章按钮、音量键、沉浸切换） | pages/ReaderPage、viewmodel/ReaderViewModel、components/Reader*、reader/* | 截图逐项比对 + 六模式 + 缩放平移 + 历史恢复 + 缓存复用 | 10–15d |
| WS5 资料库与应用 | 收藏（本地文件夹表/网络收藏）、历史页、本地漫画导入（cbz/zip）+ 下载管理（并发/暂停/续传 + 后台保活）、导出（cbz/pdf/epub）、图片收藏、追更、评论、WebDAV + .venera 导入导出、opencc/标签翻译 | store/*、net/WebDAV、pages/* | .venera 双向互操作；旧数据原地升级 | 15–20d |
| WS6 去 Flutter | EntryAbility 继承 UIAbility；删 lib/assets/stubs/test/pubspec/plugins/flutter_assets/libapp.so；hvigorfile/package.json 去 flutter-hvigor-plugin；build-hap-release.* 改为纯 devecocli；删 useNativeUi 开关 | 构建配置、脚本、README | 仓库无 flutter 产物；HAP 体积与 29.2MB 基线对比 | 2–3d |
| WS7 回归发布 | PARITY_CHECKLIST 扩充、性能（冷启动/帧率/内存/缓存命中）、真机与模拟器矩阵、签名 release HAP、lint | docs/* | 全部清单通过 | 5d |

执行顺序：先做 1 天 **NAPI PoC**（复用 flutter_inappwebview_ohos 的 CMakeLists/napi_init.cpp 模板）→ WS1 → WS2 → WS3 → WS4 → WS5 → WS6 → WS7。若 PoC 失败，WS3 切备选方案 B（隐藏 ArkWeb + runJavaScript + JavaScriptProxy 承载脚本运行时，天然带 DOMParser，可省 JS DOM）。合计约 60–90 人日（单人）。

## 4. 关键技术决策（不可随意变更）

1. **JS 引擎**：NAPI 包装 quickjs-ng（同版本、init.js 原样发布）；备选 ArkWeb 承载。必须新增执行看门狗与内存上限（现 Dart 版 timeout=0，死循环会卡死 UI）。
2. **SQLite**：NAPI 包装已随包的 libsqlite3.so（而非 relationalStore），因为 .venera 导入需打开**外部 SQLite 文件**，且要与旧版逐字节兼容；relationalStore 仅作回退。
3. **HTML/CSS**：选择器下沉到 JS 侧 DOM 库，ArkTS 只保留 http 等非 DOM method；修正 node_toElement 命名、文档上限 8、node_type 取值。
4. **网络**：@ohos.net.http（requestInStream）+ @ohos.net.connection（getDefaultHttpProxy）+ ArkWeb（CF / WebviewFetch），15s 超时、ignoreBadCertificate、Host 保留、Range 续传。
5. **编解码**：GBK 用系统 util.TextDecoder/TextEncoder（免内置码表）；AES(ECB/CBC/CFB/OFB，任意 blockSize)/RSA(PKCS#1 v1.5 解密)/MD5/SHA/HMAC 用 @kit.CryptoArchitectureKit，CFB/OFB 分块手工实现对齐 pointycastle。
6. **图像/压缩**：image.ImageSource.getImageInfo + createPixelMap({desiredSize}) + ImagePacker；zip 用 @ohos.zlib；内存上限按 hidebug.getSystemMemInfo() 分档（100/200/300/500MB）。
7. **已知缺口保持不扩**：7z/rar 本地漫画（原实现是 Process.run("7z")，鸿蒙本就不支持）、PDF/EPUB 导出（HDS 侧现仅 cbz 可用）。

## 5. 阅读器规格（截图 = 验收基准）

- 页码信息：Positioned(bottom:13, left:25)，fontSize 14 + 1.4px 描边，文本 epName : page/maxPage（无章节时仅 page/maxPage），epName 超 8 字截断加 ...；受 showPageNumberInReader 控制；SR 开启时追加图标 + " SR"。
- 时钟/电池：Positioned(bottom:13, right:25)；HH:mm（1s 刷新）；电池 1s 轮询 batteryInfo.batterySOC/chargingStatus，阈值 充电/≥96/84/72/60/48/36/24/12/<12(红)，文案 "level%"，等级≤0 或 unknown 时整体隐藏；受 enableClockAndBatteryInfoInReader 控制。
- 顶栏 56vp（返回、标题+章名、章节评论、设置）；底栏 105vp（首/上一页、Slider、下一页/末页、"E{ch} : P{page}" 药丸、收藏/全屏/旋转/自动翻页/章节/保存/分享）；滑入滑出 180ms。
- 浮动词章切换按钮 right:16, bottom 0→-58 / 36，primaryContainer 圆角 16，方向随 isReversed。
- 六种模式：画廊 LR/RL/TB（Swiper，支持 N 图/页 + 章末评论虚拟页）；连续 TTB/LR/RL（List + LazyForEach，**LR/RL 目前是假竖排，需补齐横向**），哨兵项 + 160vp 过滚翻章 + 进度药丸。
- 手势：点击分区翻页/切工具栏（30% 分区）；双击 1.75×（或快速收藏）；长按缩放（press/center）；双指缩放 1.0–2.5；**缩放后平移（现为死代码，必须实现）**；Swipe 侧滑收藏（阈值 150）。
- 章节面：章节选择抽屉（平铺/分组、正倒序、已下载标记）、阅读设置抽屉（24 键 + 漫画/设备级开关）、章末评论页/抽屉、选图浮层、Toast/NetworkError 重试。
- 数据：三级设置解析；历史写入 ep/page/group/readEpisode/maxPage/time（1s 去抖 + 退出落盘）并重启恢复；图片键 imageKey@sourceKey@cid@eid（SR 键 sr_cv@...）；预取 preloadImageCount(默认 4) + 磁盘尺寸探测；音量键（鸿蒙 keyCode 2012/2013/2054/2055）；showSystemStatusBar 沉浸切换；屏幕常亮。
- 待修缺陷：启动参数 0/1-based 混淆、ComicDetailPage 传 chapterId 当索引、history 返回被忽略、模式按钮不持久化、设置面板缺 10+ 项、假进度条、无重试、硬编码英文与颜色、safeAreaTop 未使用。

## 6. 兼容性要求（不可变）

- 文件：appdata.json（{settings, searchHistory}）、syncdata.json、implicitData.json（ua、webdavAutoSync、lastCheckUpdate、favoriteFolder）、local_path、downloading_tasks.json、logs.txt、comic_source/<key>.js 与 <key>.data、cache/<00..99>/<md5>、local/<comic>/cover.<ext> + <chapter>/<index><ext>。
- 数据库：cookie(name,value,domain,path,expires,secure,httpOnly, PK(name,domain,path))；cache(key PK,dir,name,expires,type)；local_favorite(folder_order、folder_sync、每文件夹一表 + 4 个 ALTER 迁移)；history(history + image_favorites + chapter_group 迁移)；local(comics, PK(id,comic_type))。
- JSON：Comic / ComicDetails / ComicChapters（平铺或分组，分组结构不可扁平化）/ History / Favorite / LocalComic / ImageFavorite / Comment 字段名保持不变。
- 设置：60+ 键；三级覆盖键 "<comicId>@<sourceKey>"；同步排除列表 proxy、authorizationRequired、customImageProcessing、webdav、disableSyncFields、deviceId。
- .venera ZIP：history.db、local_favorite.db、appdata.json（或 syncdata.json）、cookie.db、comic_source/*；文件名 <days>-<dataVersion>.venera，保留 10 份。

## 7. 测试与风险

**测试**：hypium 单测（设置三级解析、CacheDAO 键/TTL/淘汰、Cookie 域路径匹配、DDL 与迁移、Convert、页码换算、Parser 校验）；黄金对比（同一批源同一批参数，Flutter 版 vs 原生逐 JSON diff）；集成（真实源、.venera 双向、旧数据升级、CF 全流程）；阅读器（边界表驱动 + 截图比对 + 六模式冒烟 + 手势）；每阶段 devecocli build / check lint。

**风险与缓解**：NAPI/CMake 链路（1 天 PoC 先行，失败切 ArkWeb 方案）；QuickJS 语义/封送漂移（同版本 + init.js 原样 + 黄金回归）；无执行超时卡死 UI（看门狗 + 内存/栈上限）；HTML 选择器兼容（JS DOM + 10 源真实页面断言）；CF/风控 TLS 差异（复用 ArkWeb 全流程 + 失败率记录）；后台下载缺失（@ohos.request / backgroundTaskManager）；无真机时验证面窄（模拟器为主 + 至少 1 台真机验收）；数据格式破坏（DDL 逐字保留 + 双向互操作 + 升级前自动导出 .venera）；API 26 仍为 Beta2（锁定 SDK 26.0.0.32，HDS 用法集中在 design/HdsTheme.ets）。

## 8. 假设

1. 单人开发；基线为合并后的 HDS_UI，不回退重写 UI。
2. 不新增上游功能，只做移植 + 修复既有缺陷；WS6 删除 Flutter 回退开关。
3. 除不再写 useNativeUi 外，不改动任何磁盘格式。
4. 7z/rar 本地漫画与 PDF/EPUB 导出维持现状。
5. 验收设备：Pura 90 Pro / PuddingTest 模拟器 + 1 台 API 26 真机。
6. JS worker 池维持 4 实例；看门狗超时默认值在 WS3 门禁中定标（建议 30s，可配置）。

## 9. Git 收敛记录（本次已完成，本地）

| 步骤 | 内容 | 结果 |
|---|---|---|
| A1.1 | chore(gitignore)：忽略本机调试产物与 inappwebview 参考仓库 | 提交 e20cc16 |
| A1.2 | wip(webview)：inappwebview 重构 Cloudflare 免验证与 WebView fetch 兜底（17 文件，+1515/−336；含已知缺陷 type 'Null' is not a subtype of type 'String'） | 提交 68a5c83 |
| A1.3 | git push origin main | **阻塞：本机无法访问 GitHub（TCP 443 连接被重置，无本地代理，无 git http.proxy）** |
| A2 | git merge --no-ff main（合并进 HDS_UI）：15 个内容冲突 + 2 个 modify/delete + 1 个 rename/delete，全部解决 | 合并提交 7b71e41 |
| A3.1 | 删除误提交的构建日志 build_log.txt / build_out.txt / build_deveco.txt 并加入 .gitignore | 已提交（见下一次提交） |
| A3.4 | README 更新分支策略与 API 26 目标 | 同上 |

**冲突解决原则（已执行）**：原生 UI/桥接以 HDS_UI 为准；Dart 数据与网络层以 main 为准；版本号统一为 1.6.5 / 1060500；依赖集合保留 main（含 flutter_inappwebview）以保证 Dart 侧可编译，去插件化推迟到 WS6；并额外完成两项集成：PlatformBridge 补齐 getWebCookies（WebCookieManager.saveCookieAsync → fetchCookieSync，含 HttpOnly cf_clearance），WebViewBridge/WebViewPage 的 onCloudflareResolved 载荷对齐 Dart 期望（{url, cookies: 字符串, userAgent} 并新增 getUserAgent()）。

**待办（网络恢复后）**：git push origin main；git push origin HDS_UI。
