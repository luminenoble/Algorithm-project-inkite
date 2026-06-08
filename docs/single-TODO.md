# single-TODO — 单人接手后续开发清单

> **背景**：原计划 5 人 20 天，因变故转为**单人 + AI 辅助**完成。本文档替代原 `docs/section1-TODO.md`（P1 视角）成为后续开发的**唯一行动指引**，覆盖从 **T1.8 起所有剩余后端任务** + **P2 / P3 / P4 全部前端模块**。
> **目标不变**：保留全部预期功能骨架，最终以 **Windows 桌面端演示视频**交付。
> **剩余工期**：**15 天**（D6→D20 折算；下文统一记为 **R1…R15**，R = Remaining day）。单人可加大单日工作量，故按「全保真做完 + 建议日程」组织，不砍量。
> **范围变更（相对原计划）**：
> - ❌ **模块 G（角色查询 Wikipedia + Reddit）整体砍掉**。`character_screen.dart` 占位屏移除，`charactersCache` 集合与相关 Repository 保留在仓库但不接入 UI（留作后续可选）。详见 §0.3。
> - ✅ AI 折纸：**预生成素材池为主 + Replicate Flux Schnell 备用**（演示当天最多实拍 1 次）。
>
> 命名 / 提交 / 数据模型权威继续遵循 `CLAUDE.md`、`docs/git-format.md`、`docs/schema-design/design.md`。**Claude 不自行 `git commit`**，每个任务完成后给出建议 commit message 等人工审核。

---

## 0. 现状快照（动工前必读）

### 0.1 已交付（T1.1–T1.7，不要重做）

| 任务 | 交付物 | 现状 |
|------|--------|------|
| T1.1 | Firebase 项目 `inkite-demo`（asia-east1）、`firebase.json`、`.firebaserc`、`firebase_options.dart`（android + windows） | ✅ 线上可用，已升 Blaze + ¥50 预算告警 |
| T1.2 | `docs/schema-design/design.md` 数据模型 | ✅ 已冻结，唯一事实来源 |
| T1.3 | Flutter 工程 `app-storage/`、GoRouter 骨架、4 Tab 主框架、Windows 跑通 | ✅ `flutter run -d windows` 通 |
| T1.4 | `firestore.rules` / `storage.rules` / 复合索引声明 | ✅ 规则已部署线上；索引声明在 `firestore.indexes.json`（待 T1.10 部署） |
| T1.5 | `AuthService`（匿名 + 邮箱密码）、`login_screen.dart`、首登自动建 `users/{uid}` | ✅ Windows 验证通过 |
| T1.6 | 全部 Repository + 模型类（见 §0.2），接口已冻结 | ✅ Emulator/测试账号验证 |
| T1.7 | `functions/` 子工程：5 个触发器 + `recomputeHotScores` Callable | ✅ 代码完成（**未实地部署**，按零成本策略 demo 前才 deploy） |

> **关键含义**：**整个后端数据层已就绪**。P2/P3/P4 是纯前端拼装——绝大多数功能是「调已有 Repository + 搭 UI」，不需要碰 Firestore 裸 API，也不需要改 schema。

### 0.2 已就绪的接口面（你后续主要消费这些，签名已冻结，禁止改字段名）

**AuthService**（`lib/services/auth_service.dart`，单例 `AuthService.instance`）

```dart
User?   get currentUser;
String? get currentUid;
Stream<User?> get authStateChanges;
Future<UserCredential> signInAnonymously();
Future<UserCredential> signInWithEmail({required String email, required String password});
Future<UserCredential> signUp({required String email, required String password, String? displayName});
Future<void> signOut();
```

**Repository**（均为单例 `XxxRepository.instance`，`lib/data/repositories/`）

