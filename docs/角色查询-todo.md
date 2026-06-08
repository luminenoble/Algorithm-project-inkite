# 角色查询（「开拓」栏）集成 TODO

> 本 TODO 供 Claude Code 在 `Algorithm` 仓库执行。开始前必读 `CLAUDE.md`、
> `docs/single-TODO.md`、`docs/schema-design/design.md`、`docs/GUIDE/fronted-design.md`。
> 本任务**复活**已于单人重排中砍除的模块 G（角色查询），但采用「方案 A：预爬 + 缓存查询」
> 的最小形态，不引入任何在线后端依赖。

---

## 0. 背景与方案定调

### 0.1 数据来源

数据来自既有姊妹项目 **ISR-scraper**（`D:\wsl-share\ISR-scraper`，私有仓
`github.com/luminenoble/ISR-hw4-scraper`）。该项目是一套完整的同人角色垂直搜索引擎
（Scrapy 抓取 + Elasticsearch 索引 + MongoDB + bge-m3 嵌入 + FastAPI 18 端点 + Vue3 前端），
已索引 **96,110 篇文档**，数据源 Fandom / Wikipedia / Reddit / 文档 / AO3。

### 0.2 方案 A 的核心约束（务必遵守）

- **不把 9.6 万篇全导进 Firestore**。只导「开拓」栏要展示的**角色卡片**（聚合后）。
- app 端**不依赖任何在线后端**（不连 ES / Mongo / FastAPI）。运行期只读 Firestore，
  与 `CLAUDE.md` §6 零成本策略一致。
- 数据导入是**一次性离线脚本**：本地起 ISR 后端 → 跑 `/search/cards` 聚合 → 灌进 Firestore
  `charactersCache` 集合 → 关掉。演示期只剩 Firestore。
- 体量预算：导 1,000~3,000 个角色卡，约 **3~9 MB**，**1,000~3,000 次写入**，
  远在 Firestore 免费层（20K writes/天、1 GB 存储）内，**零成本**。
- 写入耗时：用 `batchWrite`（每批 500）或 Admin SDK `bulkWriter`，**10~30 秒**量级。

### 0.3 与已冻结接口的关系

- 复用现有残留代码：`character_cache.dart`（模型）、`characters_cache_repository.dart`
  （只读 Repository）。两者 §0.3 砍除时**保留未删**，本任务把它们接回 UI。
- `firestore.rules` 中 `charactersCache` 段已是「客户端只读」（`allow read: if isSignedIn();
  allow write: if false;`），**无需改规则**，导入用 Admin SDK 绕过规则。
- 需**扩展** `charactersCache` schema 以承载 ISR 真实字段（见 §2），并同步更新
  `docs/schema-design/design.md` §7（schema 变更须经 P1，本任务即 P1 授权）。

---

## 1. 底部导航栏改造（加「开拓」Tab）

**文件**：`app-storage/lib/features/shell/main_shell.dart`、`app-storage/lib/routing/app_router.dart`

### 1.1 现状

底栏现在**硬编码 4 个 Tab**（`_tabs` 列表）：写作 `/writing`、广场 `/square`、
展览厅 `/gallery`、我的 `/me`。Tab 切换的翻书折叠方向由 `_onTap` 按索引差设定。

### 1.2 改动

在 `_tabs` 中**新增一项「开拓」**，路由 `/explore`，图标用 **`OrigamiGlyph.lens`**
（放大镜造型，`origami_icons.dart` 已有，语义贴合搜索）。

建议插入位置：广场之后、展览厅之前（即索引 2），让"创作→社区→探索→收藏→我的"语义递进；
也可放末尾。**注意**：插入位置会改变其余 Tab 的索引，`_onTap` 的折叠方向逻辑按索引差自动适配，
无需额外改，但需确认 5 个 Tab 在 62px 高度 `Row` 里均分后文字不挤（必要时字号 12→11）。

```dart
static const _tabs = <_TabSpec>[
  _TabSpec('/writing', '写作', OrigamiGlyph.pen),
  _TabSpec('/square', '广场', OrigamiGlyph.bird),
  _TabSpec('/explore', '开拓', OrigamiGlyph.lens),   // ← 新增
  _TabSpec('/gallery', '展览厅', OrigamiGlyph.box),
  _TabSpec('/me', '我的', OrigamiGlyph.seal),
];
```

### 1.3 路由

在 `app_router.dart` 的 `ShellRoute.routes` 中新增 `/explore` 顶级 Tab 路由，
其下挂一个详情子路由 `character/:key`（角色卡详情页）。沿用 `foldPage` + 子页
`FoldDirection.forward` 的既有约定：

