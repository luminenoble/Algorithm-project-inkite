# T6 故事书 & 章节 — 全量开发记录

> 设计事实来源：`docs/next-design-detailed.md`。本文件记交付物 / 人工操作 / 验收 / 偏差。
> 分支：`feat/storybook-chapters`。

---

## 1. 交付物清单

### 1.1 数据访问层（T6.1）

| 文件 | 动作 | 说明 |
|------|------|------|
| `app-storage/lib/data/models/storybook.dart` | 新增 | `Storybook` 模型 + `StorybookSort` 枚举 + 常量 `kDefaultChapter`（未分章）/ `kDefaultStorybookTitle`（未分类）/ `defaultStorybookId(uid)`=`default_{uid}` |
| `app-storage/lib/data/repositories/storybook_repository.dart` | 新增 | 单例。`streamMine` / `getById` / `watchById` / `getOrCreateDefault`（幂等）/ `create` / `rename`（默认书禁）/ `setPinned` / `setCoverAsset` / `setChapterOrder` / `touch` / `delete`（删非空书迁移其下 story 回默认书，WriteBatch） |
| `app-storage/lib/data/models/story.dart` | 改 | 加 `storybookId` / `chapterName`（均非空）；`fromFirestore` 防御默认（缺字段→`''` / `未分章`）；`toCreateMap` 必带两字段 |
| `app-storage/lib/data/repositories/story_repository.dart` | 改 | `update` 扩 `storybookId` / `chapterName`（移动用）；新增 `streamByStorybook`（按 storybookId 拉全书，客户端按章节分组） |

### 1.2 后端封面上传（T6.0）

| 文件 | 动作 | 说明 |
|------|------|------|
| `functions/src/storageUrl.ts` | 新增 | 抽出共享 `firebaseDownloadUrl`（折纸 + 封面复用，§2.1「勿重复实现」） |
| `functions/src/generateOrigami.ts` | 改 | 改用共享 `firebaseDownloadUrl`，删本地副本 |
| `functions/src/uploadStorybookCover.ts` | 新增 | `onCall`：鉴权（含 emulator `__testUid`）+ 归属校验 + ≤1MB + 写 `storybook-covers/{uid}/{id}.png` + 回写 `coverUrl`/清 `coverAssetId`/`updatedAt` + 返回 `coverUrl` |
| `functions/src/index.ts` | 改 | 导出 `uploadStorybookCover` |

### 1.3 客户端 CF 调用层（T6.0 前端侧）

| 文件 | 动作 | 说明 |
|------|------|------|
| `app-storage/lib/services/functions_client.dart` | 新增 | 通用 HTTPS 直调 `FunctionsClient`（从 `OrigamiService` 抽出）+ `CallableException`。**不用 `cloud_functions` 包**（Windows 无原生 handler，`CLAUDE.md` §7） |
| `app-storage/lib/services/origami_service.dart` | 改 | 委托 `FunctionsClient`；`export ... show CallableException` 保旧 import 兼容（`ai_origami_card.dart` 不动） |
| `app-storage/lib/services/storybook_service.dart` | 新增 | `uploadCover(id, bytes)`：客户端先校验 ≤1MB → base64 → 调 `uploadStorybookCover` |

### 1.4 前端两屏 + 交互（T6.2 / T6.3 / T6.4）

