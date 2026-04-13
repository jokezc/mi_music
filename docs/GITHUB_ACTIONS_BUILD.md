# GitHub Actions 多平台自动构建指南

## 📋 概述

本项目配置了 GitHub Actions 工作流，可以自动构建以下平台的可执行文件：
- ✅ Android (APK)
- ✅ Windows (EXE)
- ✅ Linux (AppImage/Bundle)
- ✅ macOS (DMG)
- ✅ iOS (IPA，未签名)

## 🚀 快速开始

### 方式 1：通过 Git 标签自动发布（推荐）

```bash
# 1. 确保所有更改已提交
git add .
git commit -m "准备发布 v1.0.4"

# 2. 创建版本标签
git tag v1.0.4

# 3. 推送标签到 GitHub
git push origin v1.0.4
```

推送标签后，GitHub Actions 会自动：
1. 构建所有平台的安装包
2. 创建 GitHub Release
3. 上传所有构建产物到 Release

正式 Release 的正文统一读取 `docs/RELEASE_NOTES.md`，因此在发版前需要先手动更新这个文件。

### 方式 2：手动触发构建

1. 打开 GitHub 仓库页面
2. 点击 **Actions** 标签
3. 选择 **Multi-Platform Build** 工作流
4. 点击 **Run workflow** 按钮
5. 配置构建选项（默认全部勾选）：
   - ✅ **构建 Android** - 构建 Android APK
   - ✅ **构建 Windows** - 构建 Windows 版本
   - ✅ **构建 Linux** - 构建 Linux 版本
   - ✅ **构建 macOS** - 构建 macOS 版本
   - ✅ **构建 iOS** - 构建 iOS 版本
6. 选择要构建的分支，点击 **Run workflow**

**特性**：
- 默认构建所有平台
- 可以取消勾选不需要的平台以节省时间和配额
- 手动触发的构建会生成 Artifacts（构建产物），但不会自动创建 Release

**使用场景**：
- 🧪 **快速测试**：只勾选需要测试的平台
- 💾 **节省配额**：只构建实际需要的平台
- 🔧 **调试构建**：单独构建某个平台排查问题

## 📦 构建产物说明

### Android APK

生成 3 个不同架构的 APK：

| 文件名 | 架构 | 适用设备 | 大小 |
|--------|------|----------|------|
| `app-arm64-v8a-release.apk` | ARM64 | 大部分现代 Android 手机 | ~40MB |
| `app-armeabi-v7a-release.apk` | ARM32 | 较老的 Android 手机 | ~35MB |
| `app-x86_64-release.apk` | x86_64 | Android 模拟器 | ~45MB |

**推荐**：大部分用户安装 `arm64-v8a` 版本。

### Windows

- **文件**：`mi_music-windows-x64.zip`
- **内容**：包含可执行文件和所有依赖
- **安装**：解压后运行 `mi_music.exe`
- **大小**：~50MB

**特性**：
- 支持 Windows 系统媒体传输控制（SMTC）
- 键盘媒体键控制
- 系统托盘图标

### Linux

- **文件**：`mi_music-linux-amd64.deb`
- **内容**：包含可执行文件和所有依赖
- **安装**：
  ```bash
  # 安装 DEB 包
  sudo dpkg -i mi_music-linux-amd64.deb
  
  # 运行
  mi-music
  ```
- **系统要求**：
  ```bash
  # Ubuntu/Debian
  sudo apt-get install libgtk-3-0
  
  # Fedora
  sudo dnf install gtk3
  ```

### macOS

- **文件**：`mi_music-macos.dmg`
- **安装**：双击打开 DMG，拖拽到应用程序文件夹
- **注意**：首次运行可能需要在"系统偏好设置 > 安全性与隐私"中允许

### iOS

- **文件**：`mi_music-ios-unsigned.ipa`
- **状态**：未签名，无法直接安装
- **使用方法**：
  1. 需要 Apple 开发者账号
  2. 使用 Xcode 重新签名
  3. 或使用 AltStore/Sideloadly 等工具侧载

## 🔧 技术细节

### 平台特定处理

#### SMTC Windows 插件

`smtc_windows` 插件只支持 Windows 平台。为了在其他平台成功构建，我们采用了以下方案：

1. **代码层面**：创建平台抽象层
   - `lib/services/smtc_platform.dart` - 条件导出
   - `lib/services/smtc_platform_stub.dart` - 桩实现（Web）
   - `lib/services/smtc_platform_io.dart` - 真实实现（IO 平台）

2. **构建层面**：在非 Windows 平台构建前移除依赖
   ```yaml
   - name: Remove Windows-only dependencies
     run: sed -i '/smtc_windows:/d' pubspec.yaml
   ```

#### Flutter DisplayMode 插件

