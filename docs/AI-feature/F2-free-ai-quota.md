# F2 — 自由 AI 折纸 + 周配额

> **目标**：用户主动点按钮就能用 Replicate Flux Schnell 实时生成专属折纸；周配额限制成本与使用频次；交互愈深 bonus 越多。
> **状态**：新增 Callable + 新增 stats / aiUsage 字段，**不破坏现有 generateOrigami / 官方挑战流**

---

## 用户视角

写作 Tab 落地页加一张「AI 折纸召唤」金箔描边卡片：

```
┌──────────────────────────────────────────────┐
│ ✨ AI 折纸召唤                  [ 1 / 4 ]      │
│                                              │
│ 用 Replicate Flux Schnell 实时生成一件专属折纸 │
│                                              │
│ [✓ 已获 20 赞 · +1 配额]  [🔒 官方挑战 2/5]    │
│                                              │
│ [✨ 召唤折纸]   剩余 3 次                      │
└──────────────────────────────────────────────┘
```

- 顶部右侧 `已用 / 上限` 实时显示
- 中间两个 chip 显示 bonus 状态：解锁的金箔色 + 勾、未解锁灰色 + 锁
- 「召唤」按钮调 CF，配额耗尽时置灰

---

## 配额规则

| 项 | 值 |
|----|----|
| 基础周配额 | **3 次** |
| Bonus A: `likesReceived ≥ 20` | **+1**，单向永久 |
| Bonus B: `officialChallengesCount ≥ 5` | **+1**，单向永久 |
| 最大周配额 | **5 次** |
| 窗口长度 | **7 天**（滚动，从用户本周首次调用时刻起算） |
| 失败退回 | Replicate 失败 → `aiUsage.count -= 1`，可重试 |

「单向永久」语义：阈值跨越后 bonus flag 永远 true，即使 likes/challenges 数字回落也不撤回。

---

## Schema 变更

### `users/{uid}.stats` 新增

| 字段 | 类型 | 说明 |
|------|------|------|
| `officialChallengesCount` | int | 已发布的官方挑战故事数，T1.8c 触发器维护 |

### `users/{uid}.aiUsage` 新建子结构

| 字段 | 类型 | 说明 |
|------|------|------|
| `weekStartAt` | timestamp \| null | 当前窗口起点；null = 从未调用 |
| `count` | int | 本窗口已用次数 |
| `bonusLikes` | bool | likes ≥ 20 解锁标记 |
| `bonusChallenges` | bool | challenges ≥ 5 解锁标记 |

**全部 CF-only**。客户端只读，T1.10a 收紧规则后字段级。

---

## CF 实现

### 新文件 `functions/src/aiQuota.ts`

```
BASE_WEEKLY_QUOTA = 3
BONUS_LIKES_THRESHOLD = 20
BONUS_CHALLENGES_THRESHOLD = 5
WEEK_MS = 7 * 24 * 3600 * 1000

consumeAiQuota(uid):
  事务里：
    1. 读 users/{uid}.aiUsage
    2. 若 weekStartAt 不存在或已过 7 天 → 重置 count=0, weekStartAt=now
    3. limit = base + (bonusLikes?1:0) + (bonusChallenges?1:0)
    4. if count >= limit → return { ok:false, snapshot }（不写库）
    5. count += 1，写回 → return { ok:true, snapshot }

refundAiQuota(uid):
  事务读 count → count -= 1（限 >0），写回。失败仅 log。
```

### 新文件 `functions/src/generateAiOrigami.ts`

```
onCall({ secrets: [REPLICATE_API_TOKEN] }):
  1. 取 uid（prod 走 request.auth；emulator 走 __testUid）
  2. consumeAiQuota(uid) → ok:false 抛 'resource-exhausted'
  3. 选 style：调用方传 → 用；否则 zen/steampunk/ink 随机
  4. tryReplicate(style)：**无 fallback**。失败 → refundAiQuota + 抛 'internal'
  5. 写 origami/{id} { source:'flux', sourceChallengeId:null, ... }
  6. 返回 { origamiId, imageUrl, style, source, quota: {used,limit,...} }
```