```dart
// StoryRepository
Future<String>      create(Story draft);                 // 返回新 storyId
Future<void>        update(String storyId, {String? title, String? body, StoryVisibility? visibility, bool? publishedToSquare});
Future<void>        delete(String storyId);
Future<Story?>      getById(String storyId);
Stream<Story?>      watchById(String storyId);
Stream<List<Story>> streamSquareFeed({SquareSort sort = SquareSort.hotScore, int limit = 50});
Stream<List<Story>> streamMyStories(String uid, {int limit = 50});
Stream<List<Story>> streamByChallenge(String challengeId, {int limit = 50});

// ChallengeRepository
Stream<Challenge?>       watchActive();                   // 当前活跃挑战
Future<Challenge?>       getById(String challengeId);
Future<List<Challenge>>  listRecent({int limit = 10});

// LikeRepository
Future<bool>    hasLiked(String storyId, String uid);
Stream<bool>    watchHasLiked(String storyId, String uid);
Future<void>    toggle(String storyId, String uid);      // 幂等：有则删、无则建

// CommentRepository
Future<String>               add(String storyId, StoryComment comment);
Future<void>                 delete(String storyId, String commentId);
Stream<List<StoryComment>>   watchComments(String storyId, {int limit = 100});

// OrigamiRepository
Future<Origami?>       getById(String origamiId);
Stream<Origami?>       watchById(String origamiId);
Stream<List<Origami>>  streamMine(String ownerId, {int limit = 50});

// UserRepository
Future<UserProfile?>   getProfile(String uid);
Stream<UserProfile?>   watchProfile(String uid);
Future<void>           updateDisplayName(String uid, String displayName);
```

**模型枚举 / 字段**（`lib/data/models/`，camelCase，禁止 snake_case）

```dart
enum StoryMode { official, free, diary, essay, fanfic }
enum StoryVisibility { private, public }
enum SquareSort { hotScore, newest }

Story    { id, authorId, authorName, title, body, mode, challengeId?, words?,
           visibility, publishedToSquare, likeCount(CF), commentCount(CF), hotScore(CF),
           createdAt, updatedAt }   // 客户端禁写 likeCount/commentCount/hotScore
Challenge{ id, title, words(len=3), startAt, endAt, isActive, createdAt }
StoryComment{ authorId, authorName, text, createdAt }
Origami  { id, ownerId, imageUrl, style, sourceChallengeId, source('pregen'|'flux'), createdAt }
UserProfile{ displayName, photoURL?, createdAt, stats{storiesCount,likesReceived,engagementScore}, unlocks{magicInk,rooms[]} }
```

> `Story.toCreateMap()` 故意不写三个计数字段 → 新 story 落库后由 `onStoryCreated` 触发器补 `hotScore=5` 才进排行榜（约 1–2 秒延迟，正常）。

### 0.3 模块 G 砍除的具体动作（R1 顺手做掉）

> **⟳ 更新（已复活）**：模块 G 已以**方案 A 形态复活为「开拓」栏**，详见
> `docs/角色查询-todo.md`。底栏新增第 5 个 Tab `/explore`，角色卡数据由离线脚本
> `functions/scripts/import_characters.mjs` 从 ISR-scraper 聚合灌入 `charactersCache`，
> app 端只读 Firestore（不连在线后端，与零成本一致）。下列「砍除」记录留作沿革；
> `charactersCache` / `CharactersCacheRepository` / `character_cache.dart` 不再是「保留未用」，
> 已接回 `features/explore/`。

1. 删 `lib/features/character/character_screen.dart`（或保留文件但从路由摘除）。
2. `main_shell.dart` 的 Tab 列表与 `app_router.dart` 当前**本就没有** `/character` 路由（角色查询原计划嵌在「我的」或独立入口），确认无残留引用即可。
3. `charactersCache` 集合 / `CharactersCacheRepository` / `character_cache.dart` **保留不删**（不影响编译，留作后续可选），但本 TODO 后续任务一律不依赖它。
4. 在 `CLAUDE.md` 项目概要的「角色查询」一行旁标注「已于单人重排中砍除」（提交时一并改）。

### 0.4 当前 4 Tab 与占位屏状态

| Tab 路由 | 屏文件 | 状态 | 归属 |
|----------|--------|------|------|
| `/writing` | `writing_screen.dart` | 15 行占位 | **P2，全做** |
| `/square` | `square_screen.dart` | 15 行占位 | **P3，全做** |
| `/gallery` | `gallery_screen.dart` | 15 行占位 | **P4，全做** |
| `/me` | `me_screen.dart` | 193 行，已展示 user 档案 + 登出 | 基本完成，仅按需微调 |

