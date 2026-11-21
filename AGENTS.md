# agent-workspace

多仓库工作区：业务代码在 `repos/<repo>/`，跨仓库共享配置在 `.agents/`。

## 地图

| 路径 | 是什么 |
| --- | --- |
| `repos/<repo>/` | 外部仓库 checkout；内容不入版本控制，用 `update` 拉最新 |
| `.agents/rules/` | 跨仓库规则，按需读取 |
| `.agents/repos/<repo>/` | 目标仓库的个人流程文档（AGENTS.md、GLOSSARY、ADR、tracker 配置） |
| `.agents/skills/` | 跨仓库 skills，按 description 自动路由 |
| `repos.example.tsv` | 仓库清单模板；本机清单 `repos.tsv` 不入 git |
| `scripts/workspace.sh` | init / clone / check / new / add / remove / update |
| `scripts/orca-dispatch.sh` | Orca 派工与编排命令 |
| `README.md`、`.agents/handbook/` | 脚手架设计与用法；按路径直读 |

## 开工

1. 确定任务所属的 `repos/<repo>/`。
2. 读 `repos/<repo>/AGENTS.md`（业务事实）与 `.agents/repos/<repo>/AGENTS.md`（编排偏好）；冲突时：业务事实 > 编排偏好 > 本文件。
3. 按路由表读规则：

| 当你…… | 先读 |
| --- | --- |
| 做需求 / 设计 / 实现 / 测试（任何功能开发） | `.agents/rules/dev-flow.md` |
| 用 Orca 编排（主 agent 派工、子 agent 开发与验收） | `.agents/rules/orchestration.md` |
| 写检查清单或做验收裁决 | `.agents/rules/checklist.md` |
| 写代码注释或审注释 | `.agents/rules/comments.md` |
| 写或改测试 | `.agents/rules/tests.md` |
| 写或改 Go 代码 | `.agents/rules/go.md` |
| 写或改前端 / TypeScript 代码 | `.agents/rules/ts.md` |
| 写或改 shell 脚本 | `.agents/rules/shell.md` |
| 写 commit message 或开 MR | `.agents/rules/commit-and-mr.md` |
| 用中文回复或写中文文本 | `.agents/rules/chinese.md` |
| 用户输入英文时提供表达建议 | `.agents/rules/english.md` |
| 大改之前先对齐方案 | `.agents/rules/before-implementing.md` |
| 新增一条跨仓库规则 | `.agents/rules/_template.md` |

## 约定

- 跨仓库规则只写在 `.agents/rules/`；业务仓库自身约定只写在该仓库内。
- 新增共享 skill 用 `scripts/workspace.sh new <name>`；第三方 skill 用 `scripts/workspace.sh add <repo> <路径>` 软链引入。
- 业务改动在各仓库内提交（`git -C repos/<repo> ...`）；本仓库仅提交脚手架与共享规则。
- 注释默认不写、英文优先；细则见 `.agents/rules/comments.md`。
- 让你分析时只给分析：写代码等我明确说动手。
- 回复用中文，commit message 用中文（Conventional Commits 类型前缀保留英文）。
