# next-design-detailed.md — 故事书 & 章节：细化实现设计

> **定位**：本文件是 `docs/next-design.md`（一句话需求）的**工程化细化**，作为 ClaudeCode 在本阶段的**唯一行动指引**（与 `single-TODO.md` 同口径，但只覆盖「故事书 & 章节」这一增量特性）。
> **三份事实来源继续生效**：数据模型权威 `docs/schema-design/design.md`、前端视觉/交互/动效权威 `docs/GUIDE/fronted-design.md`、提交规范 `docs/GUIDE/git-format.md`。本文件**新增/修改 schema 的部分须同步回 `design.md`**（D3 冻结后字段变更须经 P1，见 `CLAUDE.md` §2）。
> **任务编号**：本特性记为 **T6.x**（写作模块 P2 的延伸，文件树是 `fronted-design.md` §5 的承载），不与既有 T1–T4 冲突。
> **铁律**：① 数据读写只走 Repository，不裸调 Firestore；② 字段 camelCase，禁 snake_case；③ CF 维护字段前端禁写；④ **客户端不直连 Storage**（`CLAUDE.md` §7），封面上传走 CF 中转；⑤ Claude 不自行 `git commit`，每个子任务完成后给建议 message 等人工审核。

---

## 0. 需求复述与设计决策（动工前必读）

### 0.1 原始需求（`next-design.md`）

在「我的故事」界面里扩展**故事书**（≈ 文件夹）功能：打开一本故事书后显示**章节**（≈ 子文件夹），章节下聚合具体故事。所有文章新增两个字段表示**所属故事书**与**所属章节**；创建时未指定则落入「默认故事书 / 默认章节」。故事书有默认封面、支持更换封面。

前端两屏：

1. **故事书总览**：点「我的故事」进入，流式布局展示「封面 + 书名 + 创建时间」，支持「创建时间排序 / 修改时间排序」，支持 pin（置顶）。
2. **故事书内部**：类文件树布局，按行聚合不同章节，一个章节可含多个故事。

### 0.2 已敲定的设计决策（本轮拍板，作为后续实现约束）

| 决策点 | 选择 | 理由 |
|--------|------|------|
| **数据建模** | story 加 `storybookId` + `chapterName` 两字段；另设**轻量 `storybooks/{id}` 集合**只存故事书元数据（封面 / 书名 / pin / 时间戳） | 「章节」只是字符串名字，无需独立集合（贴合「仅给 story 加两字段」）；但封面 / pin / 排序需要一个挂载点，故故事书必须有自己的文档 |
| **章节** | **不建集合**，仅作 story 上的 `chapterName` 字符串 + 故事书内 `chapterOrder` 顺序数组（见 §1.2） | 章节是组织视图，聚合靠 `where(storybookId).orderBy` 在客户端按 `chapterName` 分组即可 |
| **封面** | **CF 中转上传**：客户端 base64 → 新 Callable `uploadStorybookCover` → CF 写 Storage → 回 `coverUrl` 存故事书文档 | 守住 `CLAUDE.md` §7「客户端不直连 Storage」；Windows 上 `firebase_storage` 支持有限，统一走 CF 与折纸图同模式 |
| **默认封面** | 内置若干 asset 预设；故事书 `coverUrl` 为空时前端回落到预设（按 `storybookId` 哈希取一张） | 零成本、零 Storage 依赖即可有封面；上传是「换更好看的」增强 |
| **默认故事书** | 每用户一本 `isDefault=true` 的「未分类」故事书，首次写故事时惰性创建；默认章节名常量 `DEFAULT_CHAPTER = "未分章"` | 满足「未指定则落入默认」；默认书不可删、不可改名（可换封面、可 pin） |

> **与 `fronted-design.md` §5 的关系**：§5 已规定书写界面左栏是「折纸箱 = 文件夹、纸鸟 = 文章」的文件树，但当时分组是固定两层（草稿 / 已发布）。本特性**把分组维度从「草稿/已发布」升级为「故事书 → 章节」**，折纸箱造型、Lottie 资源、动效令牌全部复用，不另起视觉体系。草稿/已发布改为故事卡片上的**状态徽记**而非分组层级。

---

## 1. 数据模型变更（须同步回 `schema-design/design.md`）

### 1.1 `stories/{storyId}` 新增字段

在现有 `stories` 文档（`design.md` §3）追加两个字段：

