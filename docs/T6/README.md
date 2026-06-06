# T6 — 故事书 & 章节（Storybook & Chapters）

> 本特性的阶段性开发记录目录。设计事实来源：`docs/next-design-detailed.md`（工程化细化）
> 与 `docs/next-design.md`（一句话需求）。本目录只记**已交付物 / 人工操作 / 验收**，
> 不重复设计内容。

## 索引

| 文件 | 内容 |
|------|------|
| [T6-storybook-chapters.md](T6-storybook-chapters.md) | 全量开发记录：交付物清单、人工操作（部署 / 迁移）、验收对照、偏差与限制、验证结果 |

## 一句话

「我的故事」升级为**故事书总览**（流式网格 + 排序 + pin + 换封面）→ 进入一本书后是
**章节文件树**（折纸箱 = 章节聚合，纸鸟 = 文章 + 草稿/已发布徽记）。story 加
`storybookId` / `chapterName` 两字段；新增轻量 `storybooks` 集合存封面 / pin / 章节顺序。

## 分支

`feat/storybook-chapters`（从 `main` 切出）。

## 任务对照（`next-design-detailed.md` §7）

| 任务 | 内容 | 状态 |
|------|------|------|
| T6.0 | 封面上传 CF `uploadStorybookCover` | ✅ 代码交付（演示前 deploy） |
| T6.1 | `Storybook` 模型 + Repository + `Story` 扩两字段 | ✅ |
| T6.2 | 故事书总览屏 | ✅ |
| T6.3 | 故事书内部屏 · 章节文件树 | ✅ |
| T6.4 | 编辑器接默认书 + 移动 / 换封面交互 | ✅ |
| T6.5 | 旧数据迁移脚本 | ✅ 脚本交付（演示前跑一次） |
| T6.6 | 安全规则 + 索引 + schema 同步 | ✅ 代码交付（并入 T1.10a 部署） |
