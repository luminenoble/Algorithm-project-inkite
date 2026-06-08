# Firestore 数据模型设计（data-model）

> 适用项目：Inkite（Flutter + Firebase）
> 状态：**草案**，待 D3 全员评审后冻结。冻结后任何字段变更须经 P1 同意并同步本文档。
> 命名约定：集合与字段使用 **camelCase**；文档 ID 在 schema 中以 `{xxxId}` 表示。
> 维护方说明：`Client` = 由客户端写入；`CF` = 由 Cloud Functions 触发器维护；`Auth` = 由 Firebase Auth 管理。

---

## 设计原则

1. **不存储密码**：用户身份与凭证完全交由 Firebase Auth，Firestore 内不出现 `password` 相关字段。
2. **子集合优先**：评论、点赞等"从属于故事"的数据用子集合，避免顶层集合膨胀。
3. **幂等点赞**：以 `uid` 作为点赞文档 ID，天然保证一人一赞。
4. **冗余计数反范式**：列表/排行榜依赖的计数（`likeCount` / `commentCount` / `hotScore`）冗余写在父文档上，由 Cloud Functions 维护，**前端禁止直写**（在安全规则中强制）。
5. **官方挑战 vs 自由词分离**：官方挑战是持久资源，自由模式的随机词由客户端临时生成、**不入库**。
6. **奖励两分**：AI 折纸藏品是实例集合（user × 多张），能力解锁（魔法墨水 / 主题房间）是开关，挂在 `users.unlocks` 下。

---

## 集合总览

| 集合路径 | 归属模块 | 说明 |
|----------|----------|------|
| `users/{uid}` | P1 | 用户档案、统计、解锁状态 |
| `challenges/{challengeId}` | P2 | 官方三词挑战 |
| `stories/{storyId}` | P2 / P3 | 故事正文及冗余计数 |
| `stories/{storyId}/comments/{commentId}` | P3 | 故事评论（子集合） |
| `stories/{storyId}/likes/{uid}` | P3 | 点赞记录（uid 为文档 ID） |
| `storybooks/{storybookId}` | P2 | T6：故事书元数据（封面 / pin / 章节顺序），章节不单独建集合 |
| `origami/{origamiId}` | P4 | AI 折纸藏品实例 |
| `charactersCache/{characterKey}` | 模块 G | 角色查询缓存（Wikipedia + Reddit） |

---

## 1. `users/{uid}`

文档 ID 与 Firebase Auth 的 `uid` 一致。用户首次登录由 `AuthService` 自动创建。

| 字段 | 类型 | 必填 | 维护方 | 说明 |
|------|------|------|--------|------|
| `displayName` | string | 是 | Client | 昵称，初始可取邮箱前缀 |
| `photoURL` | string | 否 | Client | 头像 URL（可空） |
| `createdAt` | timestamp | 是 | Client | 注册时间，`serverTimestamp()` |
| `stats.storiesCount` | int | 是 | CF | 已发布故事数 |
| `stats.likesReceived` | int | 是 | CF | 累计收到点赞 |
| `stats.officialChallengesCount` | int | 是 | CF | F2：已发布官方挑战故事数。F2 bonus 阈值 5 |
| `stats.engagementScore` | int | 是 | CF | 参与度得分，用于解锁判定 |
| `unlocks.magicInk` | bool | 是 | CF | 是否解锁魔法墨水 |
| `unlocks.rooms` | array&lt;string&gt; | 是 | CF | 已解锁的主题房间 ID 列表 |
| `aiUsage.weekStartAt` | timestamp | 否 | CF | F2：当前 7 天窗口起点（首次 AI 调用时设）。null = 从未调用 |
| `aiUsage.count` | int | 否 | CF | F2：本窗口已用 AI 折纸次数 |
| `aiUsage.bonusLikes` | bool | 否 | CF | F2：likesReceived 已跨过 20，+1 quota（单向） |
| `aiUsage.bonusChallenges` | bool | 否 | CF | F2：officialChallengesCount 已跨过 5，+1 quota（单向） |

**说明**
- `stats.*` 与 `unlocks.*` 由 Cloud Functions 在点赞/发布/挑战完成等事件触发更新。
- 邮箱、登录方式等鉴权信息保留在 Firebase Auth 内，不冗余到此处。

---

## 2. `challenges/{challengeId}`

