# unlock-halls.plan.md — 词语绑定解锁 + 多展馆切换 落地计划

> **定位**：把"墨水 / 纸张 / 展馆三类奖励的获取细化"与"折纸多展馆展示 + 切换"落成可编译可演示的 Flutter 代码。
> 分支：`feat/unlock-halls`。提交遵循 `docs/git-format.md`。
> 上游事实来源不变：设计 `docs/fronted-design.md`、数据模型 `docs/schema-design/design.md`、接口 `docs/single-TODO.md` §0.2。

---

## 0. 需求与现状

**需求（用户）**
1. 墨水 / 展馆 / 纸张三类奖励"获取细化"：**增加一个字段关联三个词语，在特定官方词语下发布任意文章即解锁**。
2. 所有折纸展品都在**默认展馆**展示；新增**切换展馆**功能。

**现状**
- 解锁现状是两套粗粒度 CF 维护字段：`users.unlocks.magicInk`（互动分 ≥5 自动解锁）+ `users.unlocks.rooms`（发首篇官方挑战故事 push `zen_garden`）。详见 `functions/src/userStats.ts` / `triggers.ts`。
- 皮肤：`PaperSkin.presets = [xuanDefault, kraft]`（**全部免费、无解锁概念**）；`InkSkin.presets = [pineSoot, vermilion, magicFlow(requiresUnlock)]`（仅魔法墨水靠 `magicInk` 旗标）。
- 展览厅：所有折纸在单一网格展示（已满足"默认展馆"语义），外加一个跳转 `禅意花园` 静态房间的入口卡 `RoomEntryCard`。**无主题展馆、无切换器**。
- 数据：`Story.words`（官方挑战三词快照，已发布故事携带）、`Origami.style`（zen/steampunk/ink，见 `functions/src/generateOrigami.ts` `STYLES`）均现成可用。

---

## 1. 关键决策

| 决策 | 选择 | 理由 |
|------|------|------|
| **解锁数据来源** | **纯客户端只读派生**：读 `StoryRepository.streamMyStories` 里**已发布**故事的 `words`，命中奖励的 `unlockWords` 即解锁 | CF 未部署（零成本），只读派生在 emulator/线上**当场可验**；`unlocks.*` 是规则 CF-only 字段，只读零越权 |
| **"增加一个字段关联三个词语"** | 在 `PaperSkin` / `InkSkin` / `GalleryHall` 上加 `unlockWords: List<String>?`（null = 免费/默认） | 奖励本体是客户端概念，绑定字段就近放在奖励定义上；用统一的奖励目录 `reward_catalog.dart` 兜底说明 |
| **与旧机制关系** | 新词语解锁为主，**OR 旧旗标**：魔法墨水另认 `unlocks.magicInk`，禅意展馆另认 `unlocks.rooms ∋ zen_garden` | 向后兼容，旧 CF 链路 / 种子数据不失效，不改 schema/CF/规则 |
| **展馆过滤** | 默认展馆 `全部` 显示所有折纸；主题展馆按 `Origami.style` 过滤（zen/steampunk/ink） | `style` 现成；非白名单 style（如 autumn）仍在默认展馆可见，不丢件 |
| **词集匹配** | 归一化（trim+小写+排序），奖励三词**全部包含于**某条已发布故事的 `words` 即算命中 | 顺序无关、健壮；3 词集等价于集合相等 |
| **不动范围** | 不改 `firestore.rules` / `firestore.indexes.json` / `functions/**` / `schema-design/design.md` | 本期是纯前端增强 |

### 词表（单一事实来源；种子/官方挑战应使用这些词以便演示解锁）

| 奖励 | 类型 | id | `unlockWords` | 旧旗标 OR |
|------|------|----|---------------|-----------|
| 禅意阁 | hall | `zen` | 松 / 月 / 石 | `rooms ∋ zen_garden` |
| 机关坊 | hall | `steampunk` | 齿轮 / 黄铜 / 蒸汽 | — |
| 水墨轩 | hall | `ink` | 月 / 云生 / 海楼 | — | ← 绑定挑战 `v0mZD0nPjPcTQ7TqU6PV`「月下飞天镜•云生结海楼」
| 牛皮纸 | paper | `kraft` | 秋 / 霜 / 信笺 | — |
| 雪浪笺 | paper | `snow`（新增） | 雪 / 梅 / 夜 | — |
| 朱砂 | ink | `vermilion` | 火 / 朱 / 印 | — |
| 魔法墨水 | ink | `magic_flow` | 星 / 梦 / 流光 | `magicInk == true` |

