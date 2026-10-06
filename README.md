# agent-workspace

一个多仓库工作区：多个业务仓库各自独立 clone 在 `repos/` 下，共享同一份 `AGENTS.md`、skills 和 rules。
在根目录启动一次 agent，「跨仓库」就只是普通的一次任务。

## 目录结构

```text
agent-workspace/
├── AGENTS.md              # 常驻上下文：仓库地图、规则路由表、硬约定
├── README.md              # 本文件，给人看的
├── repos.tsv              # 仓库清单：name <TAB> url <TAB> branch <TAB> kind
├── .agents/
│   ├── skills/            # 跨仓库共享 skills（每个子目录一个 SKILL.md）
│   │   └── _shared/       # 只给别的 skill 引用的片段，不会被当成 skill 加载
│   └── rules/             # 跨仓库规则，按需读取，永远不会自动进上下文
├── .claude/skills         # -> ../.agents/skills（Claude Code 只认这个位置）
├── repos/                 # 外部仓库的本地 checkout：业务仓库 + skill 源仓库（内容不入本仓库版本控制）
└── scripts/workspace.sh   # clone / check / new / add / remove
```

## 三层资源模型

决定一段内容写在哪，先问它「需要多早被看到」：

| 层 | 写在哪 | 何时进上下文 | 放什么 |
| --- | --- | --- | --- |
| 常驻 | `AGENTS.md` | 每次会话，始终 | 仓库地图、硬约定、路由表。**每行都按每次会话付费，能短则短** |
| 自动路由 | `.agents/skills/<name>/SKILL.md` | 只有 `description` 常驻，命中才读全文 | 多步骤流程 + 附带脚本 / 模板 / 参考文件 |
| 按需 | `.agents/rules/<topic>.md` | 从不自动加载，靠 `AGENTS.md` 的一行指针 | 静态规范、检查清单、长篇约束 |

判断标准：**多步骤流程 → skill；一堆约束 → rule；每次都必须遵守且很短 → 直接写进 `AGENTS.md`。**

`AGENTS.md` 里的路由表一条规则一行，指针的措辞决定它会不会被读到：

| 当你…… | 先读 |
| --- | --- |
| 写或改 Go 代码 | `.agents/rules/go.md` |
| 新增一条跨仓库规则 | `.agents/rules/_template.md` |

## 三个 CLI 各从哪读

目录结构由加载规则决定，不是拍脑袋定的。以下三条核对过官方文档与源码，pi 那两条另外在本机实测过：

| | 常驻指令 | skills 目录 | 边界 |
| --- | --- | --- | --- |
| pi | `AGENTS.md`（也认 `CLAUDE.md`） | `.agents/skills/` | 从 cwd 往上扫，**遇 git 仓库根即停** |
| Codex | `AGENTS.md`（全局是 `~/.codex/AGENTS.md`） | `.agents/skills/`（另有 `$HOME/.agents/skills`、`/etc/codex/skills`） | 文档原文：从 cwd 一直扫到 repository root |
| Claude Code | `AGENTS.md`，但**当前目录或其祖先存在 `CLAUDE.md` / `CLAUDE.local.md` 时就改读 CLAUDE.md**（默认模式 `claude-md-or-agents-md`，需 v2.1.277+） | `.claude/skills/`（**不读 `.agents/skills`**，只会在导入其他 agent 配置时扫一次） | `.claude/skills/` 同样扫到仓库根 |

由此得出一条规矩：

- `.agents/skills/` 写一次，pi 与 Codex 直接可用；Claude Code 靠仓库里那个 `.claude/skills` 软链（相对路径，跟 git 一起走）。
- `.agents/rules/` 三家都不会自动读，只能靠 `AGENTS.md` 的指针——所以路由表那一行是必需的，不是装饰。
- Claude Code 另有原生的 `.claude/rules/`（启动即加载，可用 `paths:` frontmatter 做文件级触发）。想把规则也变成 Claude 的常驻内容，就把 `.agents/rules` 链过去，代价是同一批规则在 pi / Codex 里仍是指针式的，两边语义不再一致。
- 用户级指令仍是各家自己的：`~/.pi/agent/AGENTS.md`、`~/.codex/AGENTS.md`、`~/.claude/CLAUDE.md`。
- 当前工作区及其祖先目录上都没有 `CLAUDE.md`，所以 Claude Code 读的就是这份 `AGENTS.md`。哪天在顶层（或更上层）放一个 `CLAUDE.md`，Claude 会改读它，另外两家不受影响。

