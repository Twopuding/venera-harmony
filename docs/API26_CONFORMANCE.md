# API 26 合规检查报告（当前工程 vs DevEco 26 / SDK 26.0.0.32 Beta2）

> 基线：分支 `HDS_UI` @ `e67236f`；工具链 DevEco Studio `26.0.0.621`、SDK `26.0.0.32 Beta2`。
> 判定依据：`sdk/default/openharmony/ets/{api,component,kits}/*.d.ts` 中的 `@deprecated since` 与 `@useinstead`，以及 DevEco 26 工程模板（`plugins/openharmony/lib/templates/project/New Project`）。
> 配套：[HDS_UI_GAPS.md](HDS_UI_GAPS.md)、[NATIVE_MIGRATION_PLAN.md](NATIVE_MIGRATION_PLAN.md)。

## B.1 已废弃 API（必须替换）

| 项 | 站点数 | 废弃版本 | 替代（SDK `@useinstead`） | 批次 |
|---|---|---|---|---|
| `getContext()` | 33（含 `RouterUtil.ets:260,279` 无参调用） | 18 | `UIContext.getHostContext()` | P1 |
| `@ohos.router`（`pushUrl`/`back`/`getParams`/`replaceUrl`…，经 `@kit.ArkUI` 导出） | 20 | 18 | `UIContext.getRouter()` | P1 |
| `promptAction.showToast`（全局函数） | 44（15 个文件） | 18 | `UIContext.getPromptAction().showToast()` | P1 |
| `ActionSheet.show()` | 3（`SettingsCategoryContent.ets:141,313,340`） | **26.0.0** | `UIContext.showActionSheet()` | P1 |
| `px2vp()` | 4（`ReaderAbility.ets:65,67`、`SafeAreaUtil.ets:32,35`） | 18 | `UIContext.px2vp()` | P1 |
| `LocalStorage.getShared()` | 1（`Index.ets:14`） | 18 | `UIContext.getSharedLocalStorage()` | P4（随 WS6 删除 `viewId`/`FlutterPage`） |
| `WindowProperties.type` | 未发现直接使用 | **26.0.0** | `WindowProperties.windowType` | 记录 + P1 末复检 |

`vp2px/fp2px/lpx2px/px2fp/px2lpx`、`animateTo`、`AlertDialog`、`Stepper`、`Panel`、`NavRouter`、`Navigator`、`GridContainer`、`WebController`、`WebCookie`、`EditMode`、`Sticky`、`IndicatorStyle`、`ItemState`、`NavigationType` 等同样已废弃，但**当前工程无调用点**（grep 计数为 0），保持即可。

### 已核实「合规、不要误改」清单
以下 API 与其所在模块存在废弃项，但工程使用的是**当前版本重载**：
- `Window.setWindowLayoutFullScreen(boolean): Promise<void>`、`Window.setWindowSystemBarProperties(props): Promise<void>`（被废弃的是 callback 重载，since 12）
- `WindowStage.loadContent(path, callback)`（被废弃的是 `Window.loadContent`，since 9）
- `Window.setWindowPrivacyMode`、`window.getLastWindow`、`display.getDefaultDisplaySync`、`deviceInfo.sdkApiVersion`、`batteryInfo.batterySOC/chargingStatus`
- `picker.DocumentViewPicker.select/save`、`DocumentSaveOptions.newFileNames`、`DocumentSelectOptions.fileSuffixFilters`（废弃的是 `PhotoViewPicker/VideoViewPicker` 与 `PhotoSaveOptions`）
- `WebCookieManager.saveCookieAsync`/`fetchCookieSync`、`WebviewController.runJavaScript`、`i18n.System.getSystemLocaleInstance`（since 20）、`image.ImagePacker.packToData`、`userAuth.getUserAuthInstance`
- `userAuth.getAvailableStatus(authType, authTrustLevel)`（`PlatformBridge.ets:368/374/638/644`）：废弃的是**同名类方法**（返回 `number`，since 9），工程调用的是命名空间函数 `function getAvailableStatus(...): void`（since 9，当前版本），无需改动

## B.2 工程/构建配置偏差（对照 DevEco 26 模板）

