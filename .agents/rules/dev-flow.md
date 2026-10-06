# 开发流程

主流程用 [mattpocock/skills](https://github.com/mattpocock/skills)（MIT）。真身软链在 `.agents/skills/`，clone 在 `repos/mattpocock-skills`。
上游文档：`repos/mattpocock-skills/README.md`（讲每个 skill 解决什么问题）、`docs/`（逐个详解）。更新：`git -C repos/mattpocock-skills pull`。

## 主链

```text
grill-with-docs → to-spec → to-tickets → implement-spec（内含 tdd 与 code-review）
```

| 阶段 | 命令 | 产物 |
| --- | --- | --- |
| 一次配置 | `/skill:setup-matt-pocock-skills`（**每个仓库跑一次**） | `docs/agents/issue-tracker.md`、`domain.md`、`triage-labels.md` |
| 对齐 + 定术语 | `/skill:grill-with-docs` | 就地更新 `GLOSSARY.md`、`docs/adr/` |
| 出规格 | `/skill:to-spec` | 规格 → issue tracker（GitHub / GitLab / `.scratch/<feature>/` 本地 markdown） |
| 拆任务 | `/skill:to-tickets` | tracer-bullet 票据，带阻塞边 |
| 实现 | `/skill:implement-spec` | 代码 + 测试；内部依次调 `tdd`、`code-review` |

当前只装了这条链需要的 9 个：`setup-matt-pocock-skills`、`grill-with-docs`、`grilling`、`domain-modeling`、`to-spec`、`to-tickets`、`implement-spec`、`tdd`、`code-review`。

上游还有这些没装，要哪个一条命令加上（链多了会稀释注意力，所以按需）：

```bash
./scripts/workspace.sh add mattpocock-skills skills/engineering/<名字>
# ask-matt（不知道该用哪个时的路由器）、implement（不经票据直接实现）
# diagnosing-bugs（难 bug 的诊断循环）、codebase-design（深模块词汇，tdd 会引用它）
# improve-codebase-architecture、triage、wayfinder、pr、retro、research、prototype、wizard
```

## 两类 skill，跑在哪不一样

上游按 `disable-model-invocation` 分两层，这对我们的工作区很关键：

| 类型 | 装了的 | 对 cwd 的要求 |
| --- | --- | --- |
| **编排型**（只能手动调，会写文件） | `setup-matt-pocock-skills`、`grill-with-docs`、`to-spec`、`to-tickets`、`implement-spec` | **cwd 必须是目标仓库**：它们读写 `docs/agents/`、`GLOSSARY.md`、`docs/adr/`、`.scratch/` 这些相对路径 |
| **纪律型**（模型也会自动用，是方法论） | `tdd`、`code-review`、`domain-modeling`、`grilling` | 任何 cwd 都能用 |

所以：**单仓库功能进 `repos/<repo>/` 里启动会话**（`cd repos/<repo> && pi`），跨仓库任务在工作区根跑。
在顶层跑编排型 skill，配置和文档会落到工作区根，配错对象。

## 产物落在哪

| 内容 | 落点 |
| --- | --- |
| 规格 / 票据 | 由 `/skill:setup-matt-pocock-skills` 选定：GitHub / GitLab issues，或本地 `.scratch/<feature>/`（无远端或自托管时最省事） |
| 领域术语 `GLOSSARY.md`、决策 `docs/adr/` | 目标仓库根（`domain-modeling` 就地更新） |
| 每个仓库的 skill 配置 | `repos/<repo>/docs/agents/` |
| 跨仓库的规则与清单 | `.agents/rules/`，并在根 `AGENTS.md` 路由表加一行 |
| 工作区自身的决策与说明 | 根 `README.md` |
| 短命状态（handoff、临时笔记） | 系统临时目录，不进仓库 |

判据：**这份文档的生命周期属于谁，就放在谁那里。** 单仓库的文档写进顶层，代码历史里就查不到设计与决策。

## 已知差异（软链的上游改不了）

上游 skill 之间用 `Call the Skill tool with "tdd"` 交接，这是它自己的约定（上游 CHANGELOG #878）。本环境没有 Skill 工具，**读作「读 `.agents/skills/<name>/SKILL.md` 并执行」**。