| 文件 | 动作 | 说明 |
|------|------|------|
| `app-storage/lib/features/writing/storybook_covers.dart` | 新增 | 内置预设封面（**按皮肤令牌程序化绘制**，零图片 asset）+ `StorybookCover`（coverUrl 优先 `Image.network`，否则回落预设） |
| `app-storage/lib/features/writing/storybooks_overview_screen.dart` | 新增 | 总览屏：流式网格、创建/修改时间排序、pin 角标、建/改名/删/换封面右键菜单、新建卡、空态、索引报错友好提示 |
| `app-storage/lib/features/writing/storybook_detail_screen.dart` | 新增 | 内部屏：章节折纸箱聚合（盒盖开合 + `durFold` 高度展开）、纸鸟故事 + 草稿/已发布徽记、新建章节、写故事入章、空章节显示 |
| `app-storage/lib/features/writing/widgets/cover_picker.dart` | 新增 | 换封面 sheet：预设网格（即时）+ 自定义上传（`file_selector` → CF） |
| `app-storage/lib/features/writing/widgets/move_story_sheet.dart` | 新增 | 移动故事：选目标书 + 章节 → `update` + 两端 `touch` |
| `app-storage/lib/features/writing/story_editor_screen.dart` | 改 | 新建 story 落默认书/章节（`getOrCreateDefault`）；接 extra `storybookId`/`chapterName`/`fromStorybook`；保存后 `touch`；返回去向按来源决定 |
| `app-storage/lib/features/writing/writing_screen.dart` | 改 | 「我的故事」入口 → `/writing/storybooks` |
| `app-storage/lib/routing/app_router.dart` | 改 | 加 `/writing/storybooks` + `/writing/storybooks/:storybookId`（前进向翻书折叠） |
| `app-storage/pubspec.yaml` | 改 | 加 `file_selector: ^1.0.3`（见 §4 偏差） |

> 旧 `/writing/mine`（`my_stories_screen.dart`）路由保留为兼容入口，不再是主入口。

### 1.5 迁移 / 规则 / 索引 / schema（T6.5 / T6.6）

| 文件 | 动作 | 说明 |
|------|------|------|
| `functions/scripts/migrate_storybooks.mjs` | 新增 | 一次性迁移：为存量用户建 `default_{uid}` 书、回填存量 story 的两字段。幂等，支持 `--dry-run` / `--proxy` / `--creds` |
| `firestore.rules` | 改 | `storybooks` 块（owner 读写、`coverUrl` CF-only、默认书禁改名/删）；`stories` 写校验 `storybookId` 归属 + `chapterName` string |
| `storage.rules` | 改 | `storybook-covers/**`：前端禁写、`read:true` |
| `firestore.indexes.json` | 改 | +3 索引（2× storybooks 总览、1× stories 按章节聚合） |
| `docs/schema-design/design.md` | 改 | 四处同步：集合总览、stories 两字段、新增 §8 storybooks、索引、安全规则要点、模块覆盖 |

---

## 2. 人工操作（演示前按序执行）

零成本策略下 CF / 规则 / 索引平时不部署，演示前一次性做：

1. **部署索引**（总览/章节查询依赖复合索引，否则前端报「需要索引」）：
   ```
   firebase deploy --only firestore:indexes
   ```
   建索引需几分钟生效；若仍报错，按 `docs/GUIDE/挑战发布.md` 末尾刷新法排查。
2. **部署规则**：
   ```
   firebase deploy --only firestore:rules,storage
   ```
3. **部署 Functions**（含新 `uploadStorybookCover`）：
   ```
   cd functions && npm run build && firebase deploy --only functions
   ```
4. **跑迁移脚本**（把存量 story 补默认书/章节，否则历史故事 `storybookId=''`）：
   ```
   cd functions
   node scripts/migrate_storybooks.mjs --dry-run     # 先看报告
   node scripts/migrate_storybooks.mjs               # 实跑（幂等，可重复）
   # 国内网络挂代理：--proxy http://127.0.0.1:7890
   ```

> 仅用内置预设封面、不传自定义封面时，**T6.0 CF 可缓部署**（设计 §7 缓冲顺序），
> 其余功能（总览 / 章节 / 默认书 / 移动 / 预设封面）不依赖 CF。

---

## 3. 验收对照

### 3.1 数据层（§3.3）
- [x] `Storybook` fromDoc/toCreateMap camelCase 正确
- [x] `getOrCreateDefault` 幂等（确定性 ID `default_{uid}`，`set` 写）
- [x] `streamMine` 置顶优先 + 两种排序（依赖 §1.4 索引）
- [x] `streamByStorybook` 拉全书，客户端按 `chapterName` 分组
- [x] `Story` 加两字段后既有写作流仍能 create（默认书惰性补齐）
- [x] 删非空书：其下 story 迁回默认书未被误删；默认书删除 Repository 抛错 + 规则拒

