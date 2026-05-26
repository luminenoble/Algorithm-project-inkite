# P1（技术负责人 / 后端）全程任务清单 — section1-TODO

> **角色**：P1 技术负责人 / 后端
> **职责**：整个项目的技术基座。Firebase 项目（Auth + Firestore schema + Cloud Storage）、Cloud Functions（AI 折纸生成管线、排行榜排序接口）、数据模型制定与对外交付、后期主导全模块联调。**最先开工、最后收尾**；D3 前必须交付可运行空壳，D12 前交付完整数据层供他人对接。
> **技术栈**：Flutter（客户端）+ Firebase（Auth / Firestore / Cloud Storage / Cloud Functions）+ Replicate Flux Schnell / 本机 SD（AI 生成）。
> **范围说明**：本文档覆盖 P1 在 5 个阶段（D1–D20）的**全部任务**。任务编号 `T1.x`；阶段对应排期表（阶段0奠基 / 阶段1并行 / 阶段2集成 / 阶段3打磨 / 阶段4演示）。

---

## 里程碑卡点（P1 必须守住）

- **D3**：Firebase schema 冻结 + Hello-App 跑通 + 数据模型文档交付（否则其他 4 人无法开工对接）。
- **D12**：账号系统 + 数据层 + Cloud Functions 接口骨架"单独能跑"，各模块可对接。
- **D16**：AI 生成管线、排行榜接口端到端打通，之后只许修不许加。
- **D19**：演示种子数据就绪、安全规则收紧、构建产物冻结。

---

## 阶段 0：奠基（D1–D3）

### T1.1 创建 Firebase 项目与多环境配置

**实现方法（步骤级）**

1. 在 Firebase Console 新建项目（如 `inkite-demo`），选择免费 Spark 档；记录项目 ID。
2. 启用四项服务：Authentication、Cloud Firestore（选 Native 模式）、Cloud Storage、Cloud Functions（注意 Functions 需 Blaze，但 demo 量级在免费额度内，绑定信用卡后设置预算告警 ¥50 即可）。
3. 选择就近区域（如 `asia-east1` 或 `asia-northeast1`），**所有服务统一同一区域**避免跨区延迟。
4. 在项目下注册 Android App，下载 `google-services.json`，约定其放置路径（`android/app/`）并加入 `.gitignore`，改为提供 `google-services.json.example` 模板。
5. 用 FlutterFire CLI（`flutterfire configure`）生成 `firebase_options.dart`，统一客户端初始化入口。
6. 建立 `firebase.json` + `.firebaserc`，纳入版本控制，作为部署配置基线。

**验收清单**

- [ ] Firebase Console 中 Auth / Firestore / Storage / Functions 四项均已启用
- [ ] 所有服务区域一致
- [ ] 预算告警已设置（防止 Functions 超额）
- [ ] `google-services.json` 已被 `.gitignore` 忽略，仓库内仅保留 `.example` 模板
- [ ] 团队任一成员 clone 仓库后，按 README 步骤可在本地初始化 Firebase 连接

---

### T1.2 设计并冻结 Firestore 数据模型（最高优先级）

**实现方法（步骤级）**

1. 通读 `分工-初步.md` 与可行性分析，列出各模块对数据的需求：
   - P2 写作核心 → 故事 / 草稿 / 官方挑战 / 随机词
   - P3 社区 → 广场动态 / 点赞 / 评论 / 排行榜
   - P4 游戏化 → 折纸藏品 / 解锁状态 / 主题房间
   - 角色查询（已完成模块 G）→ 角色缓存
2. 设计集合（Collection）与文档结构，建议如下（字段名最终冻结后写入团队 Wiki）：

   ```
   users/{uid}
     - displayName, photoURL, createdAt
     - stats: { storiesCount, likesReceived }
     - unlocks: { magicInk: bool, rooms: [roomId] }

   challenges/{challengeId}        # 官方三词挑战
     - words: [w1, w2, w3], title, startAt, endAt, isActive

   stories/{storyId}
     - authorId, authorName, title, body, mode (official|free|diary|essay|fanfic)
     - challengeId (nullable), words (nullable)
     - visibility (private|public)
     - createdAt, updatedAt
     - publishedToSquare: bool
     - likeCount, commentCount, hotScore   # 冗余计数，供排行榜排序

   stories/{storyId}/comments/{commentId}
     - authorId, authorName, text, createdAt

   stories/{storyId}/likes/{uid}    # 以 uid 为文档 ID 保证幂等
     - createdAt

   origami/{origamiId}              # AI 折纸藏品
     - ownerId, imageUrl, style, sourceChallengeId, createdAt

   charactersCache/{characterKey}   # 角色查询缓存（Wikipedia 主源 + Reddit）
     - name, wikiSummary, wikiUrl, redditPosts: [...], cachedAt
   ```

