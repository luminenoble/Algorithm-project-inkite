# 开发依赖与本地环境

> 用途：新成员 clone 仓库后按此文档安装所需工具链，即可参与 P1/P2/P3/P4 开发。
> 测试平台：Linux / WSL2（Ubuntu 22.04+）。其他平台命令大同小异。
>
> **如果你要在 Windows 桌面（VS 2026）跑 `flutter run -d windows`，请直接看文末「附录：Windows 桌面实测环境与稳定跑法」**——这是 P1 实际跑通的环境，踩坑较多，已整理成 checklist。

---

## 必装

| 工具 | 用途 | 推荐版本 |
|------|------|----------|
| Git | 版本控制 | 已自带 |
| Node.js | Firebase CLI / Cloud Functions 运行时 | **>= 20.0.0** |
| Flutter SDK | 客户端开发与构建 | stable channel |
| Dart SDK | 随 Flutter 自带 | 随 Flutter |
| Firebase CLI | 部署、Emulator、初始化 | 最新稳定版（需 Node 20+） |
| FlutterFire CLI | 生成 `firebase_options.dart` | 最新版 |
| Android SDK / cmdline-tools | 真机/模拟器构建 | API 34+ |
| Java JDK | Android 构建 | 17 |

---

## 一、Node.js 20（通过 nvm）

```bash
# 安装 nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# 重启终端或 source 后启用
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 安装并使用 Node 20
nvm install 20
nvm use 20
node --version   # v20.x.x
```

> 若系统已经全局设置了 npm prefix（`npm config get prefix` 返回非默认路径），需要先 `npm config delete prefix` 再用 nvm，否则冲突。

---

## 二、Flutter SDK

```bash
# 克隆 stable 通道（约 1 GB）
git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter" --depth 1

# 加入 PATH（写入 ~/.zshrc 或 ~/.bashrc）
export PATH="$HOME/flutter/bin:$PATH"

# 首次运行会下载 Dart SDK
flutter --version
flutter doctor
```

`flutter doctor` 会报告各项依赖状态。Android Studio / Android SDK 在真机构建前需要解决；纯 Web/Linux 桌面测试可不装。

---

## 三、Firebase CLI

```bash
# 确认 Node 是 20+
node --version

# 全局安装（用户级，避免 sudo）
npm install -g firebase-tools

firebase --version

# 登录（WSL 无桌面则加 --no-localhost）
firebase login --no-localhost
```

---

## 四、FlutterFire CLI

```bash
dart pub global activate flutterfire_cli

# 把 dart pub global bin 加入 PATH
export PATH="$HOME/.pub-cache/bin:$PATH"

flutterfire --version
```

---

## 五、Android SDK（真机/模拟器构建用）

最轻量方案：装 `cmdline-tools` 而非完整 Android Studio。

```bash
# 用 sdkmanager 安装 platform-tools 与 build-tools
# 详见 https://developer.android.com/tools

# Java 17 必须先就位
java -version
```

WSL2 下推荐做法：在 Windows 主机上装 Android Studio，仅用 WSL 调代码，Windows 端跑模拟器。

---

## 六、本仓库的本地一次性初始化

```bash
# 1. 安装依赖（上面五步）
# 2. clone 仓库
git clone <repo-url>
cd Algorithm

# 3. T1.3 完成后，进入 Flutter 工程目录
cd app-storage
flutter pub get

# 4. 配置 FlutterFire
flutterfire configure   # 选择 inkite-demo 项目，平台仅勾 Android
# 这会生成 lib/firebase_options.dart 并把 google-services.json 下到 android/app/

# 5. 启动 Firebase 模拟器（T1.4 完成后）
cd ..
firebase emulators:start
```

---

## PATH 一次性写入 shell rc

把以下加到 `~/.zshrc`（或 `~/.bashrc`）末尾：

```bash
# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Flutter
export PATH="$HOME/flutter/bin:$PATH"

# Dart pub global
export PATH="$HOME/.pub-cache/bin:$PATH"
```

---

## 常见问题

- **`firebase login` 浏览器无法打开**：用 `firebase login --no-localhost`，命令行会给出可粘贴的 URL。
- **`flutter doctor` 报 Android licenses 未接受**：`flutter doctor --android-licenses`，全部 `y`。
- **WSL 下无法连接物理 Android 设备**：在 Windows 端 `adb start-server`，WSL 端 `adb connect <host-ip>:5555`，或直接在 Windows 端调试。
- **`npm install -g` 报权限错误**：用 nvm 管理 Node，避免使用 `/usr/local` 全局路径。

---

# 附录：Windows 桌面实测环境与稳定跑法

> 本附录记录 P1 在 **Windows + Visual Studio 2026** 上把 `flutter run -d windows` 跑通的真实环境与排坑过程。
> 桌面端只是开发期的快速验证平台（比起 Android 模拟器启动快、改完即看），项目最终交付目标仍是 Android。
> 根本矛盾：**Firebase Windows C++ SDK 是为旧工具链设计的，在 VS 2026 + 新版 CMake 下存在多处兼容性摩擦**——下面的坑 3/4/5 都源于此。

## A. 实测环境版本

