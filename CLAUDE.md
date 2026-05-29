# CLAUDE.md

本文件用于指导 Claude Code 在本仓库中协作。新会话开始时优先读取本文件。

---

## 项目概要

**Inkite** —— 融合创意写作与社区分享的应用。20 天、5 人团队的课程 demo，目标是覆盖全部功能骨架，**最终以演示视频形式交付**（非现场操作）。

**交付形态**：**Windows 桌面应用为主**（同一份 Flutter 代码可编译为 Android APK 备用）。T1.3 已在 Windows 上跑通 `flutter run -d windows` 与匿名登录 + Firestore 探针。pivot 决策记录见 `docs/dependencies.md` 末尾「Windows 桌面实测环境与稳定跑法」附录。

核心功能：

- **官方挑战**：定期发布三词提示，用户写入故事提交
- **通道广场**：故事发布后进入社区动态，支持点赞、评论、排行榜
- **自由创作**：随机词生成器，无限灵感入口
- **展览厅**：完成官方挑战奖励 AI 生成折纸藏品；解锁魔法墨水与主题房间
- **角色查询**：Wikipedia + Reddit 多源聚合（模块 G 已完成，由 P4 嵌入）

**技术栈**：Flutter（客户端）+ Firebase（Auth / Firestore / Cloud Storage / Cloud Functions）+ Replicate Flux Schnell（AI 生成，备用）

**团队分工**：
- P1 — 技术负责人 / 后端（Firebase 基座、数据模型、Cloud Functions、联调）
- P2 — 写作核心（编辑器、官方挑战、自由词）
- P3 — 社区（广场、点赞评论、排行榜）
- P4 — 游戏化 + 角色查询嵌入（展览厅、折纸、模块 G 集成）
- P5 — 见 `docs/` 后续补充

**关键里程碑**（P1 视角）：
- D3 Firestore schema 冻结 + Hello-App 可跑（Windows 桌面端）
- D12 账号系统 + 数据访问层 + Functions 骨架可独立运行
- D16 AI 生成与排行榜端到端打通，功能冻结
- D19 安全规则收紧、种子数据就绪、构建产物冻结
- D20 演示视频录制 + 交付（Windows release 构建为主，可附 Android APK）

---

## 仓库目录

```
.
├── CLAUDE.md                       # 本文件
├── README.md                       # 对外项目简介
├── LICENSE
├── firebase.json                   # Firebase CLI 部署/Emulator 配置（T1.1）
├── .firebaserc                     # 项目别名（T1.1）
├── .gitignore
├── .editorconfig                   # 跨编辑器风格统一
├── docs/
│   ├── git-format.md               # 提交信息与分支命名规范（强制）
│   ├── dependencies.md             # 本地工具链安装指引（含 Windows 实测附录）
│   ├── section1-TODO.md            # P1 全程任务清单（T1.1 – T1.11）
│   ├── P1/
│   │   ├── stage0/                 # 阶段 0 子任务文档（T1.1.md, T1.2.md, T1.3.md）
│   │   └── stage1/                 # 后续阶段
│   ├── schema-design/
│   │   └── design.md               # Firestore 数据模型（D3 冻结后唯一事实来源）
│   └── tmp/                        # 立项阶段资料
│       ├── 分工-初步.md
│       └── Inkite_可行性与资金分析.md
└── app-storage/                    # Flutter 工程根目录（T1.3 初始化）
```

Flutter 工程内部目录（`app-storage/` 下）：

```
app-storage/
├── firebase.json                   # FlutterFire CLI 配置状态（与仓库根的 firebase.json 用途不同）
├── lib/
│   ├── main.dart                   # Firebase.initializeApp + MaterialApp.router
│   ├── firebase_options.dart       # FlutterFire CLI 生成（含 android + windows 平台）
│   ├── routing/
│   │   └── app_router.dart         # GoRouter + authStateChanges 守卫
│   └── features/
│       ├── auth/                   # P1
│       ├── shell/                  # 底部 Tab 主框架
│       ├── writing/                # P2
│       ├── square/                 # P3
│       ├── gallery/                # P4
│       ├── me/                     # 我的 Tab
│       └── character/              # 模块 G 嵌入
├── windows/                        # Windows 桌面平台（主交付）
│   ├── CMakeLists.txt
│   ├── flutter/
│   └── runner/                     # MSVC native runner
├── android/app/
│   └── google-services.json        # 入仓（Firebase Android 客户端公开配置，非密钥）
├── test/widget_test.dart
├── pubspec.yaml
└── analysis_options.yaml
```