---

## 1. 总日程建议（R1–R15）

> 原则：**先把端到端主路径打通（登录→写作→广场→点赞评论→排行榜），再做游戏化与打磨**。主路径不依赖 AI，风险最低、最该早。折纸 / 解锁 / 演示放后。每日含一个「收工自检」（编译 + Windows 跑一遍当日新页）。

| 段 | 天 | 主线任务 | 卡点 |
|----|----|----------|------|
| A 主干 | R1 | 砍模块 G（§0.3）+ 写作模块脚手架：写作 Tab 落地页（官方挑战入口 / 自由创作入口）+ 路由 | — |
| A | R2 | **T2.1** 编辑器页（标题 + 正文 + 模式选择 + 保存草稿/发布） | 能 `StoryRepository.create` 写出一条 story |
| A | R3 | **T2.2** 官方挑战完整流（领取 `watchActive` → 三词带入编辑器 → 提交 official story） | 官方故事能落库且带 `challengeId`/`words` |
| A | R4 | **T2.3** 自由创作随机词生成器（本地词库，不入库）+ **T2.4**「我的故事」列表（`streamMyStories`） | 写作模块自闭环 |
| B 社区 | R5 | **T3.1** 广场动态列表（`streamSquareFeed`，hotScore/newest 切换）+ 故事卡片 | 列表渲染真实数据 |
| B | R6 | **T3.2** 故事详情页（正文 + 作者 + 计数）+ **T3.3** 点赞（`LikeRepository.toggle` + `watchHasLiked`） | 点赞数 1–2 秒内变化（CF 生效） |
| B | R7 | **T3.4** 评论（`watchComments` + `add` + `delete`）+ **T3.5** 排行榜视图（hotScore Top N） | 社区主路径闭环 |
| C 后端 | R8 | **T1.8a** 折纸生成 CF：预生成池路径（Storage 素材池 + `generateOrigami` Callable + 防刷校验） | Emulator 跑通发放 |
| C | R9 | **T1.8b** Replicate Flux Schnell 备用路径 + 密钥管理（Secrets）+ 弱网降级回预生成池 | 备用路径可切 |
| D 游戏化 | R10 | **T4.1** 展览厅画廊（`streamMine` 渲染折纸网格）+ **T4.2** 客户端触发折纸发放（接 `cloud_functions`，需改 `pubspec`） | 完成官方挑战→拿到折纸→画廊可见 |
| D | R11 | **T4.3** 主题房间（禅意花园 UI）+ **T4.4** 魔法墨水解锁视觉 + **T1.8c** user 派生字段 CF（`stats.*` / `unlocks.*` 维护，原 T1.7 留的尾） | 解锁语义闭环 |
| E 集成 | R12 | **T1.9** 跨模块联调：串端到端主路径逐段验证，修接缝 bug | 主路径一气呵成 |
| E | R13 | **T1.10a** 收紧 `firestore.rules` / `storage.rules` + 部署复合索引 | 越权被拒、查询无缺索引报错 |
| E | R14 | **T1.10b** 演示种子数据脚本（挑战 / 故事 / 点赞评论 / 折纸）+ 全量自测 | 广场 / 排行榜 / 画廊有内容 |
| F 演示 | R15 | **T1.11** 部署 Functions + 录制端到端演示视频（Windows release 构建）+ 演示前 `recomputeHotScores` 刷榜 + 兜底预案 | **交付** |
| ＋ 开拓 | R10.5（穿插） | **「开拓」栏（方案 A，复活模块 G）**：底栏 5 Tab + `/explore` 路由 + 角色卡数据层（searchByName/listPopular）+ 落地/详情页 + `import_characters.mjs` 离线导入（先 Emulator 验证）。详见 `docs/角色查询-todo.md`，工作记录 `docs/角色卡/` | 进开拓搜「hu」召回胡桃，详情外链可开；空库优雅降级 |

> 缓冲策略：若某段超时，**牺牲顺序为** T4.3/T4.4（主题房间 + 魔法墨水视觉）→ Replicate 备用路径（只留预生成池）→ 评论删除等次要交互。**绝不牺牲**：登录、写作发布、广场列表、点赞、排行榜、折纸预生成发放。