**关键差异 vs `generateOrigami`**：
| 项 | generateOrigami | generateAiOrigami |
|----|-----------------|-------------------|
| challengeId 入参 | 必填 | 无 |
| 防刷 | 查 official+published story | 配额 |
| 幂等 | (uid, challengeId) | 无（每次都是新折纸） |
| Replicate 失败 | 降级到池 | 退配额 + 报错 |
| 写库的 sourceChallengeId | challengeId | null |

### `functions/src/userStats.ts` 扩展

`applyUserDelta` 增 `officialDelta` 参数；事务里：

```
newOfficialCount = max(0, stats.officialChallengesCount + officialDelta)
update["stats.officialChallengesCount"] = newOfficialCount

if newLikesReceived >= 20 && !aiUsage.bonusLikes:
  update["aiUsage.bonusLikes"] = true

if newOfficialCount >= 5 && !aiUsage.bonusChallenges:
  update["aiUsage.bonusChallenges"] = true
```

### `functions/src/triggers.ts` 三处改动

| 触发器 | 改动 |
|--------|------|
| `onStoryCreated` | 若 official+published，多传 `officialDelta: 1` |
| `onStoryUpdated` | 草稿↔发布转换时按 `mode === 'official'` 计算 officialDelta |
| `onStoryDeleted` | 删 official-published story 时 `officialDelta: -1` |

### `functions/src/index.ts` 追加

```
export { generateAiOrigami } from "./generateAiOrigami";
```

---

## 客户端实现

### `data/models/user_profile.dart`

- `UserStats` 增字段 `officialChallengesCount`
- 新类 `UserAiUsage`（weekStartAt / count / bonusLikes / bonusChallenges）
- `UserProfile` 增 `aiUsage` 字段；`initialDoc` 加默认值

### `services/origami_service.dart`

- 新类 `AiOrigamiResult`（含配额快照）
- 新方法 `generateAiFree({ style? })` 包装 `generateAiOrigami` Callable

### `features/writing/widgets/ai_origami_card.dart`（新）

- `StatefulWidget`，内置 `_summoning` loading 态
- `StreamBuilder<UserProfile?>` 订阅 user 文档实时算配额
- 显示：标题 + `quota pill (used/limit)` + 描述 + bonus chips + 召唤按钮
- 按钮点击 → `OrigamiService.generateAiFree()` → SnackBar 反馈
- 配额耗尽时按钮置灰 + 倒计时文案「X 天后重置」

### `features/writing/writing_screen.dart`

- 在「自由创作」卡和「我的故事」卡之间插一个 `const AiOrigamiCard()`

---

## 验收清单

> 前提：CF 已重新部署（含 generateAiOrigami + 改过的 triggers + userStats）。

### 基础

- [ ] 全新账号打开写作 Tab → 看到 AI 折纸卡，显示 `0/3`，两个 bonus chip 都是锁定态
- [ ] 点「召唤折纸」→ ~3-5 秒后 SnackBar「AI 折纸已生成（zen/steampunk/ink） · 本周剩余 2/3」
- [ ] 展览厅刷新看到新折纸（`source: 'flux'`，`sourceChallengeId: null`）
- [ ] 卡上配额变为 `1/3`，按钮可继续

### 配额耗尽

- [ ] 连续点 3 次召唤 → 第 4 次按钮置灰，副文「本周配额已用完，X 天后重置」
- [ ] 直接调 CF（绕过 UI）也被拒：`resource-exhausted`

### Bonus A：likes > 20

- [ ] 用别的账号给目标账号的 story 点 21 次赞（多个 story 累计）→ 触发器把 `aiUsage.bonusLikes` 翻 true
- [ ] AI 卡上「点赞 20/20」chip 立即变金箔「已获 20 赞 · +1 配额」
- [ ] 配额 pill 由 3 变 4

### Bonus B：5 篇官方挑战

- [ ] 用同账号连续发 5 篇 mode=official + publishedToSquare story → `officialChallengesCount` 累计到 5
- [ ] AI 卡 chip 由「官方挑战 X/5」变「5 篇官方挑战 · +1 配额」
- [ ] 配额 pill 由 3 变 4（或 5 如果两个 bonus 都解锁）

### Replicate 失败降级（**不**回池）