3. 明确**冗余计数策略**：`likeCount` / `commentCount` / `hotScore` 写在 story 文档上，由 Cloud Functions 触发器维护，前端排序无需聚合查询（见 T1.7）。
4. 输出一份 `docs/data-model.md`，作为唯一事实来源；任何字段变更必须经 P1 同意。
5. **D3 当天冻结**，召集全员评审 15 分钟，确认每个模块都能从此 schema 取到所需数据。

**验收清单**

- [ ] `docs/data-model.md` 已提交，含每个集合的字段、类型、是否必填、归属模块
- [ ] 5 个模块的数据需求均能被 schema 覆盖（逐一对照打钩）
- [ ] 点赞用 `uid` 作文档 ID 的幂等设计已确认
- [ ] 冗余计数字段（likeCount/commentCount/hotScore）已规划其维护方式
- [ ] D3 全员评审通过，schema 正式冻结

---

### T1.3 搭建可运行空壳 App（Hello-App）

**实现方法（步骤级）**

1. `flutter create` 初始化工程，约定包名（如 `com.inkite.app`）。
2. 集成 `firebase_core`，在 `main()` 中 `Firebase.initializeApp()`，确保真机/模拟器能成功连上 Firebase。
3. 搭好基础路由骨架（如用 `go_router`）：登录页 → 主框架（底部 Tab：写作 / 广场 / 展览厅 / 我的）占位空页。
4. 写一个最小验证：登录后向 Firestore 写一条测试文档并读回，打印成功 → 证明端到端链路通。
5. 约定项目目录结构（`lib/features/<module>/`），让 P2–P4 各自在自己目录开发，减少冲突。
6. 配置 lint 规则（`flutter_lints`）与 `.editorconfig`，统一代码风格。

**验收清单**

- [ ] `flutter run` 可在真机/模拟器启动，无红屏
- [ ] App 成功连接 Firebase（测试文档写入并读回成功）
- [ ] 四个主 Tab 占位页可导航切换
- [ ] 目录结构与 lint 规则已约定并提交
- [ ] 其他成员 pull 后能直接在自己模块目录开工

---

### T1.4 制定 Firestore 安全规则基线 + 范围锁定协助

**实现方法（步骤级）**

1. 编写 `firestore.rules` 初版：开发期以"已登录用户可读写自己数据"为基线，对公开 story 放开读、对他人 story 限制写。
2. 同步写 `storage.rules`：折纸图片只读公开、上传需鉴权。
3. 在 Firebase Emulator Suite 本地起规则模拟器，便于离线开发与测试（不消耗线上额度）。
4. 配合可行性分析第 6 节，协助团队在 D3 锁定砍量方案（明确哪些做切片、哪些 Mock），把 P1 这边的"延后项"列清（如实时排行榜延后，用简单排序）。

**验收清单**

- [ ] `firestore.rules` 与 `storage.rules` 初版已提交
- [ ] 本地 Emulator 可启动并加载规则
- [ ] 未登录用户无法写入、无法读取私密 story（已用 Emulator 验证）
- [ ] 范围基线文档明确 P1 的保留项与延后项

---

## 阶段 1：并行开发（D4–D12）

### T1.5 实现账号系统（Firebase Auth）并率先交付

**实现方法（步骤级）**

1. 启用登录方式：建议匿名登录 + 邮箱/密码（demo 够用，省去第三方 OAuth 配置成本）。
2. 封装 `AuthService`：`signIn` / `signUp` / `signOut` / `currentUser` / `authStateChanges` 流。
3. 用户首次登录时自动在 `users/{uid}` 写入初始文档（displayName 默认值、stats 归零、unlocks 默认 false）。
4. 在 App 顶层用 `authStateChanges` 控制路由：未登录跳登录页，已登录进主框架。
5. **优先交付**：把 `AuthService` + `users` 集合读写封装成稳定接口文档，D4–D5 内交付给 P2/P3/P4，让他们能拿到 `currentUser.uid` 对接各自数据。

**验收清单**

- [ ] 可完成注册 → 登出 → 重新登录全流程
- [ ] 新用户自动创建 `users/{uid}` 文档且字段完整
- [ ] `authStateChanges` 驱动的路由守卫正常（登录态变化页面随之切换）
- [ ] `AuthService` 接口文档已交付其他 3 人，且他们能取到 uid
- [ ] 与 T1.4 规则联动：用户只能改自己的 user 文档

---

### T1.6 交付数据访问层 / Repository 接口供各模块对接

**实现方法（步骤级）**