两个 `firebase.json` 区分：

- `./firebase.json`（仓库根）：**Firebase CLI** 用，声明 `firestore.rules` / `storage.rules` / `firestore.indexes.json` / `functions/` 路径与 Emulator 端口
- `app-storage/firebase.json`：**FlutterFire CLI** 用，存储已配置的平台元数据（android / windows 的 appId 等），不要手工编辑

Firebase 后端配置文件（仓库根，T1.4 起补齐）：

```
firestore.rules
storage.rules
firestore.indexes.json
functions/                          # Cloud Functions 源码
```

---

## 协作约定

### 1. 提交规范

**严格遵循 `docs/git-format.md`**。要点：

- 格式：`<type>[(<scope>)]: <subject>`
- `type` 限定：`feat` / `fix` / `docs` / `style` / `refactor` / `test` / `revert` / `build`
- `subject` 不超过 72 字符，不加句号
- 分支命名：`<type>/<简短描述>`，如 `feat/firebase-schema`

**Claude 不得自行执行 `git commit`**。修改完成后，在聊天中给出推荐的 commit message（含 type / scope / subject / body），由用户审核后再执行。

### 2. 数据模型权威

- `docs/schema-design/design.md` 是 Firestore schema 的**唯一事实来源**。
- D3 冻结后，任何字段变更须经 P1 同意，并在同一份 PR 中更新本文档。
- 字段命名 **camelCase**，禁止 snake_case。
- 冗余计数（`likeCount` / `commentCount` / `hotScore` 等）由 Cloud Functions 维护，前端禁写，由安全规则强制。

### 3. 安全与机密

- 不在 Firestore 自行存储密码或鉴权凭证，全部交给 Firebase Auth。
- **真正的机密绝不入仓**：Firebase service account / Admin SDK 凭证（`service-account*.json` / `serviceAccountKey*.json`）、Replicate API key、CF 环境变量（`functions/.env`）。
- **`google-services.json` 入仓**：它是 Android 客户端公开配置（按 Firebase 官方说法，API key 不是 secret，访问控制由 Security Rules 强制）。私有仓 + 单 Firebase 项目 (`inkite-demo`) 下入仓便于成员零摩擦克隆即跑。若日后转公开仓或多环境项目，再切回 gitignore。
- 任何"看起来像密钥"的字符串在提交前需再次确认。

### 4. 任务执行原则

- 涉及破坏性 git 操作（`reset --hard` / `push --force` / 删除分支等）须先与用户确认。
- 范围之内：只做要求的事，不顺手做"周边重构"。
- 修改 schema 前必先读 `docs/schema-design/design.md`；修改任务执行细节前必先读 `docs/section1-TODO.md`。

### 5. 当前阶段定位

当前正在执行 **阶段 1（D4–D12）并行开发期**。阶段 0 已收尾（T1.1 / T1.2 / T1.3 / T1.4 全部交付，最后 commit `7270f43`）。阶段 1 进度：T1.5 账号系统已交付 + Windows 端验证通过（commit `26fd86b`）；T1.6 数据访问层 Repository + 模型已交付。T1.4 的 `firestore.rules` / `storage.rules` 已实际部署到 `inkite-demo` 线上。Cloud Functions 尚未存在（T1.7 / T1.8 待做）。

每个子任务（T1.1 / T1.2 / ...）在 `docs/P1/stageN/T1.x.md` 留一份开发记录，覆盖：已交付物、需人工执行的 Console/CLI 动作、验收清单。子任务完成后**提交前必须等待用户审核**，绝不自行 commit（用户显式授权除外）。