- [ ] 临时把 secret 改错（`firebase functions:secrets:set REPLICATE_API_TOKEN` 输入无效）→ 调召唤 → SnackBar「AI 生成失败，配额已退回」
- [ ] CF 日志看到 `[aiQuota] refunded uid=...`
- [ ] 卡上 `count` 没增（配额已退回）

### 窗口重置

- [ ] 把 `users/{uid}.aiUsage.weekStartAt` 改成 8 天前的时间戳 → AI 卡显示 `0/limit`，按钮可用
- [ ] 调一次 → 实际 CF 内部判定 expired → 重置 count=1，weekStartAt=now

---

## 部署清单

```bash
cd /mnt/d/wsl-share/Algorithm/functions
npm run build  # 已验证可通过

cd ..
firebase deploy --only functions
```

CLI 自动 diff：
- `generateAiOrigami`（新建）
- `onStoryCreated` / `onStoryUpdated` / `onStoryDeleted`（更新，加 officialDelta）
- `onLikeCreated` / `onLikeDeleted`（更新，bonus flag 翻转逻辑）
- 其余 skip

Secret `REPLICATE_API_TOKEN` 已在 T1.8b 步骤设过，不必重设；CF 部署会自动绑给新 callable。

---

## 排错速查

| 症状 | 原因 |
|------|------|
| 召唤按钮一直 loading | 网络 / CF 冷启动；正常 3-5s 内出 SnackBar，超 30s 看 CF 日志 |
| `resource-exhausted` 但实际还没用过 | `aiUsage.count` 没归零；改为 0 或等 7 天 |
| Bonus chip 不解锁 | T1.8c 触发器没重新部署 / stats.likesReceived 没累计；Console 看 user 文档实际值 |
| AI 卡显示 quota 不对 | 客户端缓存：`flutter hot-restart`（R 键），或 Console 改 aiUsage 字段后 stream 会立刻更新 |
| Replicate 反复失败 | secret 过期 / Replicate 账号欠费；`firebase functions:secrets:get REPLICATE_API_TOKEN` 查版本 |
| 自由 AI 折纸混入官方挑战的画廊 | `OrigamiRepository.streamMine` 不区分 source；如要分组显示需要扩 UI（当前不做） |

---

## 设计取舍

- **拆出独立 callable** vs 在 generateOrigami 加 mode：拆分换来清晰度（防刷 vs 配额是不同逻辑）+ 独立部署（free AI 出问题不影响官方挑战发放）。
- **窗口走滚动 7 天而非自然周**：用户体验更直观——「上次召唤后 7 天」比「等到周一」更人性。代价是状态依赖每用户 `weekStartAt` 字段。
- **Bonus 单向永不撤回**：游戏化心理学——「拿到的奖励不能被取消」。即使 likes 被取消、official 故事被删，bonus 仍保留。
- **Replicate 失败不降级到池**：自由 AI 的产品定义就是「真 AI」。回池等于「AI 失败给你一张老图」，叙事崩。退配额让用户重试，比静默回池诚实。
- **客户端 `count` 显示用 stream 自动同步**：不在客户端本地存配额状态（避免 stale）。窗口过期的检测在客户端做一层 UX 优化（显示 0），CF 实际重置在下次调用时事务化进行。
- **bonus 阈值通过触发器在 stats 更新时检查**：而非 lazy 在 consumeAiQuota 时查 likesReceived/官方故事——避免在配额事务里多查 stories collection。把触发器变成「事实源」，配额事务只读 aiUsage 即可。

---

## 与原 magicInk 解锁的关系

- `unlocks.magicInk`（T1.8c 既有）仍由 `engagementScore >= 5` 触发，**仅作视觉装饰**（展览厅金箔横幅 + 藏品卡金边 + 编辑器 AppBar 徽章）。
- `aiUsage.bonus*`（F2 新增）是**真正的功能解锁**（多 1 次 AI 配额）。
- 两者独立、阈值不同，避免「一个旗子管两件事」的耦合。
- 演示叙事：magicInk = 「你写得多受欢迎了」的徽章；AI 配额 = 「你已经积累足够 reputation 可以多用 AI 工具」的实际权力。
