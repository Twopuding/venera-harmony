# Venera HarmonyOS

[Venera](https://github.com/venera-app/venera) 漫画阅读器的 HarmonyOS 移植版，采用 Flutter + 原生 ArkTS 混合架构。

## 鸿蒙特性

| 类别 | 使用的鸿蒙能力 |
|------|----------------|
| 应用模型 | Stage 模型；4 个 `UIAbility`（Entry / Reader / WebView / Settings） |
| Flutter 集成 | `@ohos/flutter_ohos`：`FlutterAbility`、`MethodChannel`（Dart ↔ ArkTS） |
| UI | `@kit.ArkUI`：ArkUI 页面、沉浸式全屏、屏幕常亮 |
| Web | `@kit.ArkWeb`：内置 WebView |
| 安全 | `@kit.UserAuthenticationKit`：人脸/指纹认证 + PIN 回退；`ohos.permission.ACCESS_BIOMETRIC` |
| 文件 | `@kit.CoreFileKit`：文件选择器、本地文件读写 |
| 系统服务 | `@kit.BasicServicesKit`：电量信息、系统能力启动；`ohos.permission.INTERNET` |
| 构建 | Release：`ArkGuard` 源码混淆；`nativeLib` 过滤仅打包 arm64-v8a |

## 前置条件

| 项目 | 版本要求 |
|------|----------|
| Flutter ohos SDK | `3.22.4-ohos-1.1.4-beta` |
| Dart SDK | `>=3.4.4 <4.0.0` |
| DevEco Studio | `>=5.0` |
| HarmonyOS SDK | `>=5.0.0(12)`, target `6.1.0(23)` |
| Node.js | `>=16.x` |

Flutter ohos SDK 安装请参考 [flutter_ohos 官方文档](https://gitee.com/openharmony-sig/flutter_flutter)。

## 构建

### 1. 克隆与依赖

```bash
git clone https://github.com/Twopuding/venera-harmony.git
cd venera-harmony/apps/app_ohos
flutter pub get
```

### 2. 配置签名

1. 用 DevEco Studio 打开 `apps/app_ohos/ohos/`
2. **File → Project Structure → Signing Configs**
3. 勾选 **Automatically generate signature**
4. 确认 bundleName 为 `com.venera.ohos`
5. Apply → OK

### 3. 构建 Release HAP

```powershell
.\scripts\build-hap-release.ps1
```

输出：`apps/app_ohos/build/ohos/hap/entry-default-signed.hap`

### 4. 安装到设备

```bash
cd apps/app_ohos/ohos
devecocli run --skip-build --build-mode release
```

或使用 `hdc install` 安装上述 HAP 文件。

## 致谢

- [Venera](https://github.com/venera-app/venera) - 原始项目
- [Flutter ohos SDK](https://gitee.com/openharmony-sig/flutter_flutter) - Flutter HarmonyOS 支持
- [QuickJS](https://bellard.org/quickjs/) - JavaScript 引擎
