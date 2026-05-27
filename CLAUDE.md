# CLAUDE.md

本文件用于指导 Claude Code 在本仓库中协作。新会话开始时优先读取本文件。

---

## 项目概要

**Inkite** —— 融合创意写作与社区分享的 Android 移动应用。20 天、5 人团队的课程 demo，目标是覆盖全部功能骨架、可现场演示核心主路径。

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
- D3 Firestore schema 冻结 + Hello-App 可跑
- D12 账号系统 + 数据访问层 + Functions 骨架可独立运行
- D16 AI 生成与排行榜端到端打通，功能冻结
- D19 安全规则收紧、种子数据就绪、构建产物冻结
- D20 演示

---

## 仓库目录

```
.
├── CLAUDE.md                       # 本文件
├── README.md                       # 对外项目简介
├── LICENSE
├── docs/
│   ├── git-format.md               # 提交信息与分支命名规范（强制）
│   ├── section1-TODO.md            # P1 全程任务清单（T1.1 – T1.11）
│   ├── schema-design/
│   │   └── design.md               # Firestore 数据模型（D3 冻结后唯一事实来源）
│   └── tmp/                        # 立项阶段资料
│       ├── 分工-初步.md
│       └── Inkite_可行性与资金分析.md
└── (Flutter 工程将放置于仓库根，由 T1.3 初始化)
```

未来 Flutter 工程目录约定（T1.3 起逐步建立）：

```
lib/
├── main.dart
├── firebase_options.dart           # FlutterFire CLI 生成
└── features/
    ├── auth/                       # P1
    ├── writing/                    # P2
    ├── square/                     # P3
    ├── gallery/                    # P4
    └── character/                  # 模块 G 嵌入
android/app/
├── google-services.json            # 已 gitignore
└── google-services.json.example    # 仓库内仅保留模板
firebase.json
.firebaserc
firestore.rules
storage.rules
firestore.indexes.json
functions/                          # Cloud Functions
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
- `google-services.json`、Replicate API key、Firebase service account 等机密**绝不入仓**；仓库内仅保留 `.example` 模板。
- 任何"看起来像密钥"的字符串在提交前需再次确认。

### 4. 任务执行原则

- 涉及破坏性 git 操作（`reset --hard` / `push --force` / 删除分支等）须先与用户确认。
- 范围之内：只做要求的事，不顺手做"周边重构"。
- 修改 schema 前必先读 `docs/schema-design/design.md`；修改任务执行细节前必先读 `docs/section1-TODO.md`。

### 5. 当前阶段定位

当前正在执行 **阶段 0（D1–D3）奠基期**，重点是 T1.1 – T1.4。Flutter 工程尚未初始化，Cloud Functions 尚未存在；此阶段以**文档与配置**为主，不要凭空创建源码目录。

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