---

## 2. 后端剩余任务（T1.8 / T1.10 / T1.11）

> 这部分是你（原 P1 角色）的后端尾活。每个子任务在 `docs/P1/stage1/`（或 stage2/3）补一份开发记录，口径同 T1.5–T1.7。

### T1.8 — Cloud Functions：AI 折纸生成管线

依据原 `section1-TODO.md` T1.8 + 用户决策「预生成池为主 + Replicate 备用」。落到 `functions/src/generateOrigami.ts`，复用 `index.ts` 已有的 `initializeApp` 与 `setGlobalOptions`（asia-east1 / maxInstances 5）。**T1.7 文档已预告此任务在 `index.ts` 追加一行 `export { generateOrigami }`。**

#### T1.8a 预生成池路径（R8，P0）

**工作内容**

1. **准备素材池**：在 Cloud Storage 建 `origami-pool/{style}/*.png` 目录，每种风格（建议 `zen` / `steampunk` / `ink`，与 schema `style` 字段对齐）预置 3–5 张折纸图。图片可由你提前用任意工具批量生成或手工备好，命名随意。
2. **写 `generateOrigami` Callable**（v2 `onCall`）：
   - 入参：`{ challengeId: string, style?: string }`（`style` 缺省时按 challengeId 哈希或随机选一种）。
   - **防刷校验（关键约束）**：在 Function 内查 `stories`，确认 `request.auth.uid` 确有一条 `mode == 'official'` 且 `challengeId == 入参` 且 `publishedToSquare == true`（或 `visibility == public`）的 story；否则 `throw new HttpsError('failed-precondition', '需先完成该官方挑战')`。
   - **选图**：列出 `origami-pool/{style}/` 下文件，随机取一张，取其下载 URL（`getDownloadURL` 或公开读规则下拼 URL）。
   - **写记录**：在 `origami/{autoId}` 写 `{ ownerId: uid, imageUrl, style, sourceChallengeId: challengeId, source: 'pregen', createdAt: serverTimestamp() }`。
   - **幂等**（可选但推荐）：同一 `(uid, challengeId)` 已发放过则直接返回旧记录，避免重复刷折纸。
   - 出参：`{ origamiId, imageUrl, style, source }`。
   - Emulator 跳过 auth（同 `recomputeHotScores` 写法：`process.env.FUNCTIONS_EMULATOR === 'true'` 时不校验 `request.auth`，但仍需一个测试 uid 传入做防刷查询）。
3. `index.ts` 追加 `export { generateOrigami } from "./generateOrigami";`。

**AI 协作提示**：让 AI 参照 `functions/src/recompute.ts` 的 `onCall` + emulator 分支 + `HttpsError` 写法，保持同款错误处理与日志（`logger.info/warn`）。Storage 列文件用 `getStorage().bucket().getFiles({ prefix })`。

**验收**

- [ ] Storage `origami-pool/{style}/` 已上传，按风格分类可列出
- [ ] Emulator 下：先建一条该用户的 official 已发布 story → 调 `generateOrigami` → 返回 imageUrl 且 `origami/{id}` 落库 `source='pregen'`
- [ ] 防刷生效：无对应 official story 时调用被拒（`failed-precondition`）
- [ ] 幂等（若实现）：重复调用不产生第二条折纸
- [ ] `index.ts` 正确导出，`npm run build` 无 TS 报错

#### T1.8b Replicate Flux Schnell 备用 + 密钥 + 降级（R9，P1）

**工作内容**

1. **接 Replicate**：在 `generateOrigami` 增加分支——当入参带 `{ live: true }`（或单独 Callable `generateOrigamiLive`）时，调 Replicate Flux Schnell API 实时出图。
2. **密钥管理**：Replicate API key 用 **Firebase Functions Secrets**（`firebase functions:secrets:set REPLICATE_API_TOKEN`），在函数 `runWith({ secrets: ['REPLICATE_API_TOKEN'] })` 注入。**绝不入仓**（`CLAUDE.md` §3）；`functions/.env` 已在 `.gitignore`。
3. **出图后落地**：把 Replicate 返回的图片下载写入 Storage（与预生成同目录或单独 `origami-live/`），拿 URL → 写 `origami/{id}` 且 `source: 'flux'`。
4. **降级**：Replicate 调用包 try/catch + 超时（如 20s）。失败/超时 → **自动回退到 T1.8a 预生成池路径**，仍发一张图，记 warn 日志。保证演示弱网不阻塞。

