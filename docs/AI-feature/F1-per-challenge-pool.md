# F1 — Per-Challenge 自定义图池

> **目标**：每个官方挑战可以独立指定它发放的折纸图源在 Storage 哪个目录、贴什么 style 标签；不指定就回落到现行 `origami/pool/{style}/` + 哈希逻辑。
> **状态**：T1.8a 升级版（非 break，旧 challenge 文档无字段时行为不变）

---

## Schema 变更（`challenges/{id}`）

新增两个**可选字段**：

| 字段 | 类型 | 含义 |
|------|------|------|
| `imagePool` | string | Storage 中本挑战折纸图源前缀，如 `origami/challenges/qiu-shuang` |
| `style` | string | 写入 `origami.style` 的标签（决定 T4.1 卡片 chip 文案） |

**完全可选**。任一字段缺失就走旧行为：哈希 challengeId → 落到 `zen/steampunk/ink` 三选一 → `origami/pool/{style}/` 选图。

> 同步 `docs/schema-design/design.md §2` 已加这两条字段说明。

---

## CF 行为变化（`functions/src/generateOrigami.ts`）

**选 style 优先级链**：

```
调用方传入 requestedStyle  ──►  直接用
       ↓ 没传
challenges/{id}.style       ──►  用 challenge 自定义（可超出 zen/steampunk/ink）
       ↓ 没设
pickStyleByHash(challengeId) ──► zen / steampunk / ink 三选一（旧逻辑）
```

**选图池优先级链**：

```
challenges/{id}.imagePool   ──►  用 challenge 自定义路径
       ↓ 没设
origami/pool/{style}        ──►  旧逻辑
```

**关键代码片段**：

```typescript
const challengeSnap = await db.collection("challenges").doc(challengeId).get();
const challengeData = challengeSnap.data();
const challengeStyle = challengeData?.style as string | undefined;
const customPool = challengeData?.imagePool as string | undefined;

const style = requestedStyle ?? challengeStyle ?? pickStyleByHash(challengeId);
const poolPath = customPool ?? `origami/pool/${style}`;

const imageUrl = await pickFromFolder(poolPath);
```

`pickFromPool(style)` 被泛化成 `pickFromFolder(prefix)`——接受任意 Storage prefix，扩展名白名单不变（png/jpg/jpeg/webp）。

**Replicate prompt 兼容自定义 style**：

```typescript
const prompt = defaultPrompts[style as DefaultStyle]
  ?? `single origami paper craft, ${style} theme, paper texture, ..., no text`;
```

不在 zen/steampunk/ink 白名单的 style（如 `autumn` / `winter`）走通用 prompt 模板。

---

## 客户端兼容

T4.1 的 `OrigamiCard._StyleChip._labels` 只映射 `zen/steampunk/ink → 禅/蒸汽/水墨`：

```dart
final label = _labels[style] ?? style;
```

自定义 style 走 fallback，直接显示原字符串（如「autumn」）。需要中文标签时在 `_labels` 字典里加映射即可。

---

## 运营 SOP（你的工作流）

每发布一个新官方挑战：

### 步骤 1：准备图

按 `T1.8-manual-ops.md §A.1` 的规格，给本挑战准备 3–6 张主题图（PNG/JPG，≤2MB，正方形）。可走 Replicate / Bing / Midjourney 任一工具生成。

### 步骤 2：上传到 Storage

Firebase Console → Storage → 进入默认 bucket：

```
origami/
└── challenges/
    └── <挑战标识>/        ← 自起一个简短英文目录名
        ├── 01.png
        ├── 02.png
        └── ...
```

例：`origami/challenges/qiu-shuang/`、`origami/challenges/jiang-xue/`。

> **不要**把图传到 `origami/pool/{style}/`（那是 fallback 默认池）。F1 自定义图池要单独目录。

### 步骤 3：建/改 challenge 文档

Firestore Console → `challenges/{id}` → 加两个字段：

```
imagePool: "origami/challenges/qiu-shuang"      (string)
style:     "autumn"                             (string, 任意标签)
```

### 步骤 4：客户端零改动

T4.2 完整流程不变：用户发 official story → fire-and-forget 调 `generateOrigami` → CF 自动读 challenge 文档 → 选你的图池 → 发放藏品。

---

## 验收清单

> 前提：CF 重新部署（F1 的 generateOrigami 代码改了）。

- [ ] **旧 challenge 不动**：`demo-challenge-001` 没 `imagePool`/`style` 字段时，仍走 `pickStyleByHash → steampunk → origami/pool/steampunk/`，行为与改之前完全一致（幂等命中老折纸记录）
- [ ] **新 challenge 自定义池**：
  - Storage 传 3 张图到 `origami/challenges/test-001/`
  - Firestore 新建 `challenges/test-002` 文档，含 `imagePool='origami/challenges/test-001'`, `style='autumn'`, `isActive=true`...
  - 在 app 里发一篇 mode='official', challengeId='test-002' 的 story → CF 应从 `origami/challenges/test-001/` 选图
  - 检查新写的 `origami/{id}.style == 'autumn'`, `imageUrl` 指向 `origami/challenges/test-001/...`
  - 画廊卡片 chip 显示 「autumn」（fallback）
- [ ] **空池报错**：`imagePool` 指向不存在 / 空目录 → `failed-precondition: 素材池 .../ 为空`，前端 SnackBar 「折纸生成失败」

---

## 设计取舍

- **新字段全部可选**：F1 是非破坏式升级，老数据零改动。这是 CLAUDE.md §2「数据模型权威」原则的现实体现。
- **style 不再强类型 enum**：TS 端把 `Style` 改成 `DefaultStyle`，默认池仍用 enum；调用链上 style 字段是 `string` 类型，允许任意值。换来的自由度让你后续加 `winter` / `autumn` / `huaxiang` 等主题不用动代码。
- **图池路径不限定前缀**：CF 不强制 `imagePool` 必须以 `origami/` 开头；但 storage.rules 的 read:true 只覆盖 `origami/**`，所以实际使用时必须放在 `origami/` 子目录下。文档明确给出 SOP 推荐位置 `origami/challenges/`。
- **客户端零改动**：所有变化在后端 + Console 运营动作完成。前端展览厅 / 编辑器代码完全不知道有「图池切换」这回事。
- **Prompt 通用模板**：自定义 style 用 `single origami paper craft, ${style} theme, ...` 模板套，避免老 style 改名后 prompt 字典找不到。

---

## 排错速查

| 症状 | 原因 |
|------|------|
| 新挑战发放的折纸还是旧池里的图 | challenges 文档 `imagePool` 字段没设，或拼写错 |
| 折纸 chip 显示英文不显示中文 | `OrigamiCard._StyleChip._labels` 没加你新 style 的中文映射；加一行即可 |
| `failed-precondition: 素材池 origami/.../ 为空` | `imagePool` 指的目录没图，或路径写错。Console Storage 浏览那个路径确认 |
| Replicate live=true 路径出图，但风格不对 | 自定义 style 走通用 prompt 模板，效果不如三个预置 style。要好效果只在 zen/steampunk/ink 范围内写挑战 |