官方挑战，由运营预置或脚本生成。**自由模式的随机词不进此集合**（前端实时生成即可）。

| 字段 | 类型 | 必填 | 维护方 | 说明 |
|------|------|------|--------|------|
| `title` | string | 是 | 运营 | 挑战标题 |
| `words` | array&lt;string&gt; | 是 | 运营 | 三个关键词，长度 = 3 |
| `startAt` | timestamp | 是 | 运营 | 生效开始时间 |
| `endAt` | timestamp | 是 | 运营 | 生效结束时间 |
| `isActive` | bool | 是 | 运营 / CF | 是否当前活跃，便于客户端 `where` 查询 |
| `createdAt` | timestamp | 是 | 运营 | 创建时间 |
| `imagePool` | string | 否 | 运营 | F1：Storage 中本挑战折纸图源前缀，如 `origami/challenges/qiu-shuang`。缺省回落 `origami/pool/{style}`。详见 `docs/AI-feature/F1-per-challenge-pool.md` |
| `style` | string | 否 | 运营 | F1：本挑战发放折纸的 style 标签，写入 `origami.style`。缺省按 `challengeId` 哈希取 `zen / steampunk / ink` 之一 |

---

## 3. `stories/{storyId}`

故事主文档。

| 字段 | 类型 | 必填 | 维护方 | 说明 |
|------|------|------|--------|------|
| `authorId` | string (uid) | 是 | Client | 作者 uid |
| `authorName` | string | 是 | Client | 冗余作者昵称，避免列表渲染再查 user |
| `title` | string | 是 | Client | 故事标题 |
| `body` | string | 是 | Client | 故事正文 |
| `mode` | string | 是 | Client | 枚举：`official` / `free` / `diary` / `essay` / `fanfic` |
| `challengeId` | string \| null | 否 | Client | `mode = official` 时引用 `challenges/{id}` |
| `words` | array&lt;string&gt; \| null | 否 | Client | 写作时用到的三词快照（防挑战被修改后语义丢失） |
| `visibility` | string | 是 | Client | 枚举：`private` / `public` |
| `publishedToSquare` | bool | 是 | Client | 是否已发布到广场 |
| `storybookId` | string | 是 | Client | T6：所属故事书文档 ID。未指定时写入该用户默认书 ID（`default_{uid}`） |
| `chapterName` | string | 是 | Client | T6：所属章节名。未指定时写入常量 `未分章`（DEFAULT_CHAPTER） |
| `likeCount` | int | 是 | CF | 冗余计数；前端禁写 |
| `commentCount` | int | 是 | CF | 冗余计数；前端禁写 |
| `hotScore` | number | 是 | CF | 排行榜权重；公式：`likeCount*2 + commentCount + 时间衰减` |
| `createdAt` | timestamp | 是 | Client | `serverTimestamp()` |
| `updatedAt` | timestamp | 是 | Client | 编辑时更新 |

**说明**
- `likeCount` / `commentCount` / `hotScore` 在安全规则里限制为 **仅 Cloud Functions 可写**（T1.10）。
- 排行榜查询：`stories.where(visibility=public).orderBy(hotScore desc).limit(N)`，需复合索引。

---

## 4. `stories/{storyId}/comments/{commentId}`

故事评论，子集合。MVP 阶段不做楼中楼。

| 字段 | 类型 | 必填 | 维护方 | 说明 |
|------|------|------|--------|------|
| `authorId` | string (uid) | 是 | Client | 评论者 uid |
| `authorName` | string | 是 | Client | 冗余昵称 |
| `text` | string | 是 | Client | 评论内容 |
| `createdAt` | timestamp | 是 | Client | `serverTimestamp()` |

**说明**：评论的新增/删除由 CF 触发器维护父 `stories/{storyId}.commentCount`。

---

## 5. `stories/{storyId}/likes/{uid}`

点赞记录，**文档 ID = 点赞者 uid**，天然幂等。

| 字段 | 类型 | 必填 | 维护方 | 说明 |
|------|------|------|--------|------|
| `createdAt` | timestamp | 是 | Client | 点赞时间 |

**说明**
- 取消点赞 = 删除该文档。
- CF 触发器在创建/删除时更新父 `stories/{storyId}.likeCount` 及作者的 `users.stats.likesReceived`。

---

## 6. `origami/{origamiId}`