**AI 协作提示**：Replicate 调用走 HTTP（`fetch` / `axios`），Flux Schnell 单张 ≈ $0.003，演示当天只实拍 1 次。降级回退直接复用 T1.8a 的选图函数，抽成共享 helper。

**验收**

- [ ] `REPLICATE_API_TOKEN` 通过 Secrets 注入，仓库内搜不到明文 key
- [ ] `live: true` 路径成功实时出 1 张图并落库 `source='flux'`
- [ ] 模拟 Replicate 失败（断网/改错 key）→ 自动回退预生成池，仍返回一张图，不抛错给前端

#### T1.8c user 派生字段触发器（R11，P2，原 T1.7 留的尾）

> T1.7 文档明确把 `users.stats.*` / `unlocks.*` 的 CF 维护留给后续。这里补上，否则「我的」页 storiesCount/likesReceived 永远 0、解锁永远 false。

**工作内容**

1. `onStoryCreated` 扩展或新增触发器：story 创建（`publishedToSquare` 时）→ 作者 `users/{authorId}.stats.storiesCount += 1`。
2. `onLikeCreated` / `onLikeDeleted` 扩展：被赞 story 的 `authorId` 的 `users/{authorId}.stats.likesReceived ±1`。
3. `engagementScore` 简单公式（如 `storiesCount*3 + likesReceived`）同步写回。
4. **解锁判定**：`engagementScore` 跨阈值时置 `unlocks.magicInk = true`；完成首个官方挑战时把禅意花园房间 ID push 进 `unlocks.rooms`（与 T4.3/T4.4 视觉对应）。阈值随便定（demo 数据下能触发即可）。
5. 全部走事务，`Math.max(0, …)` 防负，同 T1.7 风格。

**验收**

- [ ] 发布故事后「我的」页 `storiesCount` +1（Emulator）
- [ ] 他人点赞我的 story 后 `likesReceived` +1
- [ ] `engagementScore` 过阈值 → `magicInk` 变 true，画廊魔法墨水视觉解锁
- [ ] 完成官方挑战 → `rooms` 含禅意花园 ID

---

### T1.10 — 收紧规则 + 索引 + 种子数据（R13–R14）

依据原 `section1-TODO.md` T1.10。

#### T1.10a 规则收紧 + 索引部署（R13，P0）

**工作内容**

1. 把开发期宽松的 `firestore.rules` / `storage.rules` 收到演示级：私密 story 仅作者可读；点赞 / 评论需登录；`likeCount`/`commentCount`/`hotScore` 与 `users.stats.*`/`unlocks.*` 字段级 **CF-only**（前端任何 update 含这些字段即拒）；`origami` / `challenges` 前端只读。
2. `recomputeHotScores` 与（如有）`generateOrigamiLive` 的 admin 校验：把 `if (!request.auth)` 升级为 `request.auth?.token.admin === true`（演示用临时管理账号，或保留登录即可调但文档注明风险）。
3. 部署复合索引：`firestore.indexes.json` 已声明（`visibility+hotScore`、`authorId+createdAt`、`mode+challengeId+createdAt`）→ `firebase deploy --only firestore:indexes`。

**验收**

- [ ] Emulator：未登录 / 越权读写私密 story 被拒
- [ ] 前端尝试写 `likeCount` 等字段被规则拒
- [ ] 三条排行榜 / 我的 / 按挑战查询均无「需要索引」报错

#### T1.10b 演示种子数据脚本（R14，P0）

**工作内容**

1. 写一次性脚本（Node + Admin SDK，放 `functions/seed/` 或 `scripts/`，不入正式部署）：灌入 2–3 个官方挑战（含一个 `isActive=true`）、8–12 条示例故事（含 official / free 混合、不同作者）、若干点赞与评论、2–3 条折纸藏品。
2. 字段严格对齐 schema（camelCase、枚举值、`serverTimestamp`）。
3. 跑完后调一次 `recomputeHotScores` 让种子 story 进榜。