| 字段 | 类型 | 必填 | 维护方 | 说明 |
|------|------|------|--------|------|
| `storybookId` | string | 是 | Client | 所属故事书文档 ID。未指定时写入该用户默认故事书 ID |
| `chapterName` | string | 是 | Client | 所属章节名。未指定时写入常量 `"未分章"`（`DEFAULT_CHAPTER`） |

**约束**

- 两字段均**非空**：`Story.toCreateMap()` 必须带上它们（默认值由写入前在客户端补齐，见 §3.1）。
- 既有数据迁移：旧 story 无此两字段 → 一次性迁移脚本（§5.3）把它们补成「默认故事书 / 未分章」。读取层对缺字段做防御性默认（`storybookId ?? defaultId`，`chapterName ?? '未分章'`），保证迁移前不崩。
- **不引入新的 CF 维护字段**：这两个字段纯 Client 写，安全规则只校验 `storybookId` 指向的故事书属于本人（见 §4）。

### 1.2 新增集合 `storybooks/{storybookId}`

故事书元数据。文档 ID 自动生成（或对默认书用确定性 ID `default_{uid}`，便于惰性创建幂等，见 §3.1）。

| 字段 | 类型 | 必填 | 维护方 | 说明 |
|------|------|------|--------|------|
| `ownerId` | string (uid) | 是 | Client | 拥有者 uid。安全规则据此限制读写 |
| `title` | string | 是 | Client | 书名。默认书固定 `"未分类"` |
| `coverUrl` | string \| null | 否 | CF | 封面图 URL（CF 上传后回写）；为空时前端回落内置预设 |
| `coverAssetId` | string \| null | 否 | Client | 选用的内置预设封面 ID（如 `"cover_zen_01"`）；与 `coverUrl` 互斥，`coverUrl` 优先 |
| `chapterOrder` | array&lt;string&gt; | 否 | Client | 章节展示顺序（章节名数组）；缺省按 story 的 `createdAt` 推断顺序 |
| `isDefault` | bool | 是 | Client | 是否默认「未分类」书。默认书禁删、禁改名 |
| `pinned` | bool | 是 | Client | 是否置顶。总览中 pinned 优先排前 |
| `storyCount` | int | 否 | CF（可选） | 冗余故事数，用于总览卡片角标。**首版可不接 CF**，前端用 `streamByStorybook` 长度兜底 |
| `createdAt` | timestamp | 是 | Client | `serverTimestamp()` |
| `updatedAt` | timestamp | 是 | Client | 书名/封面/章节顺序变更时更新；用于「修改时间排序」 |

**说明**

- `coverUrl` 标记为 CF 维护，是因为上传走 CF（§2）回写，**前端禁直写 `coverUrl`**（安全规则强制）；但 `coverAssetId`（选内置预设）是纯前端开关，可直写。
- `storyCount` 列为可选 CF 字段：首版为省一个触发器，前端直接用故事流长度显示，不接 CF；若后续要在总览不拉故事流就显数量，再补触发器（与 `users.stats` 同模式）。
- **修改时间排序**依赖 `updatedAt`：前端在 story 增删、改名、换封面时一并 `update` 故事书的 `updatedAt`（见 §3.2）。

### 1.3 集合总览表追加（同步 `design.md` §集合总览）

| 集合路径 | 归属模块 | 说明 |
|----------|----------|------|
| `storybooks/{storybookId}` | P2 | 故事书元数据（封面 / pin / 章节顺序），章节不单独建集合 |

### 1.4 索引追加（同步 `design.md` §索引 与 `firestore.indexes.json`）

新增两条复合索引：

- `storybooks`：`ownerId ASC` + `pinned DESC` + `updatedAt DESC` —— 故事书总览（置顶优先 + 修改时间排序）
- `storybooks`：`ownerId ASC` + `pinned DESC` + `createdAt DESC` —— 故事书总览（置顶优先 + 创建时间排序）
- `stories`：`storybookId ASC` + `chapterName ASC` + `createdAt ASC` —— 故事书内按章节聚合（替代/补充既有 `mode+challengeId+createdAt`，二者并存不冲突）

> 单字段排序（如仅 `ownerId` + `updatedAt`）Firestore 自动建；上面三条因含多字段需在 `firestore.indexes.json` 显式声明，随 T1.10a 一并 `firebase deploy --only firestore:indexes`。若开发期遇「需要索引」报错，按 `docs/GUIDE/挑战发布.md` 末尾排查刷新法处理。