```dart
GoRoute(
  path: '/explore',
  pageBuilder: (_, state) => foldPage(state, const ExploreScreen()),
  routes: [
    GoRoute(
      path: 'character/:key',
      pageBuilder: (_, state) => foldPage(
        state,
        CharacterDetailScreen(characterKey: state.pathParameters['key']!),
        direction: FoldDirection.forward,
      ),
    ),
  ],
),
```

### 1.4 视觉

动底栏/Tab 前必读 `docs/GUIDE/fronted-design.md`（设计事实来源）。「开拓」Tab 选中态沿用
朱砂高亮 + 微缩放点按反馈；`lens` 图标暂不加专属动效（广场纸鸟振翅是特例，保持克制）。

---

## 2. Firestore schema 扩展（`charactersCache`）

**文件**：`docs/schema-design/design.md` §7（同一 PR 更新）

现有 §7 只有 5 字段（`name / wikiSummary / wikiUrl / redditPosts / cachedAt`），
不足以承载 ISR 多源聚合 + 排序信号。**扩展为下表**（保持向后兼容，旧字段不动）：

| 字段 | 类型 | 必填 | 维护方 | 说明 |
|------|------|------|--------|------|
| `name` | string | 是 | 导入脚本 | 角色名（展示用，保留原大小写） |
| `wikiSummary` | string | 是 | 导入脚本 | 官方权威摘要（来自 Wikipedia/Fandom canon 文档的 snippet/body 截断） |
| `wikiUrl` | string | 是 | 导入脚本 | 官方条目链接（ISR `DocDetail.url`） |
| `redditPosts` | array&lt;object&gt; | 否 | 导入脚本 | 民间二创要点；每项 `{ title, url, snippet, source, tag }`，source∈{reddit,ao3} |
| `cachedAt` | timestamp | 是 | 导入脚本 | 导入时间 |
| `source` | string | 否 | 导入脚本 | 主条目来源（fandom/wikipedia） |
| `tag` | string | 否 | 导入脚本 | canon/fanon/meta/crossover（ISR `Hit.tag`） |
| `popularity` | number | 否 | 导入脚本 | ISR popularity（用于「开拓」栏热度排序，可选） |
| `obscurity` | number | 否 | 导入脚本 | ISR obscurity（冷门度，可做"发现冷门角色"入口，可选） |
| `searchTokens` | array&lt;string&gt; | 是 | 导入脚本 | 角色名 normalize 后的前缀/分词，供 app 端 `array-contains` 名称搜索 |

**`characterKey`（文档 ID）**：沿用 design.md §7 既有约定 —— normalized 名称
（小写、空格→下划线、去标点）。例：`"Hu Tao"` → `hu_tao`。与 ISR 的 `doc_id`（sha1(url)）
**不同**，因为 app 端要按角色名查询而非按文档查询。

**`searchTokens` 生成规则**（app 端无全文索引，靠它做前缀搜索）：
取角色名小写后，生成累进前缀（`["h","hu","hu ","hu t",...]` 取到合理长度上限，如 12），
外加完整 token 拆分。app 端用 `where('searchTokens', arrayContains: queryLower)` 匹配。
3,000 角色 × 平均 ~15 token，数组开销可控。

---

## 3. 离线导入脚本（ISR → Firestore）

**新建**：`functions/scripts/import_characters.mjs`（与 `seed_challenge.mjs` 同目录同风格）

### 3.1 前置（在 ISR-scraper 侧，由用户本地执行，非本仓）

1. `docker-compose up -d`（起 ES + Mongo + Tika）
2. `uvicorn api.main:app --port 8000`（起 FastAPI）
3. 确认 `/health` 与 `/search/cards?q=<角色名>` 正常返回。

### 3.2 角色清单从哪来

ISR 没有现成「角色列表」端点。两种取法，**推荐 (a)**：

- **(a) 用 ISR 侧导出脚本（已提供）**：在 ISR-scraper 仓执行
  `jobs/export_characters.py`（已写好），它直接查 ES `isr_pages` 按 `character_name`
  聚合，挑 canon 角色，输出 `[{name, url, source, tag, doc_count, popularity, is_genshin}, ...]`
  到 `functions/scripts/seed/characters_input.json`（默认路径即本仓 seed 目录）。
  **该脚本内置硬性条件：原神角色数必须 > 100，否则非零退出并提示补抓**，
  正好满足「开拓」栏以原神同人为主的定位。用法：
  `python jobs/export_characters.py --top 3000`（或 `--genshin-only` 只导原神）。
