# 开发流程

主流程用 [mattpocock/skills](https://github.com/mattpocock/skills)（MIT）。真身软链在 `.agents/skills/`，clone 在 `repos/mattpocock-skills`。
上游文档：`repos/mattpocock-skills/README.md`（讲每个 skill 解决什么问题）、`docs/`（逐个详解）。更新：`git -C repos/mattpocock-skills pull`。

## 主链

```text
grill-with-docs → to-spec → to-tickets → implement-spec（内含 tdd 与 code-review）
```

| 阶段 | 命令 | 产出 |
| --- | --- | --- |
| 一次配置（**每个仓库一次**） | `clone` 自动跑 `repo-init`（tracker 按 origin 猜） | issue tracker、领域文档 layout 两份配置，落 `.agents/repos/<repo>/docs/agents/` |
| 对齐 + 定术语 | `/skill:grill-with-docs` | 就地更新术语与决策 |
| 出规格 | `/skill:to-spec` | 规格进 issue tracker |
| 拆任务 | `/skill:to-tickets` | tracer-bullet 票据，带阻塞边 |
| 实现 | `/skill:implement-spec` | 代码 + 测试；内部依次调 `tdd`、`code-review` |

上游还有 12 个没装（`ask-matt`、`implement`、`diagnosing-bugs`、`codebase-design`、`improve-codebase-architecture`、`triage`、`wayfinder`、`pr`、`retro`、`research`、`prototype`、`wizard`）；链多了会稀释注意力，按需加，用途看上游 `docs/`：

```bash
./scripts/workspace.sh add mattpocock-skills skills/engineering/<名字>
```

**`setup-matt-pocock-skills` 不跑**：它会往仓库根写 `docs/agents/*.md` 和 `AGENTS.md` 的 `## Agent skills` 段。这是个人流程，不是团队资产，不能进业务仓库。同样的内容落到 `.agents/repos/<repo>/`：

```bash
./scripts/workspace.sh repo-init <repo> [--tracker github|gitlab|local] [--domain single|multi]
```

它从上游种子模板（`repos/*/skills/engineering/setup-matt-pocock-skills/`）复制 `issue-tracker-*.md` 与 `domain.md`，在文件头贴一段落点声明（模板写的是仓库根路径，靠这段改写成 `.agents/repos/<repo>/` 与工作区 `.scratch/`），再生成 `AGENTS.md`。tracker 默认从 origin 的 URL 猜，没有远端就是 `local`；已存在的文件不覆盖。`triage-labels.md` 不生成——`triage` 没装。

## 两类 skill，跑在哪不一样

上游按 `disable-model-invocation` 分两层，这对我们的工作区很关键：

| 类型 | 装了的 | 对 cwd 的要求 |
| --- | --- | --- |
| **编排型**（只能手动调，会写文件） | `grill-with-docs`、`to-spec`、`to-tickets`、`implement-spec` | **cwd 必须是目标仓库**：要读代码、跑测试；但它们正文里写的是仓库根相对路径（`GLOSSARY.md`、`docs/adr/`、`docs/agents/`、`.scratch/`） |
| **纪律型**（模型也会自动用，是方法论） | `tdd`、`code-review`、`domain-modeling`、`grilling` | 任何 cwd 都能用 |

所以：**一律在工作区根启动会话**（根是唯一启动点，见 `.agents/handbook/design.md`）。读代码时的 `repos/<repo>/` 前缀自己带；**写产物时反过来，一律用绝对路径指到工作区**（落点见下一节），业务仓库里不留任何流程文件。

**别用 `cd repos/<repo> && pi` 绕过**：各家的 skills 向上扫描遇仓库根即停，进去以后只剩用户级那份 `grilling` 可达。

## 产物落在哪

个人流程的产物全部落工作区，业务仓库只放代码和团队自己的文件。

| 内容 | 落点 |
| --- | --- |
| 规格 / 票据 | GitHub / GitLab issues，或本地 `.scratch/<feature>/`（工作区根，已 gitignore） |
| worker 的 brief / report / verdict | 同上 `.scratch/<feature>/{briefs,reports,verdicts}/`，派工时给绝对路径 |
| 领域术语 `GLOSSARY.md`、`GLOSSARY-MAP.md`、决策 `docs/adr/` | `.agents/repos/<repo>/` |
| tracker 与 domain layout 两份配置（`triage` 装后才有标签映射） | `.agents/repos/<repo>/docs/agents/` |
| 个人编排偏好（流程、派工要求、验收口径） | `.agents/repos/<repo>/AGENTS.md` |
| 开发进度摘要（一个 feature 一行） | `.agents/repos/<repo>/progress.md` |
| 业务仓库根的 `AGENTS.md` | 仓库本来就有的那份不碰：业务变动让它过时就改、随业务提交（构建命令、目录约定这类事实）；个人内容永不写入 |
| 跨仓库的规则与清单 | `.agents/rules/`，并在根 `AGENTS.md` 路由表加一行 |
| 短命状态（handoff、临时笔记） | 系统临时目录，不进任何仓库 |

判据：**别人 clone 下来会踩坑的，写业务仓库；只影响你这套编排的，写工作区。** `domain-modeling` 正文会要你建仓库根的 `GLOSSARY.md`，按这节改写到 `.agents/repos/<repo>/`；`workspace.sh check` 会发现漏网的。

## ticket 执行：主会话只当编排者

逐个在主会话里实现 ticket，上下文必爆。默认一个 ticket 一个 subagent（上游 `implement-spec` 的形态），主会话只留 spec 指针、ticket 图和短回报。**这一节就是委派授权**——pi-subagents 默认父代理直接干活，`implement-spec` 正文那句不算授权。

派工四件事：agent 用 `worker`；cwd 是 `repos/<repo>`、worktree 隔离（要求源干净）；产物 `file-only` 落到工作区根的 `.scratch/<feature>/<ticket>.md`；task 只给 ticket 指针 + 分支约定 + 「必须用 tdd」，再加上两份 `AGENTS.md` 的绝对路径（worker 只会自动加载业务仓库那份）。

- 只走 context pointer（ticket、分支、commit、笔记文件），别粘代码或摘要。
- 一个 worktree 一个 writer。
- slice 要装进一个全新窗口；`/to-spec` 与 `/to-tickets` 之间不 clear / compact。
- 收尾只跑一次 `code-review` 再清 worktree；小改动不走这套。

坑（上游踩过）：`code-review` 中途跑会成循环；worktree 里 gitignored 的 fixture / 本地库 / 凭据会**静默 skip 报绿**；implementer 不自动继承 `tdd`。

## 已知差异

上游 skill 之间用 `Call the Skill tool with "tdd"` 交接，这是它自己的约定（上游 CHANGELOG #878）。本环境没有 Skill 工具，**读作「读 `.agents/skills/<name>/SKILL.md` 并执行」**。