1. 为每个核心集合封装 Repository（`StoryRepository` / `ChallengeRepository` / `CommentRepository` 等），统一 CRUD 与查询入口，避免各模块直接散写 Firestore 调用。
2. 定义数据模型类（`Story` / `Comment` / `Challenge` …）含 `fromFirestore` / `toFirestore` 序列化，保证字段名与 schema 一致。
3. 提供常用查询方法签名（如 `StoryRepository.streamSquareFeed({sort})`、`watchComments(storyId)`），即使内部实现先简单，也先把**接口签名冻结**供前端并行开发。
4. 输出接口清单文档，标注每个方法的入参、返回类型、是否实时流。
5. D12 前确保这些 Repository "单独能跑"（用 Emulator 或测试账号验证读写）。

**验收清单**

- [ ] 各核心集合均有对应 Repository，前端不直接裸写 Firestore
- [ ] 数据模型类序列化字段与 `data-model.md` 完全一致
- [ ] 接口签名清单已交付，P2/P3/P4 据此并行开发不被阻塞
- [ ] 每个 Repository 的读写在 Emulator/测试账号下验证通过
- [ ] D12 数据层达到"单独能跑"状态

---

### T1.7 Cloud Functions：排行榜 / 计数维护

**实现方法（步骤级）**

1. 编写 Firestore 触发器 Function：监听 `stories/{id}/likes` 与 `/comments` 的写入/删除，原子更新父 story 的 `likeCount` / `commentCount`（用 `FieldValue.increment`）。
2. 计算 `hotScore`：用简单加权公式（如 `likeCount*2 + commentCount + 时间衰减`），写回 story 文档——**遵循可行性建议：排行榜用简单排序，不做实时推送**。
3. 前端排行榜直接对 `stories` 按 `hotScore` 降序 + `limit` 查询，无需聚合。
4. 必要时提供一个可手动触发的 Callable Function `recomputeHotScores`，便于演示前刷新榜单。
5. 部署：`firebase deploy --only functions`，确认日志无错误。

**验收清单**

- [ ] 点赞/评论后，story 的计数字段自动同步更新（Emulator 验证）
- [ ] `hotScore` 公式产出合理排序（高赞高评在前）
- [ ] 前端按 `hotScore` 查询排行榜返回正确顺序
- [ ] `recomputeHotScores` 可手动触发并刷新全部榜单
- [ ] Functions 部署成功，日志无报错

---

### T1.8 Cloud Functions：AI 折纸生成管线

**实现方法（步骤级）**

1. 编写 Callable Function `generateOrigami`：入参为触发来源（如 `challengeId`、风格 `style`）。
2. 接入生成源（二选一，按可行性第 5 节）：
   - 主：从**预生成素材池**（Storage 中预置的折纸图）按风格随机/匹配取一张 → 成本 ¥0，演示稳定。
   - 备：实时调用 **Replicate Flux Schnell**（$0.003/张），仅用于现场演示 1 次真实生成。
3. 生成/选取后：将图片写入 Cloud Storage，得到 `imageUrl`，并在 `origami/{id}` 写入藏品记录（ownerId、style、sourceChallengeId）。
4. 关键约束：**只有完成官方挑战才发放**——Function 内校验该 user 是否确有对应已发布的 official story，防刷。
5. 把 Replicate API key 放入 Functions 环境配置（`firebase functions:config:set` 或 Secrets），**不入仓库**。
6. 部署并用测试账号跑通：完成挑战 → 调用 → 拿到折纸 → 展览厅可见。

**验收清单**

- [ ] 预生成素材池已上传 Storage，按风格分类可取
- [ ] `generateOrigami` 完整链路跑通：调用 → 出图 → 写 Storage → 写 `origami` 记录
- [ ] 实时 Flux Schnell 路径可现场演示 1 次成功生成
- [ ] 校验逻辑生效：未完成官方挑战无法获得折纸
- [ ] API key 通过环境配置注入，未硬编码/未进仓库
- [ ] 与 P4 展览厅对接，新折纸能在画廊显示

---

## 阶段 2：集成（D13–D16）

### T1.9 主导跨模块联调，打通端到端主路径

**实现方法（步骤级）**

1. 串联核心主路径并逐段验证：登录（T1.5）→ 领取官方挑战（P2）→ 写作发布（P2）→ 折纸奖励（T1.8 + P4）→ 发布到广场（P3）→ 点赞评论排行榜（P3 + T1.7）。
2. 接入角色查询（已完成模块 G）：确认 Wikipedia 主源渲染正常、Reddit 缓存数据从 `charactersCache` 正确读出，配合 P4 嵌入 Flutter 页面（无需重写逻辑）。
3. 建立联调 issue 看板，每天定位并分派跨模块 bug；P1 拥有数据层/接口的最终裁决权。
4. 字段冲突或 schema 微调统一收口到 P1，更新 `data-model.md` 并通知相关人。
5. **D16 卡点**：端到端主流程必须跑通，之后冻结功能，只许修不许加。

