# 「开拓」栏（角色卡 · 方案 A）开发记录

> 任务来源：`docs/角色查询-todo.md`。本目录留细化工作总结与人工操作指引。
> 实现分支：`feat/explore-character-cards`。

模块 G（角色查询）以**方案 A：预爬 + 缓存查询**的最小形态复活为底栏第 5 个
「开拓」Tab。运行期 app **只读 Firestore `charactersCache`**，不连任何在线后端
（ES / Mongo / FastAPI），与 `CLAUDE.md` §6 零成本 / 视频交付策略一致。

数据是**一次性离线导入**：本地起 ISR-scraper 后端 → 导角色清单 → 跑
`import_characters.mjs` 聚合灌库 → 关后端。演示期只剩 Firestore。

## 文档

- [实现总结](实现总结.md) —— 文件清单、数据流、字段映射、设计取舍。
- [人工操作指引](人工操作指引.md) —— pub get / ISR 起后端 / 导入 / Emulator 验证 / 验收。