| 组件 | 版本 / 说明 |
|------|-------------|
| 操作系统 | Windows（VS 2026 工具链） |
| Flutter | **3.44.0**，channel stable，revision `559ffa3f75`（2026-05-15） |
| Dart | **3.12.0**（随 Flutter 自带），DevTools 2.57.0 |
| Engine | hash `fcf463a224…`（revision `4c525dac5e`） |
| Visual Studio | **2026**（提供 MSVC 工具链 + CMake，桌面构建必需） |
| pub / storage 源 | **官方源**（`pub.dev` / `storage.googleapis.com`） |

> Flutter 初始版本 < 3.39 不支持 VS 2026，必须先升级：
>
> ```powershell
> flutter upgrade --force   # 升到 3.44.0
> flutter --version         # 确认 revision 559ffa3f75
> ```

## B. 国内网络（官方源 + 重试）

本环境直连官方源（`pub.dev` / `storage.googleapis.com`），不走第三方镜像。直连存在不稳定，应对方式：

- `flutter pub get` / `flutter upgrade` 若超时，**重试**即可，通常多跑几次能过；必要时挂代理。
- 如换用镜像，再在此处补 `PUB_HOSTED_URL` / `FLUTTER_STORAGE_BASE_URL` 配置；当前以官方源为准。

## C. 已知坑与稳定跑法（按重要性）

### 1. Windows Defender 拖慢 / 中断 SDK 解压（最关键，治本项）

`flutter run -d windows` 构建时会解压 ~300–500 MB 的 Firebase C++ SDK zip。Defender 实时扫描会把它拖到长时间无响应，甚至中断，日志报：

```
cmake -E tar: error: ZIP decompression failed (-5)
```

- 一旦 `flutter clean` 清掉 `build/`，下次构建必须重新解压，此坑就会**复发并可能致命**。
- **治本：把以下两个目录加入 Defender 排除项**（Windows 安全中心 → 病毒和威胁防护 → 排除项 → 添加文件夹）：
  - 工程的 `app-storage/build/`（解压目标目录）
  - Flutter pub_cache（`%LOCALAPPDATA%\Pub\Cache` 或 `$HOME/.pub-cache`，按实际安装位置）
- **操作纪律：尽量避免随手 `flutter clean`**。只要 `build/windows/x64/extracted/firebase_cpp_sdk_windows` 里的缓存还在，即便某次解压失败也能复用，构建仍可继续。

### 2. CMake 最低版本被拒（清 build 后会还原）

Firebase SDK 的 `build/windows/x64/extracted/firebase_cpp_sdk_windows/CMakeLists.txt` 顶部声明 `cmake_minimum_required(VERSION 3.1)`，被新版 CMake 拒绝。该文件是**解压产物、不在版本控制内**，清 build 重新解压后会还原。

- 修复方向：不要去改那个会被还原的文件，而是在**工程自己的** `app-storage/windows/CMakeLists.txt` 顶部注入 `CMAKE_POLICY_VERSION_MINIMUM`，使其对子项目生效。
- 注意区分两种程度：**报错（致命，构建失败）需修**；**Deprecation Warning（`Compatibility with CMake < 3.10 will be removed…`）只是警告，不影响构建与运行，可不处理**。

### 3. INSTALL 步骤权限 → exe 找不到 `flutter_windows.dll`

CMake 的 install prefix 默认指向 `C:\Program Files\inkite`，无管理员权限时 DLL 无法拷入 Debug 目录，exe 启动即报缺 `flutter_windows.dll`。

- 修复：**强制把 install prefix 覆盖为 Debug 输出目录**（已实测可解）。

### 4. MSVC 运行库 / 工具集匹配（链接期）

VS 2026 默认运行库与 Firebase 预编译 `.lib` 若不一致，会报 `LNK2038: mismatch detected for 'RuntimeLibrary'`。Firebase Windows SDK 区分 `MD/` 与 `MT/` 两套库目录。

- 排查：确认 CMake 选用的 Firebase 库目录（`MD/` vs `MT/`）与工程 `MSVC_RUNTIME_LIBRARY` 设置一致。

## D. Firebase 后端开关（非代码问题，易被误判为 bug）

T1.3 连通性验证用匿名登录，若报：

```
[firebase_auth/unknown-error] This operation is restricted to administrators only.
```

说明 **Firebase 项目里「匿名登录」未启用**，不是代码 bug。

- 修复：Firebase Console → `inkite-demo` → **Authentication → Sign-in method → 匿名 / Anonymous → 启用 → 保存**。无需改任何代码。

## E. Windows 桌面跑通的最短路径（checklist）

```powershell
# 0. 一次性：Defender 排除 build/ 与 pub_cache（见 C.1），此后避免 flutter clean
# 1. 确认 Flutter 版本（须 >= 3.44，支持 VS 2026）
flutter --version

# 2. 工程依赖
cd app-storage
flutter pub get          # 直连官方源，超时就重试

# 3. 跑 Windows 桌面（首次会解压 Firebase SDK，耐心等）
flutter run -d windows -v   # -v 便于定位卡在 configure / build / link / 运行期哪一步

# 4. 若 app 起来但匿名登录失败 → 去 Console 开匿名登录（见 D），与代码无关
```

> 验收标准：app 窗口正常弹出登录页，点「匿名登录并验证」返回成功（开启匿名登录后），即说明客户端 ↔ Firebase Auth 链路通畅。