---

## 2. 后端：封面上传 Cloud Function（T6.0）

> 唯一的后端增量。落到 `functions/src/uploadStorybookCover.ts`，复用 `index.ts` 已有的 `initializeApp` / `setGlobalOptions`（asia-east1 / maxInstances 5），参照 `generateOrigami.ts` 的 `onCall` + `HttpsError` + emulator 分支写法保持同款。

### 2.1 `uploadStorybookCover` Callable

- **入参**：`{ storybookId: string, imageBase64: string, contentType?: string, __testUid?: string }`（`contentType` 缺省 `image/png`；`__testUid` 仅 emulator 用，对齐 `generateOrigami.ts` 的同名约定）。
- **鉴权 + 归属校验**：`uid = request.auth?.uid ?? (isEmulator ? request.data.__testUid : undefined)`（**逐字照搬 `generateOrigami.ts` L67–77 的 emulator 分支写法**，`isEmulator = process.env.FUNCTIONS_EMULATOR === 'true'`）；`uid` 必须等于该 `storybooks/{storybookId}.ownerId`，否则 `throw new HttpsError('permission-denied', '只能给自己的故事书换封面')`。
- **大小限制**：`Buffer.from(imageBase64, 'base64')` 解码后校验 ≤ 1 MB，超限 `throw new HttpsError('invalid-argument', '封面图过大')`。
- **写 Storage**：路径 `storybook-covers/{uid}/{storybookId}.png`，`getStorage().bucket().file(path).save(buf, { contentType })`（同 `generateOrigami.ts` `runReplicate` L301–305 的落图写法）。覆盖写（同书换封面直接覆盖，URL 不变省去清理）。
- **取 URL**：复用 `generateOrigami.ts` 的 `firebaseDownloadUrl(bucketName, objectName)`（拼 `https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encoded}?alt=media`，**抽成共享 helper 复用，勿重复实现**）。可访问性依赖 `storage.rules` 对 `storybook-covers/**` 开 `read`（与 `origami/**` 同 `read:true` 口径）。
- **回写 Firestore**：`storybooks/{storybookId}.update({ coverUrl, coverAssetId: null, updatedAt: FieldValue.serverTimestamp() })`（上传成功即清空 `coverAssetId`，让 `coverUrl` 生效；用 `firebase-admin/firestore` 的 `FieldValue`，同既有 CF）。
- **出参**：`{ coverUrl }`。
- `index.ts` 追加 `export { uploadStorybookCover } from "./uploadStorybookCover";`。

### 2.2 验收

- [ ] Emulator：建一本属于测试 uid 的故事书 → 传 base64 → Storage 落图 + `storybooks` 的 `coverUrl` 回写 + 返回 URL
- [ ] 归属校验：传他人故事书 ID 被拒（`permission-denied`）
- [ ] 大小校验：超 1 MB 被拒（`invalid-argument`）
- [ ] 仓库内搜不到任何上传凭证明文；`npm run build` 无 TS 报错；`index.ts` 正确导出

---

## 3. 数据访问层：StorybookRepository（T6.1）

> 新增 `lib/data/models/storybook.dart` + `lib/data/repositories/storybook_repository.dart`（单例 `StorybookRepository.instance`，与既有 Repository 同款）。同时**扩展 `Story` 模型与 `StoryRepository`** 接纳两个新字段。所有签名一旦交付即冻结，对齐 `single-TODO.md` §0.2 风格。

### 3.1 StorybookRepository 接口（建议签名）

```dart
// lib/data/models/storybook.dart
class Storybook {
  final String id;
  final String ownerId;
  final String title;
  final String? coverUrl;        // CF 维护，前端禁写
  final String? coverAssetId;    // 前端可写（选内置预设）
  final List<String> chapterOrder;
  final bool isDefault;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  // fromDoc / toCreateMap（toCreateMap 不含 coverUrl，由 CF 写）
}

enum StorybookSort { createdAt, updatedAt }   // 对应「创建时间 / 修改时间排序」

// lib/data/repositories/storybook_repository.dart
class StorybookRepository {
  static final StorybookRepository instance = ...;

  // 总览：置顶优先 + 指定时间排序
  Stream<List<Storybook>> streamMine(String uid, {StorybookSort sort = StorybookSort.updatedAt});

  Future<Storybook?>     getById(String storybookId);
  Stream<Storybook?>     watchById(String storybookId);

  // 惰性拿/建默认书：返回该用户的 isDefault 书，无则用确定性 ID `default_{uid}` 创建
  Future<Storybook>      getOrCreateDefault(String uid);

  Future<String>         create(Storybook draft);            // 返回新 storybookId
  Future<void>           rename(String storybookId, String title);   // 默认书禁用（isDefault 时抛错或前端不暴露）
  Future<void>           setPinned(String storybookId, bool pinned);
  Future<void>           setCoverAsset(String storybookId, String coverAssetId);  // 选内置预设
  Future<void>           setChapterOrder(String storybookId, List<String> order);
  Future<void>           touch(String storybookId);          // 仅刷新 updatedAt（story 增删时调）
  Future<void>           delete(String storybookId);         // 默认书禁删；删非空书的处置见下
}
```