## 只用一种方式：始终在顶层启动

`agent-workspace/` 是唯一的启动点。共享的 `AGENTS.md`、skills、rules 都在这一次会话里生效，跨仓库改动就是普通的多次 `edit`。

代价只有一条：**`repos/<repo>/` 里的东西不会自动加载**——该仓库自己的 `AGENTS.md`、`.pi/`、`.claude/`、仓库级 hook 都需要显式对待。根 `AGENTS.md` 已内置「开工前先读目标仓库的 AGENTS.md」这条规则；其余需要时在会话里 `cd repos/<repo> && <命令>` 跑，不影响 skills 与 rules。

哪天改成在 `repos/<repo>/` 里启动，要知道三个 CLI 的 skills 扫描都会在仓库根停下（见上表），顶层 `.agents/skills` 就看不到了——那时再把 skills 放进用户级目录。

## 快速开始

```bash
cd ~/Codes/github.com/agent-workspace

./scripts/workspace.sh clone     # 按 repos.tsv 克隆缺失的仓库（可选）
./scripts/workspace.sh check     # 自检：AGENTS.md、软链、skill 元数据（有问题退出码 1）
pi                               # 或者 claude / codex，都在这个目录启动
```

没有安装步骤：`.claude/skills` 指向 `.agents/skills` 的软链跟着 git 一起走，clone 下来就是就绪状态。

## 日常操作

### 新增共享 skill

```bash
./scripts/workspace.sh new review-api     # 生成 .agents/skills/review-api/SKILL.md
# 改 description：写清「做什么 + 什么场景」，模型靠这一句决定要不要读
./scripts/workspace.sh check
```

### 引入 / 更新第三方 skill

第三方 skill 一律**软链**，不复制内容：上游 clone 在 `repos/` 里，`.agents/skills/` 只放一个相对软链。

```bash
printf 'mattpocock-skills\thttps://github.com/mattpocock/skills\tmain\tskill\n' >> repos.tsv
./scripts/workspace.sh add mattpocock-skills skills/productivity/grilling
./scripts/workspace.sh check
```

`add` 做的事：`repos/<repo>` 不在就先按 `repos.tsv` 克隆，然后建软链
`.agents/skills/<name> -> ../../repos/<repo>/<path>`（名字默认取目录名，可用 `--name` 覆盖）。

```bash
./scripts/workspace.sh remove <name>        # 只删软链
```

更新就是拉上游，没有第二步同步：

```bash
git -C repos/mattpocock-skills pull          # 软链目标跟着变
```

`repos.tsv` 的第四列标它是什么：留空 / `repo` 是业务仓库，完整克隆（要历史）；`skill` 是 skill 源，只读工作树，所以 `clone` 用 `--depth 1`——`mattpocock-skills` 这样是 1.5M 而不是 3.2M。浅克隆里 `git pull` 正常；如果上游改写了历史、`pull` 报不能 fast-forward，就：

```bash
git -C repos/mattpocock-skills fetch --depth 1 && git -C repos/mattpocock-skills reset --hard origin/main
```

为什么不用复制：软链只有一份真身，`git pull` 就是更新，也不会出现「仓库里是新版、全局是旧版」这种漂移。代价是**软链必须指向工作区内**（相对路径），所以上游仓库要 clone 到 `repos/` 并有 `repos.tsv` 登记——否则别人 clone 这个工作区只会拿到一堆坏链，`check` 会把它们报出来。

两个注意点：

- 上游 skill 的内容是**只读**的：要改就得改 `repos/<repo>` 里的文件（那就变成你对那个仓库的改动），或者在 `.agents/skills/` 里自研一个同名 skill。
- 上游 SKILL.md 里的调用写法是自带 Agent 的语法。例如 `mattpocock/skills` 的 `grill-me` 正文是「Call the Skill tool with "grilling"」（Claude Code 语法），软链过来在 pi / Codex 里语义不对，而软链又改不了——所以这种转发壳直接不链，用 `/skill:grilling` 就行。