**验收**

- [ ] 一键脚本灌入后，广场 / 排行榜 / 画廊均「有内容」可演示
- [ ] 种子数据字段无 schema 违例（规则不拒、列表正常渲染）

---

### T1.11 — 演示保障与产物冻结（R15）

依据原 `section1-TODO.md` T1.11，**主交付改为 Windows release + 演示视频**（非 APK 现场操作）。

**工作内容**

1. `firebase deploy --only functions --project=inkite-demo`（首次正式部署；Cloud Build 1–2 min，Artifact Registry 镜像几分钱/月，在预算内）。部署后立即调一次 `recomputeHotScores` 验证生产链路。
2. `flutter build windows --release` 出可运行产物；按 `docs/dependencies.md` 末尾「Windows 桌面实测环境与稳定跑法」附录排查构建坑（VS 2026 / CMake / MSVC 运行库 / Defender）。
3. **录制端到端演示视频**（Windows 上）：登录 → 领官方挑战 → 写作发布 → 折纸奖励 → 画廊查看 → 发布到广场 → 点赞评论 → 排行榜。视频是最终交付物，务必覆盖主路径。
4. 折纸实拍那 1 次（Replicate）现场失败即切预生成池（T1.8b 降级已兜底）。
5. 打 tag / 留分支冻结产物。可选：Android `flutter build apk --release` 作加分备份。

**验收**

- [ ] Functions 部署成功，`firebase functions:log` 见 asia-east1 启动日志，6+ 函数在线
- [ ] Windows release 构建成功并能运行
- [ ] 端到端演示视频录制完成，主路径完整
- [ ] AI 实时生成有降级预案（已验证回退）
- [ ] 产物打 tag / 分支冻结

---

## 3. 前端模块任务（P2 写作 / P3 社区 / P4 游戏化）

> 共性约定：① 所有数据读写**只走 §0.2 的 Repository**，不裸调 Firestore。② 当前 uid 取 `AuthService.instance.currentUid`。③ 列表 / 详情用 `StreamBuilder` 吃 Repository 的 `Stream`，自动响应 CF 计数变化。④ 每个新页放在对应 `lib/features/<module>/` 下，可拆多个文件（页 / 卡片 / widget）。⑤ 路由在 `app_router.dart` 的 `ShellRoute` 内按需加子路由（如 `/writing/editor`、`/square/story/:id`）。

### P2 — 写作核心（R1–R4）

#### T2.1 编辑器页（R2，P0）

**工作内容**：写作 Tab 落地页给两个入口（官方挑战 / 自由创作）；编辑器页含标题输入、正文多行输入、模式选择（`StoryMode` 枚举：official/free/diary/essay/fanfic）、可见性（private/public）、「保存草稿」（`visibility=private`）与「发布」（`visibility=public` + `publishedToSquare=true`）。提交调 `StoryRepository.create(Story(...))`；`authorName` 取 `UserProfile.displayName`（先 `getProfile` 或用本地缓存）。

**验收**：能写出一条 story 落库；private/public 与 mode 正确；发布的能在广场出现（配合 T3.1）。

#### T2.2 官方挑战完整流（R3，P0）

**工作内容**：写作落地页用 `ChallengeRepository.watchActive()` 展示当前三词挑战；「领取」→ 跳编辑器并把 `challenge.words` 带入（正文预填或顶部提示），`mode=official`、`challengeId=challenge.id`、`words=challenge.words` 快照随 story 一起写。提交后可触发折纸发放（T4.2，R10 再接）。

**验收**：官方故事落库带正确 `challengeId` / `words`；`streamByChallenge` 能聚合到它。

#### T2.3 自由创作随机词（R4，P1）

**工作内容**：本地内置词库（一个 `const List<String>`），随机抽 1–3 词展示，「换一批」刷新；「用这些词写」→ 跳编辑器 `mode=free`。**随机词不入库**（schema §设计原则 5）。

**验收**：随机词可刷新；进编辑器写出 free story；确认未写入任何 `challenges` 集合。

#### T2.4「我的故事」列表（R4，P1）