**删除非空故事书的处置**：删一本含故事的书时，把其下所有 story 的 `storybookId` 改回该用户默认书、`chapterName` 置 `"未分章"`（迁移而非级联删，避免误删正文），再删书文档。此逻辑放 Repository 内（一次批量 `WriteBatch`）。**默认书 `isDefault=true` 不可删**（前端不暴露删除入口，Repository 二次防御抛错）。

**封面上传调用**（前端经 `cloud_functions` 调 §2 的 CF，不在 Repository 直传）：

```dart
// 放 StorybookRepository 或单独 service，调 CF
Future<String> uploadCover(String storybookId, Uint8List bytes) async {
  final base64 = base64Encode(bytes);
  final res = await FirebaseFunctions.instanceFor(region: 'asia-east1')
      .httpsCallable('uploadStorybookCover')
      .call({'storybookId': storybookId, 'imageBase64': base64});
  return res.data['coverUrl'] as String;   // CF 已回写 Firestore，watchById 会自动刷新
}
```

### 3.2 StoryRepository 扩展（保持既有签名兼容）

既有签名（`single-TODO.md` §0.2）**不破坏**，按以下方式扩展：

```dart
// Story 模型加两字段
Story { ... 既有字段 ..., storybookId, chapterName }   // 均非空，toCreateMap 必带

// create：Story 已含两字段；若调用方未设，写入前补默认（见调用约定）
Future<String> create(Story draft);   // 签名不变，draft 内已带 storybookId/chapterName

// update 扩展可选参数（既有参数保留）
Future<void> update(String storyId, {
  String? title, String? body, StoryVisibility? visibility, bool? publishedToSquare,
  String? storybookId, String? chapterName,    // 新增：移动故事到别的书/章节
});

// 新增：故事书内按章节聚合（替代用 streamByChallenge 的思路）
Stream<List<Story>> streamByStorybook(String storybookId, {int limit = 200});
```

**调用约定（关键）**：编辑器/写作流在 `create` 前必须保证 `draft.storybookId` 与 `draft.chapterName` 非空——未选则调 `StorybookRepository.getOrCreateDefault(uid)` 拿默认书 ID + `DEFAULT_CHAPTER`。**story 增删 / 改名 / 移动后**，调用方负责 `StorybookRepository.touch(targetStorybookId)` 刷新 `updatedAt`（让「修改时间排序」准确）。

### 3.3 验收

- [ ] `Storybook` 模型 fromDoc/toCreateMap 正确，camelCase 无误
- [ ] `getOrCreateDefault` 幂等：同一 uid 多次调只得到一本默认书（确定性 ID `default_{uid}`）
- [ ] `streamMine` 置顶优先 + 两种排序均生效（依赖 §1.4 索引）
- [ ] `streamByStorybook` 拉到该书全部 story，可在客户端按 `chapterName` 分组
- [ ] `Story` 加两字段后既有写作流仍能 `create`（向后兼容，未指定走默认）
- [ ] 删非空书：其下 story 迁回默认书未被误删；默认书删除被拒

---

## 4. 安全规则（同步 `firestore.rules`，随 T1.10a 收紧时一并落）

`storybooks/{storybookId}`：

- **读**：仅 `resource.data.ownerId == request.auth.uid`（故事书是私有组织视图，不对外公开）。
- **建**：`request.auth.uid == request.resource.data.ownerId` 且 `isDefault` 与 `pinned` 类型合法；**禁止前端写 `coverUrl`**（`!('coverUrl' in request.resource.data)` 或建时必须为 null/缺省）。
- **改**：仅 owner；**字段级 CF-only**——任何含 `coverUrl` 的 update 一律拒（`coverUrl` 只能由 §2 的 CF 用 Admin SDK 绕规则写）；`title` 在 `isDefault==true` 时禁改。
- **删**：仅 owner 且 `isDefault==false`。