| 偏差 | 现状 | 对齐目标 | 批次 |
|---|---|---|---|
| 缺 `apps/app_ohos/ohos/code-linter.json5` | `devecocli check lint` 直接报错，项目无 lint 门禁 | 照模板补齐（已在 P0 落地） | P0 ✅ |
| `devecocli check compat` 不可用 | 本机 DevEco `26.0.0.621` < 要求 `26.0.0.810` | 升级 DevEco 后执行 `check compat --source-version <..> --target-version <..>`，报告并入本文 | 后续 |
| `build-profile.json5` 缺 `buildOption.strictMode` | 无 | `{"caseSensitiveCheck": true, "useNormalizedOHMUrl": true}`（API ≥ 12 模板值） | P2 |
| `modelVersion` = `5.0.0` | `oh-package.json5`、`hvigor/hvigor-config.json5` | 与 DevEco 26 新建工程一致 | P2（trial） |
| hypium 1.0.6、无 hamock | `@ohos/hypium: 1.0.6` | 模板版本；API ≥ 11 需补 `@ohos/hamock` | P2（受 ohpm 网络限制） |
| `AppScope/app.json5` | 无 `buildVersion`；icon = `$media:app_icon` | 加 `"buildVersion": "1"`；API ≥ 11 用 `$media:layered_image` | P2 |
| `module.json5` skills | `action.system.home` | `ohos.want.action.home` | P2 |
| `entry/oh-package.json5` | 尾部多余逗号；`dependencies` 为空（flutter_ohos 由 hvigor 插件注入，不可复现） | 清理；P4 一并去除 | P2 / P4 |
| Flutter 痕迹 | `hvigorfile.ts`/`hvigorconfig.ts` 注入 `flutter-hvigor-plugin`；`package.json` 指向 `D:\\Project\\flutter_ohos_sdk` 绝对路径；`local.properties` 含 `flutter.sdk`；`EntryAbility extends FlutterAbility`；HAP 含 libflutter.so / libapp.so / flutter_assets；`useNativeUi` 回退开关 | 全部移除 | P4（WS6） |
| `entry/build-profile.json5` 的 `nativeLib.filter.excludes **/x86_64/*.so` | release 包不含 x86_64 | 明确模拟器/真机验证通道并在此记录策略 | P2（决策记录） |

## B.3 待核实清单（不留悬空结论）

1. 升级 DevEco Studio ≥ 26.0.0.810 后跑 `devecocli check compat`（source = 当前 SDK，target = 26.0.0）与 `devecocli check lint` 全量报告，把**新增**条目并入本文。
2. HMS 侧 `@hms.hds.*`（`HdsTabs`/`hdsMaterial`/`SymbolGlyphModifier` 等）与 `@hms.ai.vision.*` 的 `@deprecated` 扫描（SDK 路径 `sdk/default/hms/ets/api`）。
3. `entry/libs/{arm64-v8a,x86_64}` 下 `libqjs.so`/`libsqlite3.so`/`libc++_shared.so` 的 16KB 页对齐与 ABI/符号检查。

## B.4 lint 基线

P0 补齐 `code-linter.json5` 后的首次 `devecocli check lint apps/app_ohos/ohos/entry/src/main/ets`（P0 执行）：

```
Summary: Issues: 47 | Errors: 0 | Warnings: 47 | Suggestions: 0 | Files checked: 22
Full report: %TEMP%/venera-lint.md
```

规则分布：`@performance/bad-deep-clone-check`（桥接层 `JSON.parse(JSON.stringify(...))` 深拷贝，多为 JsUiBridge/PlatformBridge/ReaderBridge/SettingsBridge/WebViewBridge）、`@performance/avoid-overusing-custom-component-check`（BlurCard 等小组件）等。
**门禁**：后续每个批次复跑，Errors 必须为 0，Warnings 不得高于 47（新增项需修复或说明）。

## B.5 P1 执行结果（废弃 API 机械化替换）

| 项 | 替换前 | 替换后 | 方式 |
|---|---|---|---|
| `getContext(...)` | 35 处 / 33 文件 | 0（仅注释提及） | 组件内与非组件统一改为 `UiContextHolder.hostContext()`（成员变量初始化阶段无法使用 `this.getUIContext()`，见下） |
| `router.pushUrl/back/getParams/...` | 17 处 | 0 | 组件内 `this.getUIContext().getRouter()`；`RouterUtil/AuthGatePresenter` 用 `UiContextHolder.router()`；`router.RouterMode` 枚举保留（未废弃） |
| `promptAction.showToast` | 44 处 / 15 文件 | 0 | `this.getUIContext().getPromptAction().showToast(...)`，并清理 `promptAction` 导入 |
| `ActionSheet.show` | 3 处 | 0 | `this.getUIContext().showActionSheet(...)` |
| `px2vp` | 4 处 | 0 | `win.getUIContext().px2vp(...)`（ReaderAbility / SafeAreaUtil 均有 `win` 在手） |

新增 `entry/src/main/ets/utils/UiContextHolder.ets`：单例保存前台 ability 的 `UIAbilityContext`（`setHostContext`）、主窗口 `UIContext`/`Router`/`PromptAction`（`init(windowStage)`）；四个 ability 在 `onCreate`/`onForeground`/`onWindowStageCreate` 注册。
> 注：自定义组件的**成员变量初始化**（`private context = getContext(this)`）执行时组件尚未挂载，`this.getUIContext()` 不可靠，故这类站点统一走 `UiContextHolder.hostContext()`；组件方法内则使用 `this.getUIContext()`。