**工作内容**：「我的」页或写作页内列出 `StoryRepository.streamMyStories(uid)`；点进可看 / 编辑（`update`）/ 删（`delete`）。草稿与已发布区分显示。

**验收**：列表实时；编辑改 title/body 生效；删除后消失。

---

### P3 — 社区（R5–R7）

#### T3.1 广场动态列表（R5，P0）

**工作内容**：广场 Tab 用 `StoryRepository.streamSquareFeed(sort)`，顶部切换 `SquareSort.hotScore` / `SquareSort.newest`；故事卡片显示标题、作者、正文摘要、`likeCount` / `commentCount`。点卡片进详情（T3.2）。

**验收**：列表渲染真实公开 story；两种排序可切；计数显示正确。

#### T3.2 故事详情页（R6，P0）

**工作内容**：路由 `/square/story/:id`，`StoryRepository.watchById(id)` 实时展示正文 + 作者 + 计数；底部接点赞（T3.3）与评论区（T3.4）。

**验收**：详情实时；CF 改计数后页面自动更新。

#### T3.3 点赞（R6，P0）

**工作内容**：详情页 / 卡片点赞按钮：`LikeRepository.watchHasLiked(storyId, uid)` 驱动选中态，点击 `LikeRepository.toggle(storyId, uid)`。likeCount 由 CF 维护，**前端不自己加**——靠 `watchById` 自动刷新（1–2 秒延迟正常）。

**验收**：点赞/取消幂等；likeCount 1–2 秒内变化；重复点不重复计数。

#### T3.4 评论（R7，P0）

**工作内容**：评论区 `CommentRepository.watchComments(storyId)` 列出；输入框 `add(storyId, StoryComment(authorId: uid, authorName, text, ...))`；自己的评论可 `delete`。commentCount 同样由 CF 维护，靠 stream 刷新。

**验收**：评论实时增删；commentCount 自动同步；非作者不能删他人评论（配合 T1.10 规则）。

#### T3.5 排行榜视图（R7，P1）

**工作内容**：广场内独立「排行榜」入口，`streamSquareFeed(sort: hotScore, limit: 20)` 展示 Top N，带名次序号。

**验收**：高赞高评在前；点赞/评论后顺序合理变化；演示前 `recomputeHotScores` 刷新后榜单正常。

---

### P4 — 游戏化（R10–R11）

#### T4.1 展览厅画廊（R10，P0）

**工作内容**：展览厅 Tab 用 `OrigamiRepository.streamMine(uid)` 渲染折纸网格（`Image.network(origami.imageUrl)`，**客户端不直连 Storage**，只用 Firestore 给的 URL —— 见 `CLAUDE.md` §7）。空态提示「完成官方挑战解锁折纸」。

**验收**：已有折纸以网格展示；图片正常加载；空态友好。

#### T4.2 客户端触发折纸发放（R10，P0）

**工作内容**：完成官方挑战发布后，调 `generateOrigami` Callable（需在 `pubspec.yaml` 加 `cloud_functions` 依赖，T1.7 文档已注明本步会动 pubspec）。`FirebaseFunctions.instanceFor(region: 'asia-east1').httpsCallable('generateOrigami').call({...})`。成功后画廊出现新折纸。

**验收**：完成官方挑战 → 调用成功 → `streamMine` 新增一条 → 画廊可见；未完成挑战调用被拒（T1.8a 防刷）。

#### T4.3 主题房间 · 禅意花园（R11，P2）

**工作内容**：展览厅内一个「禅意花园」房间 UI（静态美术 / 简单动效即可），进入条件由 `users.unlocks.rooms` 是否含其 ID 决定（T1.8c 维护）。

**验收**：解锁后可进入；未解锁显示锁定态。

#### T4.4 魔法墨水解锁视觉（R11，P2）

**工作内容**：`users.unlocks.magicInk` 为 true 时，展览厅 / 编辑器给一个视觉彩蛋（如特殊主题色 / 笔触效果）。条件由 T1.8c 的 `engagementScore` 阈值触发。

**验收**：`magicInk` 翻 true 后视觉生效；false 时不显示。

---

## 4. 集成与联调（T1.9，R12）