`flutter_displaymode` 只支持 Android，但因为其他平台可以编译通过，所以无需特殊处理。

### 构建流程

每个平台的构建流程：

```
1. Checkout 代码
2. 设置平台环境（Java/SDK/依赖）
3. 安装 Flutter
4. 移除平台不支持的依赖（如需要）
5. flutter pub get
6. flutter build <platform> --release
7. 打包构建产物
8. 上传 Artifacts
9. [仅标签触发] 创建 GitHub Release
```

### 构建时间

| 平台 | 预计时间 |
|------|----------|
| Android | 5-8 分钟 |
| Windows | 3-5 分钟 |
| Linux | 4-6 分钟 |
| macOS | 5-8 分钟 |
| iOS | 5-8 分钟 |
| **总计** | **20-30 分钟** |

所有平台并行构建，实际等待时间约为最慢平台的构建时间（~8 分钟）。

## 🐛 故障排查

### 构建失败

**Android 构建失败**
- 检查 Java 版本（需要 JDK 17）
- 检查 `android/build.gradle.kts` 配置
- 查看 Gradle 缓存是否损坏

**Windows 构建失败**
- 检查 `windows/CMakeLists.txt`
- 确保所有插件支持 Windows

**Linux 构建失败**
- 检查系统依赖是否安装
- 确认 GTK 3.0 可用
- 查看 CMake 错误日志

**macOS/iOS 构建失败**
- 检查 Xcode 版本
- 确认 CocoaPods 依赖
- 查看签名问题

### 依赖问题

如果某个插件在特定平台不支持：

1. 创建平台抽象层（参考 SMTC 的实现）
2. 在 GitHub Actions 中添加依赖移除步骤
3. 使用条件导入避免编译错误

### Release 创建失败

检查：
- 标签格式是否正确（需要 `v` 前缀，如 `v1.0.4`）
- `GITHUB_TOKEN` 权限是否足够
- 是否有同名 Release 已存在
- `create-release` job 是否已成功 checkout 仓库源码
- `docs/RELEASE_NOTES.md` 是否已经提交到当前发布对应的代码中

## 📝 自定义配置

### 修改 Flutter 版本

编辑 `.github/workflows/build.yml`：

```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    channel: 'stable'  # 使用最新稳定版
    cache: true        # 启用缓存加速构建
    # flutter-version: '3.27.0'  # 可选：指定具体版本
```

**说明**：
- 默认使用最新稳定版 Flutter，自动支持最新的 Dart SDK
- `cache: true` 可以缓存 Flutter SDK，加速后续构建
- 如需固定版本，取消注释 `flutter-version` 并指定版本号

### 添加新平台

在 `jobs` 下添加新的 job：

```yaml
build-new-platform:
  name: Build New Platform
  runs-on: ubuntu-latest
  steps:
    - name: Checkout code
      uses: actions/checkout@v4
    # ... 其他步骤
```

### 自定义构建参数

修改 `flutter build` 命令：

```yaml
- name: Build
  run: flutter build <platform> --release --verbose --tree-shake-icons
```

## 🔐 安全性

### Secrets 配置

如需签名证书，在 GitHub 仓库设置中添加：

**iOS/macOS 签名**：
- `IOS_CERTIFICATE_BASE64`
- `IOS_PROVISION_PROFILE_BASE64`
- `KEYCHAIN_PASSWORD`
- `MACOS_CERTIFICATE_BASE64`

**Android 签名**：
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

### 证书编码

```bash
# 将证书转换为 Base64
base64 -i certificate.p12 -o certificate_base64.txt

# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("certificate.p12"))
```

## 📚 相关资源

- [Flutter 构建文档](https://docs.flutter.dev/deployment)
- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [Flutter 桌面支持](https://docs.flutter.dev/desktop)
- [代码签名指南](https://docs.flutter.dev/deployment/ios#create-a-build-archive)

## ✅ 最佳实践

1. **版本管理**
   - 在 `pubspec.yaml` 中更新版本号
   - 使用语义化版本（如 `1.0.4`）
   - 标签与版本号保持一致

2. **测试**
   - 本地测试后再推送标签
   - 使用手动触发测试 CI 配置
   - 检查 Artifacts 确认构建产物

3. **发布**
   - 正式发版前先更新 `docs/RELEASE_NOTES.md`
   - 说明各平台的安装方法
   - 标注推荐下载的版本

4. **维护**
   - 定期更新 Flutter 版本
   - 检查依赖是否有安全更新
   - 关注 GitHub Actions 的使用配额

## 💡 提示

- **节省配额**：只在需要发布时推送标签，日常开发使用普通提交
- **并行构建**：所有平台同时构建，节省时间
- **增量构建**：GitHub Actions 会缓存依赖，加快构建速度
- **构建日志**：保留 90 天，便于排查问题
