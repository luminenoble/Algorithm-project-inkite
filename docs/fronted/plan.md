# fronted/plan.md — 折纸主题前端落地开发计划

> **定位**：把 `docs/fronted-design.md`（设计事实来源）落成可编译、可演示的 Flutter 代码的**行动计划**。
> 本文件只记「怎么落地、分几期、动哪些文件、每期验收」；视觉/交互/动效的事实来源仍是 `docs/fronted-design.md`，数据接口事实来源仍是 `docs/single-TODO.md` §0.2，数据模型事实来源仍是 `docs/schema-design/design.md`。
> 分支：`dev/fronted`。提交遵循 `docs/git-format.md`。

---

## 0. 现状与差距（动工前判断）

**现状**：P2/P3/P4 功能层 + AI 折纸已完成并可跑（`flutter analyze` 0 issue）。但**折纸主题视觉/动效尚未落地**：

- `main.dart` 用 Material 默认 `ColorScheme.fromSeed(indigo)`，**不是**设计的「宣纸·松烟墨」。
- 设计令牌（§1.1 的 `paperBase`/`inkPrimary`/`accentVermilion`…）以**字面量 `Color(0xFF…)` 散落在每个页面**——正是设计 §8.4 明令禁止的写法。
- 路由用默认 `builder`，**无翻书折叠转场**（§3）。
- `main_shell.dart` 用 Material `NavigationBar` + Material 图标，**非折纸底栏**（§3.2 / §11）。
- 无折纸图标、无毛笔加载、无骨架纸卡（§2），无纸鸟/合拢/摊开动效（§4/§6），无皮肤系统（§8）。

**结论**：本期工作 = **横切的「主题 + 令牌 + 转场 + 动效 + 皮肤」基础层**，外加把现有各页从「硬编码色值」改为「读皮肤令牌」。功能逻辑与 Repository 调用**一律不动**（§11：数据只走既有 Repository）。

---

## 1. 关键决策（落地约束）

| 决策 | 选择 | 理由 |
|------|------|------|
| **依赖** | **零新增依赖** | 不动 `pubspec` 第三方包，规避 Windows 原生插件兼容风险（`CLAUDE.md` §7 / dependencies 附录） |
| **Lottie（§2）** | **用 `CustomPainter` 折纸图标替代**，留 Lottie 接入 seam | 仓库无 `.json` 资源；设计 §2.1/2.3 本就要求「Lottie 缺失→退静态图标」恒在兜底。CustomPainter 既给折纸造型又能做 idle/振翅动效，且永不破坏构建 |
| **皮肤持久化（§8.2）** | **内存态**（`SkinController` 单例），留持久化 seam | 设计 §8.2 明确「本版不必入 Firestore，跨端同步后续再说」；演示视频单次会话内选皮肤即可，避免引入 `shared_preferences` 原生插件 |
| **验证门槛** | `flutter analyze` 0 issue（每期收工跑） | 本机为 WSL/Linux，无法 `flutter run -d windows`；Windows 真机演示由用户按 `dependencies.md` 附录在 Windows 录制 |
| **骨架复用（设计 §0.5）** | 4 Tab / `ShellRoute` / 路由结构 / Repository 接口**不变** | 新增 `theme/`、`widgets/` 两层 + 转场层；各页只「接令牌 + 挂动效」 |

---

## 2. 目录新增（本期产出）

```
app-storage/lib/
├── theme/                         # ★ 设计令牌 + 皮肤 + 主题 + 动效级别（§1/§7/§8）
│   ├── design_tokens.dart         # 默认皮肤的原始常量（唯一字面量出处）
│   ├── paper_skin.dart            # PaperSkin 数据类（§8.1）
│   ├── ink_skin.dart              # InkSkin 数据类（§8.1）
│   ├── app_skin.dart              # AppSkin = paper+ink + 预置皮肤（xuanDefault / pineSoot / magicFlow 锁定）
│   ├── motion.dart                # 时长/缓动令牌（§1.4）+ MotionLevel（full/reduced/off，§7）
│   ├── skin_controller.dart       # ChangeNotifier(skin+motion) + SkinScope(InheritedNotifier) + BuildContext 扩展
│   └── app_theme.dart             # AppSkin → ThemeData（替换 indigo 默认）
├── widgets/                       # ★ 折纸图标 + 加载/骨架 + 飞行物（§2/§4/§6）
│   ├── origami_icons.dart         # CustomPainter：bird/box/pen/lens/heart/emptyPaper/lockGold/seal
│   ├── origami_icon.dart          # OrigamiIcon 语义 widget（枚举+尺寸+色+可选动画；Lottie seam）
│   ├── brush_loading.dart         # 毛笔运笔加载（替代 CircularProgressIndicator）+ 8s「正在铺纸…」
│   ├── paper_skeleton.dart        # 骨架纸卡（呼吸透明度，列表首屏）
│   └── paper_bird_overlay.dart    # Overlay 纸鸟飞行（贝塞尔弧线 + IgnorePointer），§4/§6.2 复用
└── routing/
    └── fold_transition.dart       # FoldDirection + foldPage<T>()（Matrix4 透视 + rotateY + 折痕受光；降级 Fade）
```

改动既有文件：`main.dart`、`routing/app_router.dart`、`features/shell/main_shell.dart`，以及各页/widget 的「去硬编码色值」。