- **(b) 手工维护一份热门角色种子名单**（原神 + One Piece 主要角色，几百个），
  脚本对每个名字打 `/search/cards` 聚合。规模小、最稳，适合 demo。

### 3.3 脚本逻辑

对清单里每个角色名 `name`：

1. `GET http://localhost:8000/search/cards?q=<name>&size=8`，拿 `hits: HitCard[]`。
2. **聚合成一个 CharacterCache 文档**：
   - 主条目：从 hits 里挑 `source∈{wikipedia,fandom}` 且 `tag=canon` 的最高分项
     → `wikiSummary = snippet_plain`、`wikiUrl`（需补打 `/doc/{doc_id}` 拿 `url`）、`source`、`tag`。
   - `redditPosts`：取 hits 里 `source∈{reddit,ao3}` 的前 3~5 项 →
     `[{title, url, snippet, source, tag}]`（同样经 `/doc/{doc_id}` 补 url）。
   - `popularity`/`obscurity`：从主条目 `/doc/{doc_id}` 的 `DocDetail` 取。
   - `searchTokens`：按 §2 规则生成。
   - `characterKey`：normalize(name)。
3. 攒批：每 **500** 个文档一个 `batchWrite`，或用 Admin SDK `bulkWriter` 自动并发。
4. `cachedAt = FieldValue.serverTimestamp()`。
5. 打印进度 + 失败名单（某些名字 ISR 无命中要跳过并记录）。

### 3.4 凭证与安全

- 用 **Firebase Admin SDK**（service account），绕过安全规则写入。
- service account JSON **绝不入仓**（`CLAUDE.md` §3）：放 `functions/` 下并确认在 `.gitignore`，
  脚本经 `GOOGLE_APPLICATION_CREDENTIALS` 环境变量读取。
- 写的是线上 `inkite-demo` 项目；导入前先在 **Firestore Emulator** 跑通一遍（零成本验证）。

### 3.5 ISR 侧字段映射速查（`HitCard` / `DocDetail` → `CharacterCache`）

| CharacterCache 字段 | ISR 来源 |
|---|---|
| `name` | 清单输入 / `DocDetail.character_name` |
| `wikiSummary` | 主条目 `HitCard.snippet_plain`（或 `DocDetail.body` 截断 ~800 字符） |
| `wikiUrl` | 主条目 `DocDetail.url` |
| `redditPosts[].title/url/snippet/source/tag` | reddit/ao3 hits 的 `HitCard` + `/doc` 补 url |
| `source` / `tag` | 主条目 `HitCard.source` / `.tag` |
| `popularity` / `obscurity` | 主条目 `DocDetail.popularity` / `.obscurity` |

---

## 4. 数据访问层（复用 + 扩展）

**文件**：`app-storage/lib/data/models/character_cache.dart`、
`app-storage/lib/data/repositories/characters_cache_repository.dart`

### 4.1 模型扩展

`CharacterCache.fromFirestore` 现解析 5 字段，**补解析** `source / tag / popularity /
obscurity / searchTokens`（全部可空，缺省给安全默认）。不改已有字段名（接口冻结）。

### 4.2 Repository 新增查询方法

现有 `getByKey` / `watchByKey` 保留。**新增**：

```dart
/// 按角色名前缀搜索（app 端无全文索引，靠 searchTokens 数组匹配）。
Future<List<CharacterCache>> searchByName(String query, {int limit = 20}) {
  final q = query.trim().toLowerCase();
  return _col
      .where('searchTokens', arrayContains: q)
      .limit(limit)
      .get()
      .then((s) => s.docs.map(CharacterCache.fromFirestore).toList());
}

/// 「开拓」落地页默认列表：按 popularity 降序取热门角色。
Future<List<CharacterCache>> listPopular({int limit = 30}) { ... }
```

**复合索引**：`searchByName` 用单字段 `array-contains` 不需复合索引；`listPopular`
按 `popularity DESC` 单字段排序也不需要。若后续加 `tag` 过滤 + 排序，再在
`firestore.indexes.json` 补声明并 T1.10a 部署。

---

## 5. 前端页面

**新建**：`app-storage/lib/features/explore/explore_screen.dart`、
`character_detail_screen.dart`（沿用 `features/<模块>/` 目录约定；
原 `features/character/character_screen.dart` 占位屏可删或改造复用）

### 5.1 `ExploreScreen`（落地 + 搜索）

