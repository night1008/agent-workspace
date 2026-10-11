# 开发流程

主流程用 [mattpocock/skills](https://github.com/mattpocock/skills)（MIT）。真身软链在 `.agents/skills/`，clone 在 `repos/mattpocock-skills`。
上游文档：`repos/mattpocock-skills/README.md`（讲每个 skill 解决什么问题）、`docs/`（逐个详解）。更新：`git -C repos/mattpocock-skills pull`。

## 主链

```text
grill-with-docs → to-spec → to-tickets → implement-spec（内含 tdd 与 code-review）
```

| 阶段 | 命令 | 产出 |
| --- | --- | --- |
| 一次配置（**每个仓库一次**） | `/skill:setup-matt-pocock-skills` | issue tracker、triage 标签、领域文档 layout 三项配置 |
| 对齐 + 定术语 | `/skill:grill-with-docs` | 就地更新术语与决策 |
| 出规格 | `/skill:to-spec` | 规格进 issue tracker |
| 拆任务 | `/skill:to-tickets` | tracer-bullet 票据，带阻塞边 |
| 实现 | `/skill:implement-spec` | 代码 + 测试；内部依次调 `tdd`、`code-review` |

上游还有 12 个没装（`ask-matt`、`implement`、`diagnosing-bugs`、`codebase-design`、`improve-codebase-architecture`、`triage`、`wayfinder`、`pr`、`retro`、`research`、`prototype`、`wizard`）；链多了会稀释注意力，按需加，用途看上游 `docs/`：

```bash
./scripts/workspace.sh add mattpocock-skills skills/engineering/<名字>
```

## 两类 skill，跑在哪不一样

上游按 `disable-model-invocation` 分两层，这对我们的工作区很关键：

| 类型 | 装了的 | 对 cwd 的要求 |
| --- | --- | --- |
| **编排型**（只能手动调，会写文件） | `setup-matt-pocock-skills`、`grill-with-docs`、`to-spec`、`to-tickets`、`implement-spec` | **cwd 必须是目标仓库**：它们读写 `docs/agents/`、`GLOSSARY.md`、`docs/adr/`、`.scratch/` 这些相对路径 |
| **纪律型**（模型也会自动用，是方法论） | `tdd`、`code-review`、`domain-modeling`、`grilling` | 任何 cwd 都能用 |

所以：**一律在工作区根启动会话**（根是唯一启动点，见 `.agents/handbook/design.md`）。上表那列的相对路径在根会话里的基准是**会话 cwd**，要读成 `repos/<repo>/` 前缀，否则配置和文档落到工作区根，配错对象。

**别用 `cd repos/<repo> && pi` 绕过**：各家的 skills 向上扫描遇仓库根即停，进去以后这 9 个只剩用户级那份 `grilling` 可达。

## 产物落在哪

| 内容 | 落点 |
| --- | --- |
| 规格 / 票据 | 由 `/skill:setup-matt-pocock-skills` 选定：GitHub / GitLab issues，或本地 `.scratch/<feature>/`（无远端或自托管时最省事） |
| 领域术语 `GLOSSARY.md`、决策 `docs/adr/` | 目标仓库根（`domain-modeling` 就地更新） |
| 每个仓库的 skill 配置 | `repos/<repo>/docs/agents/` |
| 跨仓库的规则与清单 | `.agents/rules/`，并在根 `AGENTS.md` 路由表加一行 |
| 短命状态（handoff、临时笔记） | 系统临时目录，不进仓库 |

判据：**这份文档的生命周期属于谁，就放在谁那里。** 单仓库的文档写进顶层，代码历史里就查不到设计与决策。

## ticket 执行：主会话只当编排者

逐个在主会话里实现 ticket，上下文必爆。默认一个 ticket 一个 subagent（上游 `implement-spec` 的形态），主会话只留 spec 指针、ticket 图和短回报。**这一节就是委派授权**——pi-subagents 默认父代理直接干活，`implement-spec` 正文那句不算授权。

```text
subagent({ agent: "worker", cwd: "repos/<repo>", isolation: "worktree", async: true,
           outputMode: "file-only", output: "<仓库外>/<ticket>.md",
           task: "<ticket> + 分支约定 + 必须用 tdd" })
```

- 只走 context pointer（ticket、分支、commit、笔记文件），别粘代码或摘要；产出落文件。
- 一个 worktree 一个 writer；`cwd` 是目标仓库，`isolation` 要求源干净。
- slice 要装进一个全新窗口；`/to-spec` 与 `/to-tickets` 之间不 clear / compact。
- 收尾只跑一次 `code-review` 再清 worktree；小改动不走这套。

坑（上游踩过）：`code-review` 中途跑会成循环；worktree 里 gitignored 的 fixture / 本地库 / 凭据会**静默 skip 报绿**；implementer 不自动继承 `tdd`。

## 已知差异

上游 skill 之间用 `Call the Skill tool with "tdd"` 交接，这是它自己的约定（上游 CHANGELOG #878）。本环境没有 Skill 工具，**读作「读 `.agents/skills/<name>/SKILL.md` 并执行」**。