**验收清单**

- [ ] 端到端主路径在测试账号上一气呵成跑通（登录→挑战→写作→折纸→广场→点赞评论→排行榜）
- [ ] 角色查询 Wikipedia 主源 + Reddit 缓存在页面正常渲染
- [ ] 跨模块 bug 看板建立并持续清理
- [ ] schema 变更全部经 P1 收口，文档同步更新
- [ ] D16 端到端主流程冻结

---

## 阶段 3：测试打磨（D17–D19）

### T1.10 收紧安全规则、准备演示种子数据、性能与索引

**实现方法（步骤级）**

1. 把开发期宽松的 `firestore.rules` / `storage.rules` 收紧到演示安全级别：私密 story 仅作者可读、点赞评论需登录、计数字段禁止前端直写（只允许 Functions 改）。
2. 创建/部署 Firestore 复合索引：排行榜（`hotScore` 降序 + 过滤）等查询所需的索引写入 `firestore.indexes.json` 并部署。
3. 编写演示种子数据脚本：预置若干官方挑战、示例故事、若干点赞评论、折纸藏品，使广场和排行榜在演示时"有内容"。
4. 真机测试数据层与 Functions 的稳定性，记录并修复 bug；确认 Replicate 调用在弱网下有超时/降级（失败则回退预生成池）。

**验收清单**

- [ ] 收紧后的安全规则用 Emulator 通过测试（越权读写被拒）
- [ ] 计数字段前端无法直写，仅 Functions 可改
- [ ] 复合索引已部署，排行榜查询无"需要索引"报错
- [ ] 种子数据脚本可一键灌入，广场/排行榜演示时有充足内容
- [ ] AI 生成在弱网/失败时能降级回预生成池，不阻塞演示

---

## 阶段 4：演示（D20）

### T1.11 演示保障与构建产物冻结

**实现方法（步骤级）**

1. 构建可侧载的 release APK（`flutter build apk --release`），demo 无需上架 Google Play，直接侧载。
2. 录制端到端主流程备份视频，防止现场网络/AI 调用故障。
3. 演示前用 `recomputeHotScores`（T1.7）刷新榜单，确认种子数据展示正常。
4. 现场负责后端相关环节的兜底（如实时 AI 生成那 1 次的演示由 P1 把控，失败即切预生成池）。
5. 留出 buffer，配合演讲彩排。

**验收清单**

- [ ] release APK 构建成功并可在演示设备侧载安装运行
- [ ] 端到端备份录屏已就绪
- [ ] 演示前榜单/种子数据刷新确认正常
- [ ] AI 实时生成演示有降级预案
- [ ] 构建产物与配置已冻结、打 tag/分支留存

---

## 任务与里程碑对照速查

| 任务 | 阶段 | 截止卡点 | 是否阻塞他人 |
|------|------|----------|--------------|
| T1.1 创建 Firebase 项目 | 阶段0 | D3 | 是 |
| T1.2 冻结 Firestore 数据模型 | 阶段0 | **D3** | **是（最强阻塞）** |
| T1.3 可运行空壳 App | 阶段0 | D3 | 是 |
| T1.4 安全规则基线 + 范围锁定 | 阶段0 | D3 | 部分 |
| T1.5 账号系统并率先交付 | 阶段1 | D4–D5 优先 | **是** |
| T1.6 数据访问层接口交付 | 阶段1 | D12 | **是** |
| T1.7 排行榜/计数 Functions | 阶段1 | D12 | 对 P3 |
| T1.8 AI 折纸生成管线 | 阶段1 | D12 | 对 P4 |
| T1.9 跨模块联调 | 阶段2 | **D16** | 主导 |
| T1.10 规则收紧+种子数据+索引 | 阶段3 | D19 | 否 |
| T1.11 演示保障+产物冻结 | 阶段4 | D20 | 否 |

---

## 提交规范提醒（遵循 docs/git-format.md）

- 分支：`feat/firebase-schema`、`feat/auth-service`、`feat/cf-leaderboard`、`feat/cf-origami` 等。
- 提交示例：
  - `feat(firebase): 初始化 Firebase 项目与多环境配置`
  - `docs(data-model): 冻结 Firestore 数据模型 schema`
  - `feat(auth): 封装 AuthService 并自动创建用户文档`
  - `feat(functions): 新增点赞评论计数触发器与 hotScore 排序`
  - `feat(functions): 接入 AI 折纸生成管线（预生成池 + Flux Schnell）`