### 3.2 封面 CF（§2.2）— 待 emulator 实测
- [ ] Emulator：建本人书 → 传 base64 → Storage 落图 + `coverUrl` 回写 + 返回 URL
- [ ] 归属校验：他人书 ID 被拒（`permission-denied`）
- [ ] 大小校验：超 1MB 被拒（`invalid-argument`）
- [x] `npm run build` 无 TS 报错；`index.ts` 正确导出；仓库无上传凭证明文

### 3.3 安全规则（§4）— 待 emulator 实测
- [ ] 读他人故事书被拒
- [ ] 前端 update `coverUrl` 被拒；改默认书 `title` 被拒；删默认书被拒
- [ ] story 写入指向他人故事书的 `storybookId` 被拒

### 3.4 前端两屏（§5.1 / §5.2）— 代码完成，待 Windows 实跑
- [x] 总览：流式网格、两种排序 + pin、建/改名/删/换封面闭环、默认书隐藏改名删除
- [x] 内部屏：章节聚合、折纸箱展开/折叠、新建章节、跨章/跨书移动、草稿/已发布徽记、空章节显示
- [x] 换封面：选预设即时；上传走 CF；`coverUrl` 优先于 `coverAssetId`

### 3.5 迁移（§5.3）— 待对真实数据跑
- [x] 脚本幂等（重复跑不重复建默认书、不覆盖已有归属）
- [ ] 跑后所有旧 story 有合法 `storybookId`/`chapterName`，两屏正常渲染历史数据

---

## 4. 设计偏差与限制（实现期决策）

1. **CF 客户端走 `FunctionsClient`（HTTPS 直调），非 `cloud_functions` 包**。
   设计 §3.1 示例用 `FirebaseFunctions.instanceFor(...)`，但本项目刻意不引 `cloud_functions`
   （Windows 无原生 pigeon handler，`CLAUDE.md` §7）。与既有 `OrigamiService` 同款适配。
2. **新增依赖 `file_selector`**（Windows 经 `file_selector_windows` 支持）用于自定义封面选图。
   设计把「自定义封面上传」列为可牺牲项（§7 缓冲顺序）；此处选择全量实现，故引入该依赖。
   预设封面路径零依赖，始终可用。已 `flutter pub get` 通过。
3. **预设封面程序化绘制，无图片 asset**。项目无 `assets/` 图，预设封面按皮肤令牌
   （`paperBase`/`inkPrimary`/`goldLeaf` 等）程序化渲染折痕 + 折纸造型，随皮肤换装、不硬编码颜色。
4. **`coverUrl` 优先且 CF-only 的副作用**：已上传自定义封面后再选内置预设，因前端不能写
   `coverUrl`（规则禁），预设不会立刻覆盖显示（仍按 `coverUrl`）。符合设计 §1.2「coverUrl 优先」。
5. **`storyCount` 不接 CF**（设计 §1.2 允许）：总览卡片故事数用一条 `streamMyStories` 客户端聚合。
6. **总览查询依赖复合索引**：与既有广场/排行同模式。索引未部署时两屏显友好提示并打印
   Firestore 报错原文（含一键建索引的 Console URL），不白屏。

---

## 5. 验证结果

| 检查 | 命令 | 结果 |
|------|------|------|
| Flutter 静态分析 | `flutter analyze`（app-storage） | ✅ No issues found |
| 依赖解析 | `flutter pub get` | ✅ file_selector(+windows) 解析通过 |
| Functions 编译 | `npm run build`（tsc，functions） | ✅ 无报错 |
| 索引 JSON | node 解析 | ✅ 9 索引，含 2 storybooks |
| Widget 烟测 | `flutter test` | ⚠ 环境问题：`flutter_tester` WebSocket 无法建立（沙箱 infra，非代码失败）。`analyze` 已覆盖全量编译 |

> 未做：emulator 规则/CF 实测、Windows release 实跑、迁移脚本对真实库执行——按
> 「所有验证放最后」要求先完成全部代码，上述需连 Firebase 的实测留待演示前人工执行（§2）。