`stories/{storyId}` 既有规则**追加校验**：写 `storybookId` 时，该 ID 指向的故事书须属于本人（`get(/databases/.../storybooks/$(storybookId)).data.ownerId == request.auth.uid`）；`chapterName` 为非空 string。其余 `likeCount`/`commentCount`/`hotScore` CF-only 规则不变。

`storage.rules`：`storybook-covers/{file=**}` 前端**禁写**（仅 CF Admin SDK 用运行时服务账号绕规则写），`allow read: if true`（与既有 `origami/{file=**}` 的 `read:true` 同口径，使 `firebaseDownloadUrl` 拼出的免 token URL 可被 `Image.network` 直接加载）。

**验收**

- [ ] Emulator：读他人故事书被拒
- [ ] 前端尝试 update `coverUrl` 被拒；改默认书 `title` 被拒；删默认书被拒
- [ ] story 写入指向他人故事书的 `storybookId` 被拒

---

## 5. 前端两屏 + 文件树升级（T6.2 / T6.3 / T6.4）

> 视觉/动效令牌全部取 `fronted-design.md`（颜色 `paperBase`/`inkPrimary`/`accentVermilion`/`goldLeaf`、圆角卡片 12、间距 4 的倍数、`durFold`/`curveFold` 等）。折纸箱用 §2.2 `box_closed/box_open` Lottie，纸鸟用 `bird_idle`，空态用 `empty_paper`。一律走皮肤令牌，禁硬编码。

### 5.1 T6.2 — 故事书总览屏（点「我的故事」进入）

**路由**：`/writing/storybooks`（或「我的故事」入口跳此）。挂 `app_router.dart` 的 `ShellRoute` 内，用 `CustomTransitionPage` 套 §3 翻书折叠转场。

**布局**：流式网格（`Wrap` / `GridView`，桌面端每行 3–4 张，外边距 24，卡片间距 12）。每张故事书卡片：

- 封面区：`coverUrl` 有则 `Image.network`，否则按 `coverAssetId` 或 `storybookId` 哈希取内置预设 asset。卡片 12 圆角，`goldLeaf` 细边（呼应「藏品/书」质感），hover 轻微抬起 + 投影加深（同 §9 画廊卡）。
- 书名（`inkPrimary`，文章标题字号 20/Medium）+ 创建时间或修改时间（`inkSecondary`，12 辅助字号，随当前排序显示对应时间）。
- pin 角标：`pinned==true` 时左上角一枚 `accentVermilion` 折角徽记。

**交互**：

- 顶部分段控件切「创建时间 / 修改时间」排序（对应 `StorybookSort`），切换时列表轻量错峰重排淡入（**不做整页翻书**，同 §6.4 列表重排规范）。
- 卡片右键（桌面端）/ 长按上下文菜单：置顶（`setPinned`）/ 改名（`rename`，默认书禁用）/ 换封面（§5.4）/ 删除（`delete`，默认书禁用，二次确认）。
- 点卡片进故事书内部屏（§5.2），前进向翻书折叠。
- 「+ 新建故事书」入口卡（虚线框 + `box_closed` 图标），点按弹建书对话框（书名输入 + 选预设封面），调 `StorybookRepository.create`。
- 空态：仅有默认书且无故事时，`empty_paper.json` + 文案「还没有故事，落笔写第一篇」。

**验收**：流式渲染真实数据；两种排序 + pin 生效；进入/新建/改名/删除/换封面闭环；默认书的改名删除入口不出现。

### 5.2 T6.3 — 故事书内部屏（类文件树，按章节聚合）

**路由**：`/writing/storybooks/:storybookId`。数据 `StoryRepository.streamByStorybook(storybookId)`，客户端按 `chapterName` 分组，组顺序取故事书 `chapterOrder`（无则按各章首篇 `createdAt`）。

**布局**（对齐 `fronted-design.md` §5 文件树，但分组维度=章节）：

