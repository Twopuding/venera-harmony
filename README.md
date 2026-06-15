# Venera HarmonyOS

[Venera](https://github.com/venera-app/venera) 漫画阅读器的 HarmonyOS 移植版，采用 Flutter + 原生 ArkTS 混合架构。

## 功能特性

- 多源漫画浏览与搜索
- 漫画阅读器（6 种阅读模式：画廊左右/右左/上下、连续上下/左右/右左）
- 内置 WebView（支持 Cloudflare 验证绕过）
- 生物认证 / 密码锁（人脸识别 / 指纹识别 + PIN 回退）
- 漫画下载与本地管理
- 收藏与阅读历史
- WebDAV 数据同步
- 动态配色 / 主题切换
- 多语言支持（中文简繁、英文）

## 生物认证

基于 HarmonyOS `@kit.UserAuthenticationKit` 实现：

- **权限**：`ohos.permission.ACCESS_BIOMETRIC`（system_grant）
- **认证流程**：
  1. 用户可在设置中选择"人脸识别"或"指纹识别"作为首选认证方式
  2. 认证时先尝试所选的生物认证方式（ATL2）
  3. 生物认证界面提供"使用密码"导航按钮，点击后回退到 PIN 码验证（ATL1）
- **API**：`getUserAuthInstance(AuthParam, WidgetParam)`（API 10+）
- **错误处理**：认证失败返回 401 时自动降级

## 架构

本项目采用混合架构，Flutter 负责业务逻辑/数据层/JS引擎，原生 ArkTS 负责高性能页面：

| 层级 | 技术 | 职责 |
|------|------|------|
| 业务逻辑 & UI | Flutter (Dart) | 漫画源管理、搜索、下载、设置、大部分 UI |
| 阅读器 | 原生 ArkTS | 6 种阅读模式、手势交互、沉浸式全屏 |
| WebView | 原生 ArkTS | Cloudflare 验证、Cookie 提取 |
| 设置/认证 | 原生 ArkTS | 生物认证、文件选择、屏幕常亮 |
| JS 引擎 | QuickJS (C/FFI) | 漫画源脚本执行 |
| 数据存储 | SQLite3 (C/FFI) | 本地数据库 |
| 通信 | MethodChannel | Dart ↔ ArkTS 双向调用 |

### 通信通道

| 通道名 | 方向 | 用途 |
|--------|------|------|
| `com.venera.reader` | Dart → ArkTS | 打开阅读器、加载章节图片 |
| `com.venera.webview` | Dart → ArkTS | 打开 WebView |
| `com.venera.settings` | Dart ↔ ArkTS | 认证、文件选择、屏幕控制 |
| `venera/method_channel` | Dart ↔ ArkTS | 通用平台服务（URL打开、分享、电量、代理等） |

## 前置条件

| 项目 | 版本要求 |
|------|----------|
| Flutter ohos SDK | `3.22.4-ohos-1.1.4-beta` |
| Dart SDK | `>=3.4.4 <4.0.0` |
| DevEco Studio | `>=5.0` |
| HarmonyOS SDK | `>=5.0.0(12)`, target `6.1.0(23)` |
| Node.js | `>=16.x` |

Flutter ohos SDK 安装请参考 [flutter_ohos 官方文档](https://gitee.com/openharmony-sig/flutter_flutter)。

## 编译步骤

### 1. 克隆仓库

```bash
git clone https://github.com/<your-username>/venera-harmony.git
cd venera-harmony
```

### 2. 安装 Dart 依赖

```bash
cd apps/app_ohos
flutter pub get
```

### 3. 配置签名

1. 用 DevEco Studio 打开 `apps/app_ohos/ohos/`
2. **File → Project Structure → Signing Configs**
3. 勾选 **Automatically generate signature**
4. 确认 bundleName 为 `com.twopuding.veneraoh`
5. Apply → OK

### 4. 构建 HAP

```bash
cd apps/app_ohos
flutter build hap --debug
```

输出：`build/ohos/hap/entry-default-signed.hap`

### 5. 安装到设备

```bash
hdc install build/ohos/hap/entry-default-signed.hap
```

## 项目结构

```
venera-harmony/
├── apps/
│   └── app_ohos/                  # Flutter 主项目
│       ├── pubspec.yaml           # 依赖声明（name: venera）
│       ├── lib/                   # Dart 业务代码
│       │   ├── main.dart          # 应用入口
│       │   ├── init.dart          # 初始化流程
│       │   ├── foundation/        # 核心基础（App, JS引擎, 数据管理）
│       │   ├── pages/             # Flutter 页面
│       │   ├── components/        # Flutter 组件
│       │   ├── network/           # 网络层（Dio适配、Cloudflare、Cookie）
│       │   ├── bridge/            # MethodChannel Dart 侧
│       │   ├── platform/          # 平台服务（路径、平台检测）
│       │   └── utils/             # 工具类
│       ├── assets/                # Flutter 资源
│       ├── stubs/                 # 8 个桩插件包
│       └── ohos/                  # HarmonyOS 工程
│           ├── AppScope/          # 应用级配置
│           │   ├── app.json5      # bundleName: com.twopuding.veneraoh
│           │   └── resources/     # 应用图标和名称
│           ├── entry/             # 主模块
│           │   ├── libs/          # 预编译 .so (arm64-v8a, x86_64)
│           │   │   ├── libqjs.so
│           │   │   ├── libsqlite3.so
│           │   │   └── libc++_shared.so
│           │   └── src/main/ets/  # ArkTS 源码
│           │       ├── entryability/   # EntryAbility (Flutter主界面)
│           │       ├── readerability/  # ReaderAbility (原生阅读器)
│           │       ├── webviewability/ # WebViewAbility
│           │       ├── settingsability/# SettingsAbility
│           │       ├── bridge/         # MethodChannel ArkTS 侧
│           │       ├── pages/          # ArkUI 页面 (Index, Reader, WebView)
│           │       ├── components/     # UI 组件
│           │       ├── viewmodel/      # ReaderViewModel
│           │       └── model/          # Comic 数据模型
│           ├── build-profile.json5 # 构建配置
│           └── hvigorfile.ts       # Hvigor 构建脚本
└── plugins/
    └── flutter_qjs/               # QuickJS FFI 插件 (ohos fork)
        ├── pubspec.yaml
        └── lib/                   # Dart FFI 绑定
```

## 与上游 Venera 的关系

本项目基于 [venera-app/venera](https://github.com/venera-app/venera) v1.6.3 进行 HarmonyOS 移植，主要变更：

- **混合架构**：新增 4 个原生 ArkTS Ability（Entry/Reader/WebView/Settings）
- **MethodChannel 桥接**：Dart ↔ ArkTS 双向通信
- **平台适配**：OhosHttpClientAdapter（替代 rhttp）、OhosPathProvider（替代 path_provider）
- **插件替换**：7zip → Process、lodepng → image、zip_flutter → archive
- **桩插件**：8 个不兼容插件创建 stub 包
- **QuickJS FFI**：为 HarmonyOS ARM64 编译的 QuickJS .so

## 致谢

- [Venera](https://github.com/venera-app/venera) - 原始项目
- [Flutter ohos SDK](https://gitee.com/openharmony-sig/flutter_flutter) - Flutter HarmonyOS 支持
- [QuickJS](https://bellard.org/quickjs/) - JavaScript 引擎