AI 折纸藏品实例。每完成一次官方挑战由 Cloud Function `generateOrigami`（T1.8）写入一条。

| 字段 | 类型 | 必填 | 维护方 | 说明 |
|------|------|------|--------|------|
| `ownerId` | string (uid) | 是 | CF | 拥有者 uid |
| `imageUrl` | string | 是 | CF | Cloud Storage 中的图片 URL |
| `style` | string | 是 | CF | 风格标签（如 `zen` / `steampunk`） |
| `sourceChallengeId` | string \| null | 是 | CF | 触发此次发放的挑战 ID；F2 自由 AI 路径写 null |
| `source` | string | 是 | CF | 来源：`pregen`（素材池）或 `flux`（实时生成） |
| `words` | array&lt;string&gt; | 否 | CF | F2 自由 AI 发放时，CF 写入用户输入的 3 个关键词；官方挑战发放为 null |
| `createdAt` | timestamp | 是 | CF | 发放时间 |

**说明**
- "魔法墨水" / "主题房间"等**能力解锁**不在此集合，挂在 `users.unlocks` 下（开关型语义）。
- 仅 CF 可写，前端禁写（防刷）。

---

## 7. `charactersCache/{characterKey}`

角色查询缓存。模块 G 已以「开拓」栏（方案 A：预爬 + 缓存查询）复活，详见
`docs/角色查询-todo.md`。数据由离线导入脚本 `functions/scripts/import_characters.mjs`
从姊妹项目 ISR-scraper 多源聚合写入（Admin SDK 绕规则）；**客户端只读**。

`characterKey`（文档 ID）= normalized 名称：小写、去标点、空白 → 单下划线。
例 `"Hu Tao"` → `hu_tao`。与 ISR 的 `doc_id`（sha1(url)）不同——app 端按角色名查询。

旧 5 字段（`name` / `wikiSummary` / `wikiUrl` / `redditPosts` / `cachedAt`）保持
向后兼容不动；新增字段全部可空、缺省安全默认（接口冻结，见 `CharacterCache.fromFirestore`）。

| 字段 | 类型 | 必填 | 维护方 | 说明 |
|------|------|------|--------|------|
| `name` | string | 是 | 导入脚本 | 角色名（展示用，保留原大小写） |
| `wikiSummary` | string | 是 | 导入脚本 | 官方权威摘要（ISR `HitCard.snippet_plain`，或 `DocDetail.body` 截断 ~800 字符） |
| `wikiUrl` | string | 是 | 导入脚本 | 官方条目链接（ISR `DocDetail.url`） |
| `redditPosts` | array&lt;object&gt; | 否 | 导入脚本 | 民间二创要点；每项 `{ title, url, snippet, source, tag }`，source∈{reddit,ao3} |
| `cachedAt` | timestamp | 是 | 导入脚本 | 导入时间（`serverTimestamp()`） |
| `source` | string | 否 | 导入脚本 | 主条目来源（fandom/wikipedia）；徽标配色锚点 |
| `tag` | string | 否 | 导入脚本 | canon/fanon/meta/crossover（ISR `Hit.tag`） |
| `popularity` | number | 否 | 导入脚本 | ISR popularity，「开拓」落地页热度排序（`listPopular` 降序取） |
| `obscurity` | number | 否 | 导入脚本 | ISR obscurity（冷门度），可做「发现冷门角色」入口 |
| `searchTokens` | array&lt;string&gt; | 是 | 导入脚本 | 角色名 normalize 后的累进前缀 + 分词，供 app 端 `array-contains` 名称搜索 |

**`searchTokens` 生成规则**：取角色名小写，对整名（含空格）与各分词分别生成累进前缀
（上限 12 字符）并去重。app 端 `where('searchTokens', arrayContains: queryLower).limit(N)`
做前缀搜索——单字段 `array-contains` 不需复合索引；`listPopular` 按 `popularity DESC`
单字段排序亦不需要（若后续加 `tag` 过滤 + 排序，再补 `firestore.indexes.json`）。

---

## 8. `storybooks/{storybookId}`（T6）

故事书元数据。文档 ID 自动生成；默认书用确定性 ID `default_{uid}` 便于惰性创建幂等。
「章节」不单独建集合，仅作 story 上的 `chapterName` 字符串 + 本文档的 `chapterOrder` 顺序数组。