```
┌──────────────────────────────────────────────┐
│  ← 返回   《书名》            [+ 新建章节][排序] │  ← 顶栏
├──────────────────────────────────────────────┤
│  📦 第一章                                      │  ← 折纸箱 = 章节（行聚合）
│   ├ 🕊 故事A   [草稿]                           │  ← 纸鸟 = 文章 + 状态徽记
│   └ 🕊 故事B   [已发布]                         │
│  📦 未分章                                      │
│   └ 🕊 故事C                                    │
└──────────────────────────────────────────────┘
```

- **章节行（折纸箱）**：`box_closed/box_open` Lottie，单击展开/折叠（盒盖动画 + 子项 `durFold` 高度展开，§5.1/§10 速查表）。章节名 `inkPrimary`，右侧显故事数。
- **故事节点（纸鸟）**：`bird_idle` + 标题；草稿（`visibility=private`）/ 已发布（`publishedToSquare=true`）用**状态徽记**区分（小标签，已发布用 `accentSeal` 印章意象），不再作为分组层级。hover 纸鸟轻振翅，选中底色 `surfaceCard` + 左 `accentVermilion` 竖条。
- 单击纸鸟 = 打开该故事（进编辑器校阅模式，§5 既有）；右键 = 编辑 / 删除 / 移动到其他章节或故事书 / 发布到广场。
- 「+ 新建章节」：仅新增一个章节名进 `chapterOrder`（章节是逻辑分组，空章节也可先建好再往里写）。
- 「移动」交互：右键故事 → 选目标故事书 + 章节 → 调 `StoryRepository.update(storyId, storybookId:.., chapterName:..)` + 两端 `touch`。桌面端可选支持拖拽纸鸟跨章节（拖到另一折纸箱上落下，P2 增强，资源紧可只做菜单移动）。

**验收**：按章节正确聚合;展开/折叠动画;新建章节;故事移动跨章/跨书生效;草稿/已发布徽记正确;空章节可显示。

### 5.3 旧数据迁移脚本（T6.5，与 schema 变更同 PR）

一次性 Node + Admin SDK 脚本（放 `functions/scripts/` 或 `scripts/`，不入正式部署）：

1. 遍历所有 `users`，为每人 `getOrCreate` 默认书（确定性 ID `default_{uid}`，`isDefault=true`、`title="未分类"`）。
2. 遍历所有 `stories`，无 `storybookId` 的补成该作者默认书 ID、无 `chapterName` 的补 `"未分章"`。
3. 幂等：重复跑不重复建默认书、不覆盖已有归属。

**验收**：跑后所有旧 story 有合法 `storybookId`/`chapterName`，总览/内部屏能正常渲染历史数据。

### 5.4 换封面交互（贯穿 §5.1 / §5.2）

两种来源，统一入口（卡片菜单「换封面」或建书对话框）：

- **选内置预设**：弹预设封面网格，选中即 `setCoverAsset(storybookId, assetId)`（纯前端写 `coverAssetId`，`coverUrl` 仍空时按 `coverAssetId` 显示预设）。零成本、即时。
- **上传自定义**：用户选本地图片 → 客户端读 bytes → 调 §3.1 `uploadCover`（经 §2 CF）→ CF 回写 `coverUrl` → `watchById` 自动刷新封面。上传期间用 `loading_brush.json` 占位；失败回退提示，不阻塞。

**验收**：选预设即时换;上传走 CF 成功后封面更新;上传失败有提示不崩;`coverUrl` 存在时优先于 `coverAssetId`。

---

## 6. 动效对接（全部复用 `fronted-design.md`，无新增动效体系）

| 场景 | 复用动效 | 令牌 |
|------|----------|------|
| 「我的故事」→ 故事书总览 | 前进向翻书折叠（§3.1） | `durFold` / `curveFold` |
| 总览 → 故事书内部 | 前进向翻书折叠 | 同上 |
| 排序切换（总览） | 列表错峰重排淡入（§6.4，不翻书） | 每行 60ms 错峰 |
| 章节折纸箱展开/折叠 | 盒盖开合 + 子项高度展开（§10） | `box_open` / `durFold` |
| 新建/删除故事书 | 卡片淡入 / 揉皱缩小消失（§5.3 删除意象，可选） | `durSaveFold` 反向 |
| 换封面上传中 | 毛笔运笔加载（§2.3） | `loading_brush` |

降级口径同 `fronted-design.md` §7：减少动态效果 → 翻书退 Fade、列表重排退直接刷新、Lottie 缺失退静态图标。

---

