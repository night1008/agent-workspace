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

所以：**一律在工作区根启动会话**（根是唯一启动点，见 `handbook/design.md`），单仓库与跨仓库任务没有区别。唯一要额外记住的是：上表那列「cwd 必须是目标仓库」里的相对路径，在根会话里的基准是**会话 cwd**，所以正文的 `docs/agents/`、`GLOSSARY.md`、`docs/adr/`、`.scratch/` 要读成 `repos/<repo>/` 前缀——不带前缀，配置和文档就落到工作区根，配错对象。

**别用 `cd repos/<repo> && pi` 绕过**：各家的 skills 向上扫描遇仓库根即停（见 `handbook/design.md` 的表），进去以后这 9 个 skill 只剩用户级那份 `grilling` 可达，主链其余 8 个都拿不到。

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

一个 spec 下的 ticket 逐个在主会话里实现，上下文必爆。默认形态是把每个 ticket 交给一个 subagent（上游 `implement-spec` 的做法），主会话只持有 spec 指针、ticket 图和每个 ticket 的短回报。

上游 `implement-spec` 的正文就是「use implementer subagents，每个 ticket 一个 worktree」，但**那句话不构成授权**：pi-subagents 默认父代理直接干活，只有 operator 明说或工作区规则写明才允许委派。所以这一节是**授权**，不是建议。

```text
subagent({
  agent: "worker",                         // 别名含 implementer；fresh context + thinking high
  cwd: "repos/<repo>",                     // 目标仓库，不是工作区根
  isolation: "worktree",                   // 要求源干净；先建好 integration branch
  async: true,                             // 完成会唤醒主会话，不要 sleep / 轮询
  outputMode: "file-only",
  output: "<仓库外的固定目录>/<ticket>.md",  // worktree 清理后还在，也不污染仓库
  task: "<ticket 路径或编号> + 分支约定 + 必须用 tdd"
})
```

- **通信只走 context pointer**：ticket 路径或编号、分支名、commit、探索笔记文件。不要往 `task` 里粘代码或摘要——上游的原话是，只有这样才给编排会话的窗口留得出放 ticket 图的空间。
- **产出落文件**、主会话只留引用，不回灌正文。
- **一个 worktree 一个 writer**：并发子代理不要写同一个工作区。
- **`to-tickets` 切的 slice 要能装进一个全新窗口**——这是第一道防爆，比执行方式更重要。
- **`/to-spec` 与 `/to-tickets` 之间不要 clear / compact**，那两个要在同一个窗口里跑完。
- 收尾：所有 ticket 落地后**只跑一次** `code-review`，再清理 worktree（`mode: plan` 看过再 `apply`）。能塞进一个窗口的小改动不走这套。

三个上游踩过的坑：

1. **`code-review` 只在全部 ticket 落地后跑一次**。中途跑会拿它跟整个 spec 比，未建的 ticket 全被判成失败，触发「review → 再建 → 再 review」的循环（上游有人 5 个 ticket 的功能在 review/fix 循环里花了约 4 小时）。
2. **worktree 里只有 git 跟踪的东西**：测试若依赖 gitignored 的 fixture、本地数据库、凭据，会在 worktree 里**静默 skip 然后报绿**。这类 ticket 显式说明在主 checkout 里跑。
3. **implementer 必须显式带上 `tdd`**：subagent 不会自动继承（上游修过这个洞：一从单 ticket 扩到多 ticket，红绿就断了）。

## 已知差异（软链的上游改不了）

上游 skill 之间用 `Call the Skill tool with "tdd"` 交接，这是它自己的约定（上游 CHANGELOG #878）。本环境没有 Skill 工具，**读作「读 `.agents/skills/<name>/SKILL.md` 并执行」**。