| 字段 | 类型 | 必填 | 维护方 | 说明 |
|------|------|------|--------|------|
| `ownerId` | string (uid) | 是 | Client | 拥有者 uid。安全规则据此限制读写 |
| `title` | string | 是 | Client | 书名。默认书固定 `未分类` |
| `coverUrl` | string \| null | 否 | CF | 封面图 URL（`uploadStorybookCover` 上传后回写）；为空时前端回落内置预设。**前端禁写** |
| `coverAssetId` | string \| null | 否 | Client | 选用的内置预设封面 ID；与 `coverUrl` 互斥，`coverUrl` 优先 |
| `chapterOrder` | array&lt;string&gt; | 否 | Client | 章节展示顺序（章节名数组）；缺省按 story 的 `createdAt` 推断 |
| `isDefault` | bool | 是 | Client | 是否默认「未分类」书。默认书禁删、禁改名（可换封面、可 pin） |
| `pinned` | bool | 是 | Client | 是否置顶。总览中 pinned 优先排前 |
| `createdAt` | timestamp | 是 | Client | `serverTimestamp()` |
| `updatedAt` | timestamp | 是 | Client | 书名/封面/章节顺序/下属 story 增删变更时更新；用于「修改时间排序」 |

**说明**
- `coverUrl` 由 Cloud Function 经 Admin SDK 写入，安全规则禁止前端 update 任何含 `coverUrl` 的变更。
- `storyCount` 列为可选 CF 字段：首版不接触发器，前端用 `streamByStorybook` 长度兜底（详见 `docs/next-design-detailed.md` §1.2）。

---

## 索引（`firestore.indexes.json`）

D3 暂可空，D17 前由 T1.10 补齐。已知必需的复合索引：

- `stories`：`visibility ASC` + `hotScore DESC`（广场排行榜）
- `stories`：`authorId ASC` + `createdAt DESC`（"我的故事"列表）
- `stories`：`mode ASC` + `challengeId ASC` + `createdAt DESC`（按挑战聚合故事）
- `stories`：`storybookId ASC` + `chapterName ASC` + `createdAt ASC`（T6：故事书内按章节聚合）
- `storybooks`：`ownerId ASC` + `pinned DESC` + `updatedAt DESC`（T6：总览 · 置顶优先 + 修改时间排序）
- `storybooks`：`ownerId ASC` + `pinned DESC` + `createdAt DESC`（T6：总览 · 置顶优先 + 创建时间排序）

---

## 安全规则要点（对接 T1.4 / T1.10）

- `users/{uid}`：仅本人可写自己文档；`stats.*` / `unlocks.*` 仅 CF 可写。
- `stories/{storyId}`：作者可写自己；`visibility = public` 时任何已登录用户可读；`likeCount` / `commentCount` / `hotScore` 仅 CF 可写。T6：写入的 `storybookId` 须指向本人故事书（规则 `get()` 校验 ownerId）；`chapterName` 为非空 string。
- `storybooks/{storybookId}`（T6）：仅 owner 可读写；`coverUrl` 仅 CF（Admin SDK）可写，前端任何含 `coverUrl` 的 update 一律拒；默认书（`isDefault==true`）禁改名、禁删。`storage` 侧 `storybook-covers/**` 前端禁写、`read:true`。
- `stories/{storyId}/comments/{commentId}`：已登录可创建（authorId 必须等于 `request.auth.uid`），作者可删自己评论。
- `stories/{storyId}/likes/{uid}`：仅本人可创建/删除自己 uid 文档。
- `origami/{origamiId}`：所有人可读，前端禁写（仅 CF）。
- `challenges/{challengeId}`：所有人可读，前端禁写。

---

## 模块覆盖自查

| 模块 | 数据需求 | 覆盖集合 |
|------|----------|----------|
| P2 写作 | 故事、官方挑战、自由词、故事书/章节 | `stories`、`challenges`（自由词不入库）、`storybooks`（T6） |
| P3 社区 | 广场动态、点赞、评论、排行榜 | `stories` + `comments` + `likes`（含 hotScore） |
| P4 游戏化 | 折纸藏品、解锁状态、主题房间 | `origami` + `users.unlocks` |
| 模块 G | 角色查询缓存 | `charactersCache` |
| P1 账号 | 用户档案、统计 | `users` |
