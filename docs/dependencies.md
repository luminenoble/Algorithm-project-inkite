# 开发依赖与本地环境

> 用途：新成员 clone 仓库后按此文档安装所需工具链，即可参与 P1/P2/P3/P4 开发。
> 测试平台：Linux / WSL2（Ubuntu 22.04+）。其他平台命令大同小异。

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