### 6. Firebase 套餐与扣款触发点

`inkite-demo` 是 2026 年新建项目。**Cloud Storage for Firebase 与 Cloud Functions 均要求 Blaze（按量付费）套餐才能启用**（Auth + Firestore 仍可在 Spark 上跑）。已升 Blaze，月预算 ¥50 + 三档告警已设。

- 本地开发阶段一律走 Firebase Emulator Suite，避免产生云端费用。
- 扣款发生在**操作时即时计费、月底结算**，免费额度内不掏钱。各服务触发点：

| 服务 | 何时记一笔 | demo 体量下扣款？ |
|------|-----------|-------------------|
| Auth（匿名 / 邮箱密码） | 永久免费 | 否 |
| Firestore reads | 每"返回的文档" +1（本地缓存命中不算；监听只在初次加载与变化时算） | 远在 50K/天免费内 |
| Firestore writes / deletes | 每次 `set` / `update` / `add` / `delete` +1 | 远在 20K/天免费内 |
| Firestore 存储 / 出网 | 月度按持有量 + 流量计 | 远在 1 GB / 10 GB-月内 |
| Storage 上传（CF 写折纸图，T1.8） | Class A 操作 +1 | 远在 20K/天内 |
| Storage 下载（`Image.network`） | Class B 操作 +1 + 出网流量 | 远在 50K/天内 |
| Functions 调用 / 执行时长 | 每次 invocation + 计耗时 | 远在 2M/月 + 400K GB-秒内 |
| **Cloud Build**（每次 `firebase deploy --only functions`） | 每次构建按分钟计 | 120 min/天免费内 |
| **Artifact Registry**（Functions 容器镜像） | 部署后镜像**长期挂着**按 GB·月 | ≥ 0.5 GB 时月几分钱 |
| Replicate Flux Schnell（T1.8 实拍） | 每张 ≈ $0.003 | 演示当天 1 次 |

- 真正会跑出钱的两项：**Functions 部署后的镜像存储** + **演示当天的 Replicate 实拍**，总额远不到 ¥50 预算。
- 想 100% 零成本：T1.7 / T1.8 期间一律走 emulator，**不 deploy**，仅在 T1.11 演示前 deploy 一次正式版。

### 7. 客户端交付与跨平台

- **主交付平台**：Windows 桌面（`flutter run -d windows` / `flutter build windows`），由 P1 在 Windows + VS 2026 上跑通。**演示视频在 Windows 上录制**。
- **副平台**：Android（同代码可跑，留作 D17–D19 加分项）。`flutterfire configure` 已同时配好 android + windows 两套 `firebase_options.dart`。
- **不支持**：iOS / macOS / Linux / Web（demo 范围内不投入）。`firebase_auth` 当前选用方法（**匿名 + 邮箱/密码**）在 Windows 上经 REST 通道工作正常；OAuth 第三方登录不在计划内。
- **客户端不直接调 `firebase_storage`**：折纸图片由 Cloud Function 生成并写 Storage，客户端只通过 Firestore 拿到 `imageUrl` 用 `Image.network` 显示。避开 Windows 上 `firebase_storage` 支持有限的问题。
- **Windows 构建踩坑全集**：见 `docs/dependencies.md` 末尾「Windows 桌面实测环境与稳定跑法」附录（VS 2026 + Flutter 3.44 + Firebase C++ SDK 兼容性、Defender 拖慢、CMake 版本拒绝、INSTALL 权限、MSVC 运行库匹配 5 个治本点）。后续任何"Windows 跑不起来"问题先按附录排查。

---

## 关键参考索引

| 主题 | 文件 |
|------|------|
| 提交规范 | `docs/git-format.md` |
| P1 任务清单 | `docs/section1-TODO.md` |
| 数据模型 | `docs/schema-design/design.md` |
| 团队分工 | `docs/tmp/分工-初步.md` |
| 可行性与预算 | `docs/tmp/Inkite_可行性与资金分析.md` |
| 项目简介 | `README.md` |