### 新增共享规则

```bash
cp .agents/rules/_template.md .agents/rules/<topic>.md
```

写完**必须在根 `AGENTS.md` 的路由表加一行**——没有那一行，这份规则永远不会被读到。

### 接入一个新仓库

```bash
printf 'your-service\tgit@your-host:your-org/your-service.git\tmain\n' >> repos.tsv
./scripts/workspace.sh clone && ./scripts/workspace.sh check
```

也可以直接 `git clone <url> repos/<name>`。`repos.tsv` 供 `clone` 和 `add`（自动拉取缺失的 skill 源）使用，不影响仓库里的其他逻辑。

### 全局 skill ↔ 工作区 skill

- 全局：`~/.pi/agent/skills/`（所有项目都加载，脱离版本控制，换机器会丢）
- 工作区：`.agents/skills/`（只服务本工作区，跟着 git 走）

只有这个工作区用得上的，搬进工作区；写通用工具的，留在全局。**同名时工作区赢**——加载顺序是 项目 `.pi/skills` → 项目 `.agents/skills` → `~/.pi/agent/skills` → `~/.agents/skills`，先加载的胜出。所以同一份内容只留一处：搬进工作区就把全局那份删掉（否则全局那份只在其它目录生效），反之则别在仓库里放。

## 已知的坑

- **skills 的发现会在 git 仓库根停下**（三个 CLI 都一样），所以不要在 `repos/<repo>/` 里启动：那里的会话看不到顶层 `.agents/skills`。
- **`repos/<repo>` 自己的 `AGENTS.md` 不会在顶层会话里自动加载**（context 文件只从 cwd 往上找，不往下）。根 `AGENTS.md` 里写着「开工前先读它」。
- **`.claude/skills` 是相对软链**（`../.agents/skills`），整个工作区搬目录不会断；`check` 会验证它是否仍然指向 `.agents/skills`。
- **skill 目录内的 `.gitignore` / `.ignore` / `.fdignore` 会把 skill 从加载列表里排除掉**（pi 会读它们）。仓库根的 `.gitignore` 不影响加载。
- **`.agents/skills/` 顶层的 `.md` 会被当作 skill 加载**（没有 `description` 的静默跳过），子目录里的 `.md` 不会。所以片段放 `_shared/`，文档放 `.agents/rules/`。
- **project trust 按最近的父目录生效**：给工作区根做过一次 trust，`repos/*` 全部继承，不会再逐仓库询问。`--no-approve` 会跳过 `.pi/*` 和 `.agents/skills`，但 `AGENTS.md` 照常加载。
- 根目录里运行的扩展（如 pi-rewind）会在工作区自动提交；`repos/*` 已 gitignore，业务仓库不会被卷进来。

## 为什么不用别的方案

| 方案 | 为什么没选 |
| --- | --- |
| `git submodule` | 父仓库记录 commit 指针，clone / pull 两层耦合；「顺手改一下另一个仓库」要先切子模块再切回来。`repos/` + `repos.tsv` 更松耦合 |
| 在每个仓库放 `.pi/settings.json` 声明共享 skills 路径 | 要改每个业务仓库、每个仓库单独 trust、路径跟着机器变。现在只在顶层放一个 `.claude/skills` 软链 |
| 全塞进 `~/.pi/agent/skills/` | 所有项目都加载（无关仓库白背上下文成本），且脱离版本控制 |
| 业务仓库直接放在工作区根目录下（`agent-workspace/<repo>`） | `repos.tsv`、软链、gitignore 的规则都会变复杂，根目录也会被仓库文件淹没 |

## 相关文件

- `AGENTS.md` — agent 读的常驻上下文（三个 CLI 都读它）
- 用户级指令：`~/.pi/agent/AGENTS.md`、`~/.codex/AGENTS.md`、`~/.claude/CLAUDE.md`
- pi：`docs/skills.md`、`docs/configuration.md`（context files 与 `.pi`）、`docs/security.md`（project trust）
- Codex：<https://developers.openai.com/codex/skills>（.agents/skills 的扫描范围）
- Claude Code：<https://code.claude.com/docs/en/memory>（AGENTS.md 与 CLAUDE.md 的取舍）、<https://code.claude.com/docs/en/skills>（`.claude/skills` 与软链）