- 顶部搜索框（纸面风格，参考 fronted-design.md）。输入即调
  `CharactersCacheRepository.searchByName`，结果列表化展示卡片
  （角色名 + source/tag 徽标 + wikiSummary 首行截断）。
- 空查询时展示 `listPopular` 的默认热门角色网格/列表。
- 点卡片 → `context.go('/explore/character/$key')`。
- 处理三态：加载中（折纸 loading）、空结果（`OrigamiGlyph.emptyPaper` 文案）、有结果。

### 5.2 `CharacterDetailScreen`

- 顶部角色名 + source/tag 徽标 + 「冷门度」可选小标（obscurity）。
- 「官方权威」区块：`wikiSummary` + `wikiUrl` 外链（Windows 端用 `url_launcher`）。
- 「民间二创」区块：`redditPosts` 列表，每条 title + snippet + 外链 + source 徽标
  （reddit / ao3 区分配色）。
- 复用 `watchByKey` 拿实时文档（虽是只读，stream 保持与其他详情页一致风格）。

### 5.3 视觉一致性

必读 `docs/GUIDE/fronted-design.md`。source/tag 徽标配色：canon=朱砂、fanon=墨蓝、
meta/crossover=灰，与项目"官方权威↔民间二创"光谱叙事呼应（ISR design.md 同款语义）。

---

## 6. 文档与提交

### 6.1 同步更新的文档

- `docs/schema-design/design.md` §7：按 §2 扩展 `charactersCache` 字段表。
- `docs/single-TODO.md`：在 §0.3 旁注「模块 G 以方案 A 形态复活为『开拓』栏，见
  `docs/角色查询-todo.md`」；日程表加一行 R 任务。
- `CLAUDE.md`：项目概要「角色查询…已砍除」一行改为「已以『开拓』栏（方案 A）复活」，
  并在仓库目录树补 `features/explore/` 与 `functions/scripts/import_characters.mjs`。
- 路由表/Tab 说明（若有）同步 5-Tab。

### 6.2 提交规范（`docs/GUIDE/git-format.md`，强制）

Claude **不得自行 commit**，改完给出推荐 message 待用户审核。建议拆分：

- `feat(explore): 底栏新增开拓 Tab + 路由`
- `feat(explore): 角色卡数据层（模型/Repository 扩展 + searchByName）`
- `feat(explore): 开拓落地页与角色详情页`
- `feat(scripts): ISR→Firestore 角色卡导入脚本`
- `docs(schema): 扩展 charactersCache 字段表`

---

## 7. 验收清单

- [ ] 底栏显示 5 个 Tab，「开拓」用 lens 图标，选中态朱砂高亮，文字不挤；翻书折叠方向正确。
- [ ] `flutter run -d windows` 跑通，进入「开拓」无异常（即使 `charactersCache` 为空也优雅降级）。
- [ ] 导入脚本在 **Firestore Emulator** 跑通：N 个角色卡写入，字段映射正确，`searchTokens` 生成正确。
- [ ] app 端 `searchByName('hu')` 能召回「胡桃」等角色；`listPopular` 默认列表非空。
- [ ] 角色详情页正确渲染官方摘要 + 外链 + redditPosts，source/tag 徽标配色正确。
- [ ] `wikiUrl` / redditPosts 外链在 Windows 端可用 `url_launcher` 打开。
- [ ] **未改 `firestore.rules` 的只读约束**；client 端无任何对 `charactersCache` 的写操作。
- [ ] service account JSON 未入仓（`git status` 确认）。
- [ ] design.md §7 / single-TODO / CLAUDE.md 三处文档已同步。
- [ ] （高价值）对导入脚本字段映射做一次抽样人工核对：随机 5 个角色，比对 ISR `/search/cards`
      原始返回与 Firestore 落库文档一致。

---

## 8. 难度与工期评估（参考）

- **底栏 + 路由 + 数据层 + 两个页面**：机械活，约 1.5~2 天。
- **导入脚本 + 字段映射 + Emulator 验证**：脚本逻辑活，约 1 天（前置依赖用户在 ISR 侧
  起后端 + 导角色清单）。
- **总计约 3 天**（折合 1 个多 R）。风险低：全程不引入在线后端，与零成本/视频交付策略一致。
- **真正难点**不在 Flutter，而在 ISR 的 ES 排序信号无法整体搬进 Firestore —— 方案 A
  用 `searchTokens` 前缀匹配 + `popularity` 排序近似，牺牲 BM25/语义排序，但 demo 足够。
  若日后要恢复完整检索体验，再走「方案 B/C：托管 FastAPI」（本 TODO 不含）。