## 7. 任务拆分与建议日程（T6.x）

> 本特性是写作模块增量，建议插在 P2（R1–R4）之后、社区（P3）之前，或作为主路径打通后的并行增强。单人节奏下约 2.5–3 个 R 完成。

| 任务 | 内容 | 优先级 | 依赖 | 阻塞 |
|------|------|--------|------|------|
| **T6.0** | 封面上传 CF `uploadStorybookCover`（§2） | P1 | `index.ts` 基座 | 自定义封面 |
| **T6.1** | `Storybook` 模型 + `StorybookRepository` + `StoryRepository` 扩两字段（§3） | P0 | T1.6 数据层 | 全部前端 |
| **T6.2** | 故事书总览屏（§5.1） | P0 | T6.1 | 内部屏 |
| **T6.3** | 故事书内部屏 · 章节文件树（§5.2） | P0 | T6.1, T6.2 | — |
| **T6.4** | 编辑器/写作流接默认书 + 移动/换封面交互（§3.2 调用约定, §5.4） | P0 | T6.1, T2.1 编辑器 | — |
| **T6.5** | 旧数据迁移脚本（§5.3） | P0 | T6.1 | 历史数据可渲染 |
| **T6.6** | 安全规则 + 索引（§4, §1.4），并入 T1.10a 一起部署 | P0 | T6.1 | 演示安全 |

**建议日程**

- **R-a**：T6.1（模型 + Repository + Story 扩字段，含单测/emulator 验证）→ T6.5（迁移脚本）。先把数据层和历史数据打通。
- **R-b**：T6.2 总览屏 + T6.4 写作流接默认书（写故事自动落默认书/章节）。
- **R-c**：T6.3 内部屏文件树 + T6.0 封面 CF + §5.4 换封面闭环。规则/索引（T6.6）并入 T1.10a 统一部署。

**缓冲牺牲顺序**（资源紧时）：拖拽移动故事（退为菜单移动）→ 自定义封面上传（只留内置预设，T6.0 可缓）→ 章节顺序自定义（退为按时间）。**绝不牺牲**：故事书总览、章节聚合、默认书惰性创建、旧数据迁移。

---

## 8. 提交规范（遵循 `docs/GUIDE/git-format.md`）

- 分支示例：`feat/p2-storybook-model`、`feat/p2-storybook-overview`、`feat/p2-chapter-tree`、`feat/cf-cover-upload`、`chore/migrate-storybook`、`docs/storybook-design`。
- commit 示例：
  - `docs(frontend): 故事书与章节细化实现设计`
  - `feat(data): 新增 Storybook 模型与 Repository，Story 加 storybookId/chapterName`
  - `feat(functions): 封面上传 Callable uploadStorybookCover`
  - `feat(writing): 故事书总览与章节文件树`
  - `chore(migrate): 旧 story 回填默认故事书与章节`
- schema 变更（§1）须在**同一 PR** 内更新 `docs/schema-design/design.md`（§集合总览 / §3 stories / §索引 / §安全规则要点 四处）。
- **每个子任务完成后给出建议 commit message，等人工审核，Claude 不自行 commit。**

---

## 9. 自查清单（落地前对照）

- [ ] schema 变更已同步回 `design.md`（stories 两字段 + storybooks 集合 + 两条索引 + 安全规则要点）
- [ ] 字段全 camelCase，无 snake_case
- [ ] 前端禁写字段：`coverUrl`（CF-only）、既有 `likeCount`/`commentCount`/`hotScore` 不受影响
- [ ] 客户端无任何直连 Storage 代码；封面上传只经 `uploadStorybookCover` CF（守 `CLAUDE.md` §7）
- [ ] 默认书惰性创建幂等（确定性 ID）；默认书禁删禁改名在 Repository + 规则双重防御
- [ ] 旧数据迁移脚本幂等，跑后历史 story 全有合法归属
- [ ] 索引声明进 `firestore.indexes.json`，随 T1.10a 部署，无「需要索引」报错
- [ ] 视觉/动效令牌全取 `fronted-design.md`，无硬编码颜色/时长
- [ ] 数据读写只走 Repository，无裸 Firestore 调用

---

> **细化设计到此。** 实现期遵循：schema 改动同步 `design.md`、视觉走 `fronted-design.md` 令牌、数据只走 Repository、客户端不直连 Storage、Claude 不自行 commit。本特性如需调整，更新本文件保持单一事实来源。