---

## 3. 分期与验收（每期一提交，收工跑 `flutter analyze`）

### Phase 1 — 设计令牌 + 皮肤 + 动效级别（§1 / §7 / §8）
- 建 `theme/` 全套；`main.dart` 包 `SkinScope`，用 `AnimatedBuilder` 监听 `SkinController` 重建 `MaterialApp.router(theme: appTheme(skin))`。
- 预置 `xuan_default`（纸）+ `pine_soot`（墨）跑通；`magic_flow`（魔法墨水）置 `requiresUnlock`。
- **验收**：全局 Scaffold 背景变宣纸暖白；`context.skin.inkPrimary` 等可取；`flutter analyze` 0 issue。
- 提交：`feat(theme): 折纸设计令牌 + 皮肤系统 + 动效级别`

### Phase 2 — 折纸图标 + 毛笔加载 + 骨架纸卡（§2）
- `OrigamiIcon`（折纸造型，CustomPainter）；`BrushLoading`；`PaperSkeleton`。
- **验收**：可在任意页放 `OrigamiIcon(OrigamiGlyph.bird)`；`BrushLoading` 替代转圈不报错；Lottie 缺失走静态恒成立。
- 提交：`feat(ui): 折纸图标 + 毛笔加载 + 骨架纸卡组件`

### Phase 3 — 翻书折叠转场 + 折纸底栏（§3 / §11）
- `fold_transition.dart`：`foldPage`（前进/后退、Tab 左右翻、`reduced/off`→Fade）。
- `app_router.dart`：各路由换 `pageBuilder`。
- `main_shell.dart`：折纸底栏（纸面色 + `OrigamiIcon` + 选中微缩放 + `accentVermilion`），进 `/gallery` 放鸟特例钩子。
- **验收**：Tab/子页切换出现翻书折叠；底栏为折纸造型；快速连切不堆叠（打断）。
- 提交：`feat(routing): 翻书折叠转场 + 折纸底栏`

### Phase 4 — 各页接令牌，去硬编码色值（§1 / §8.4 / §11）
- `writing` / `square` / `gallery` / `me` / `story_detail` / `login` + 各 `widgets/`：`Color(0xFF…)` → `context.skin.*`；加载态→`BrushLoading`；空态→`OrigamiIcon(emptyPaper)`。
- **验收**：全仓搜 `0xFF` 仅剩 `theme/design_tokens.dart`（与必要的图片占位）；换皮肤时各页即时换装。
- 提交：`refactor(ui): 各页接入皮肤令牌，去除硬编码色值`

### Phase 5 — 关键页面动效（§4 / §6）
- 进展览厅纸鸟飞过（首次/>30s，§4）+ 画廊网格错峰淡入。
- 编辑器保存合拢（§6.1）+ 发布纸鸟飞出（§6.2，含降级）。
- **验收**：进画廊放鸟、30s 内不重放；保存有合拢+印记；发布有飞鸟；`reduced/off` 退淡入/提示。
- 提交：`feat(ui): 进展览厅纸鸟 + 保存合拢/发布飞鸟动效`

### Phase 6 — 「我的」页皮肤切换 + 动效级别设置（§8.2 / §7）
- 纸张/墨水皮肤横向缩略图选择器 + 动效级别分段控件；未解锁皮肤锁态（`unlock_gold` 暗示，读 `users.unlocks.magicInk`，**只读**）。
- **验收**：切纸/墨皮肤全局即时换装；切动效级别影响转场/动画；魔法墨水锁态正确且不写库。
- 提交：`feat(me): 皮肤切换与动效级别设置`

---

## 4. 留作后续（本期不强求，已留 seam）

> 设计 §中标 P2/低优先，或改动面大、易动摇既有可跑功能者，本期留接口、不强行重写：

- **§5 类 Typora 双栏写作界面**（文件树折纸箱 + 纸鸟节点 + 写作/校阅模式切换 + 文件树折叠收起动效）——改动面最大，现有「落地页 + 编辑器」已覆盖功能，单列一期后续做。
- **§6.3 列表→详情共享元素「折纸摊开」**（hero 过渡）——先用 Phase 3 的翻书折叠承载详情进入，摊开二段动效后续补。
- **§3.4 纵向翻页**（绕 X 轴）——`FoldDirection` 已参数化预留。
- **§9 禅意花园美术细化 / 飘落折纸叶**——P2 优先级。
- **Lottie 正式接入**——`OrigamiIcon` 内部渲染替换为 `Lottie.asset`，静态路径保留为兜底。

---

## 5. 提交与验证纪律

- 每期收工：`flutter analyze`（0 issue 才提交）。本机无法跑 Windows，真机演示验证属用户步骤。
- 数据只走既有 Repository（§11），**不碰** CF 维护字段（`likeCount`/`commentCount`/`hotScore`/`stats.*`/`unlocks.*`）。
- 颜色/纹理一律走皮肤令牌，**禁止**新写 `Color(0xFF…)` 字面量（`design_tokens.dart` 除外）。
- 用户已授权本会话自行 `git commit`（仍按 `git-format.md` 格式，分支 `dev/fronted`）。

---

> 计划到此。落地中如与 `fronted-design.md` 冲突，以设计文件为准并回头更新本计划的对应条目。