> 默认免费、永不锁：纸 `xuan_default`、墨 `pine_soot`、展馆 `all`。

---

## 2. 产出与改动

**新增**
```
app-storage/lib/data/
├── unlock_state.dart        # wordKey() 归一化 + UnlockResolver（命中判定）
app-storage/lib/widgets/
├── unlock_builder.dart      # UnlockBuilder：合并 streamMyStories + watchProfile → UnlockResolver
app-storage/lib/features/gallery/
├── hall.dart                # GalleryHall + galleryHalls 目录（含 style 过滤 + unlockWords）
└── widgets/hall_switcher.dart  # 顶部展馆切换 chips（锁态/选中态）
```

**改动**
- `theme/paper_skin.dart`：加 `unlockWords`；kraft 绑词 + 新增 snow。
- `theme/ink_skin.dart`：加 `unlockWords`；vermilion / magic_flow 绑词。
- `features/gallery/gallery_screen.dart`：包 `UnlockBuilder`；加展馆切换器 + 按所选展馆过滤网格；移除 `RoomEntryCard`（其入口由展馆 chip + 禅意展馆 banner 内"进入沉浸花园"按钮承接）。
- `features/me/me_screen.dart`：皮肤选择器锁态改读 `UnlockResolver`；解锁卡展示细粒度状态 + 锁定项所需三词提示。
- `features/gallery/widgets/room_entry_card.dart`：**删除**（角色被展馆切换器取代）。
- `zen_garden_screen.dart`：保留（沉浸花园路由不动）；解锁判定 OR 新词路径，避免与展馆 chip 解锁态打架。

**不动**：路由 `/gallery/room/zen-garden` 保留；CF / 规则 / schema / 索引零改动。

---

## 3. 分期与验收（收工 `flutter analyze` 0 issue）

### Phase 1 — 解锁内核（数据层）
- `unlock_state.dart`（`wordKey` + `UnlockResolver`）；`unlock_builder.dart`。
- 皮肤加 `unlockWords` + 新预置。
- **验收**：`analyze` 0 issue；`UnlockResolver.paperUnlocked/inkUnlocked` 可判定。

### Phase 2 — 多展馆
- `hall.dart` + `hall_switcher.dart`；改 `gallery_screen.dart`（切换器 + 过滤 + UnlockBuilder），删 `RoomEntryCard`。
- **验收**：默认展馆显示全部折纸；切到主题展馆按 style 过滤；锁定展馆显示锁态 + 三词提示，不展示内容；禅意展馆 banner 可进沉浸花园。

### Phase 3 — 我的页接线
- `me_screen.dart` 皮肤锁态读 `UnlockResolver`；解锁卡细化。
- **验收**：未解锁皮肤显锁 + 所需三词；发布命中三词的官方故事后，对应皮肤/展馆即时解锁（重进页面刷新）。

> 一次提交：`feat(gallery): 词语绑定解锁与多展馆切换`（如分期可拆三 commit）。

---

## 3.5 落地状态（as-built）

> 三期一并落地，`flutter analyze` **No issues found**（本机 Linux 可跑 analyze；Windows 真机演示属用户步骤）。

| 期 | 状态 | 产出 |
|----|------|------|
| P1 解锁内核 | ✅ | `data/unlock_state.dart`（`wordKey` + `UnlockResolver.paperUnlocked/inkUnlocked`）、`widgets/unlock_builder.dart`；`paper_skin`/`ink_skin` 加 `unlockWords` + 新预置 `snow` |
| P2 多展馆 | ✅ | `gallery/hall.dart` + `widgets/hall_switcher.dart`；`gallery_screen.dart` 改造（切换器 + 按 style 过滤 + UnlockBuilder + 禅意 banner）；删 `room_entry_card.dart`；`zen_garden_screen` 解锁判定改走 hall |
| P3 我的页 | ✅ | `me_screen.dart`：皮肤锁态读 `UnlockResolver` + `_UnlockGuideCard` 列全部锁定项与所需三词 |

**实测要点**：解锁靠只读用户「已发布」故事的 `words`，故验证时需先以 §1 词表里的三词发布一条官方故事（`publishedToSquare=true`），重进展览厅/我的页即见对应纸/墨/馆解锁。

## 4. 留作后续 / 已知约束
- `unlockWords` 必须与真实官方挑战 `words` 一致才能在演示中解锁——种子脚本（T1.10b）应采用 §1 词表。
- 解锁为只读派生，不写 `unlocks.*`；魔法墨水/禅意仍可由旧 CF 旗标解锁（OR）。
- 持久化、跨端同步、解锁动效（金箔展开 §9）不在本期。