依据原 `section1-TODO.md` T1.9（去掉模块 G 部分）。

**工作内容**：串联并逐段验证端到端主路径——登录（T1.5）→ 领官方挑战（T2.2）→ 写作发布（T2.1）→ 折纸奖励（T1.8 + T4.2）→ 发布到广场（T3.1）→ 点赞评论排行榜（T3.3/T3.4/T3.5 + T1.7）。建一个简单 bug 清单（可用 `docs/` 下一个 md），逐条修接缝。schema 若需微调统一改 `design.md` 并同步代码。**R12 后功能冻结，只许修不许加。**

**验收**

- [ ] 端到端主路径在一个测试账号上一气呵成跑通
- [ ] 折纸奖励链路（挑战→发放→画廊）通
- [ ] 点赞 / 评论 / 排行榜计数与排序正确
- [ ] 接缝 bug 清零，功能冻结

---

## 5. 提交规范提醒（遵循 docs/git-format.md）

- 分支示例：`feat/cf-origami`、`feat/p2-editor`、`feat/p2-official-challenge`、`feat/p3-square`、`feat/p3-like-comment`、`feat/p4-gallery`、`chore/remove-character-module`、`feat/seed-data`。
- commit 示例：
  - `chore(character): 单人重排移除角色查询模块 G`
  - `feat(functions): 接入折纸生成 Callable（预生成池 + Flux Schnell 备用）`
  - `feat(writing): 编辑器与官方挑战完整流`
  - `feat(square): 广场动态 + 点赞评论 + hotScore 排行榜`
  - `feat(gallery): 展览厅折纸画廊与折纸发放触发`
  - `feat(functions): 维护 user.stats 与 unlocks 派生字段`
- **每个任务完成后给出建议 commit message，等人工审核，Claude 不自行 commit。**

---

## 6. 任务速查表

| 任务 | 段 | 天 | 优先级 | 依赖 | 阻塞 |
|------|----|----|--------|------|------|
| 砍模块 G | A | R1 | P0 | — | — |
| T2.1 编辑器 | A | R2 | P0 | StoryRepository | 广场有内容 |
| T2.2 官方挑战流 | A | R3 | P0 | ChallengeRepository, T2.1 | 折纸发放 |
| T2.3 随机词 | A | R4 | P1 | T2.1 | — |
| T2.4 我的故事 | A | R4 | P1 | streamMyStories | — |
| T3.1 广场列表 | B | R5 | P0 | streamSquareFeed, T2.1 | 详情/点赞 |
| T3.2 详情页 | B | R6 | P0 | watchById, T3.1 | 评论/点赞 |
| T3.3 点赞 | B | R6 | P0 | LikeRepository, T1.7 | 排行榜 |
| T3.4 评论 | B | R7 | P0 | CommentRepository, T1.7 | — |
| T3.5 排行榜 | B | R7 | P1 | streamSquareFeed(hotScore) | — |
| T1.8a 折纸预生成池 | C | R8 | P0 | Storage 素材池 | T4.2 |
| T1.8b Replicate 备用 | C | R9 | P1 | T1.8a, Secrets | — |
| T4.1 画廊 | D | R10 | P0 | streamMine, T1.8a | — |
| T4.2 折纸发放触发 | D | R10 | P0 | cloud_functions, T1.8a, T2.2 | — |
| T1.8c user 派生字段 | D | R11 | P2 | T1.7 触发器 | 解锁视觉 |
| T4.3 禅意花园 | D | R11 | P2 | unlocks.rooms | — |
| T4.4 魔法墨水 | D | R11 | P2 | unlocks.magicInk | — |
| T1.9 联调 | E | R12 | P0 | 全部主路径 | 冻结 |
| T1.10a 规则+索引 | E | R13 | P0 | — | 演示安全 |
| T1.10b 种子数据 | E | R14 | P0 | T1.10a | 演示有料 |
| T1.11 部署+录制 | F | R15 | P0 | 全部 | **交付** |

---

> **唯一行动指引到此。** 后续若需改 schema 必先读 `docs/schema-design/design.md`；改任务细节先读本文件。Windows 跑不起来先查 `docs/dependencies.md` 附录。
