# 设计说明

**改脚手架本身时才需要读**：为什么目录是这么摆的、每个 CLI 从哪儿读、否决过哪些方案。日常用这个工作区不用看这份。

## 目录结构

```text
agent-workspace/
├── AGENTS.md              # 常驻上下文：仓库地图、规则路由表、硬约定
├── CLAUDE.md              # -> AGENTS.md（只认 CLAUDE.md 的 agent 用，同源不漂移）
├── README.md              # 入口，给人看的
├── .ignore                # 搜索工具的忽略清单：隐藏面向人的文档、把 repos/ 白名单回来
├── repos.example.tsv      # 仓库清单模板（name <TAB> url <TAB> branch <TAB> kind）；本机 repos.tsv 由它生成，不进 git
├── .agents/
│   ├── skills/            # 跨仓库共享 skills（每个子目录一个 SKILL.md；第三方用相对软链）
│   ├── rules/             # 跨仓库规则，按需读取，永远不会自动进上下文
│   └── handbook/          # 面向人的脚手架说明：用法、设计（本文件）、坑
├── .claude/skills         # -> ../.agents/skills（Claude Code 只认这个位置）
├── repos/                 # 外部仓库的本地 checkout：业务仓库 + skill 源仓库（内容不入本仓库版本控制）
└── scripts/workspace.sh   # init / clone / check / new / add / remove / update
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

## 四个 CLI 各从哪读

目录结构由加载规则决定，不是拍脑袋定的。以下四条核对过官方文档与源码（agy 的取自它自己的内置文档），pi 那两条另外在本机实测过：

| | 常驻指令 | skills 目录 | 边界 |
| --- | --- | --- | --- |
| pi | `AGENTS.md`（也认 `CLAUDE.md`） | `.agents/skills/` | 从 cwd 往上扫，**遇 git 仓库根即停** |
| Codex | `AGENTS.md`（全局是 `~/.codex/AGENTS.md`） | `.agents/skills/`（另有 `$HOME/.agents/skills`、`/etc/codex/skills`） | 文档原文：从 cwd 一直扫到 repository root |
| Claude Code | `CLAUDE.md`（本仓库里是 `AGENTS.md` 的软链）；当前目录及祖先都没有 `CLAUDE.md` 时才改读 `AGENTS.md`（默认模式 `claude-md-or-agents-md`，需 v2.1.277+） | `.claude/skills/`（**不读 `.agents/skills`**，只会在导入其他 agent 配置时扫一次） | `.claude/skills/` 同样扫到仓库根 |
| agy（Antigravity CLI） | `AGENTS.md`（也认 `GEMINI.md`），**按文件分层**：改到哪个文件就向上加载到仓库根 | `.agents/skills/`（也支持 `.agent/`、`_agents/`、`_agent/`） | 同样 cwd → 仓库根；**`.agents/rules/*.md` 是它原生的规则路径，自动分层加载** |

由此得出一条规矩：

- `.agents/skills/` 写一次，pi / Codex / agy 直接可用；只有 Claude Code 靠仓库里那个 `.claude/skills` 软链（相对路径，跟 git 一起走）。
- `.agents/rules/` 在 agy 里是自动加载的（不靠指针，代价是变成常驻）；pi / Codex / Claude Code 三家都不会自动读，只能靠 `AGENTS.md` 的指针——所以路由表那一行是必需的，不是装饰。
- Claude Code 另有原生的 `.claude/rules/`（启动即加载，可用 `paths:` frontmatter 做文件级触发）。想把规则也变成 Claude 的常驻内容，就把 `.agents/rules` 链过去，代价是同一批规则在 pi / Codex 里仍是指针式的，两边语义不再一致。
- 用户级指令仍是各家自己的：`~/.pi/agent/AGENTS.md`、`~/.codex/AGENTS.md`、`~/.claude/CLAUDE.md`、`~/.gemini/config/`（agy）。
- 根目录的 `CLAUDE.md` 是 `AGENTS.md` 的软链：只认 `CLAUDE.md` 的 agent 也能拿到指令，且两边永远同源——改 `AGENTS.md` 就同步生效。
- Claude Code 的兼容层就两条：`CLAUDE.md`（指令）+ `.claude/skills`（skills）。其余 agent 要么本来就认 `.agents/skills`（Amp、Cursor、Gemini CLI、GitHub Copilot、OpenCode、Zed、Warp、Cline、Kimi Code CLI…），要么加一条同形状的相对软链即可（如 `mkdir -p .windsurf && ln -s ../.agents/skills .windsurf/skills`，并把路径追到 `scripts/workspace.sh` 的 `LINKS` 里让 `check` 一并验证）。

## 只用一种方式：始终在顶层启动

工作区根是唯一的启动点。共享的 `AGENTS.md`、skills、rules 都在这一次会话里生效，跨仓库改动就是普通的多次 `edit`。

两条代价：

1. **`repos/<repo>/` 里的东西不会自动加载**——该仓库自己的 `AGENTS.md`、`.pi/`、`.claude/`、仓库级 hook 都需要显式对待。根 `AGENTS.md` 已内置「开工前先读目标仓库的 AGENTS.md」这条规则；bash 命令需要时在会话里 `cd repos/<repo> && <命令>` 跑，不影响 skills 与 rules。
2. **落在目标仓库里的相对路径要自己带前缀**。pi 的 `read` / `write` / `edit` 按会话 cwd（工作区根）解析相对路径，而编排型 skill 的正文只写裸相对路径（`docs/agents/`、`GLOSSARY.md`、`docs/adr/`、`.scratch/`，见 `.agents/rules/dev-flow.md`），所以要读成 `repos/<repo>/docs/agents/`。bash 是例外：每条命令自带 cwd，`cd repos/<repo> && …` 就够。

别靠「进 `repos/<repo>/` 里启动」来回避第 2 条：各家的 skills 向上扫描都在仓库根停下（见上表），进去以后顶层 `.agents/skills/` 就看不到了。真要那么用，得先把 skills 也放进用户级目录。

## 搜索面：`.ignore`

根目录的 `.ignore` 只服务搜索工具：rg / fd / ag 读它，git 完全不读。pi 内置的 `grep` / `find` 就是 rg / fd 的封装，用户敲的也是同一批命令，所以这份文件等于「agent 能看到什么」。三组规则各有目的：

| 规则 | 为什么 |
| --- | --- |
| `README.md`、`.agents/handbook/` | 面向人的脚手架说明，只有改工作区自身时才需要；默认读掉只是白花上下文，定位也和根 `AGENTS.md` 重复 |
| `!repos/*` | 反向白名单。根 `.gitignore` 里的 `repos/*` 会让 rg / fd **静默**跳过整个 `repos/`——从根搜索看不到任何业务代码，而根正是唯一启动点。`.ignore` 优先级高于 `.gitignore`，正好只修搜索层 |
| `.git/` | pi 的 `grep` / `find` 带 `--hidden`，不挡会连 git 内部一起翻；嵌套仓库各自的 `.git` 同理 |

为什么前两条不用 `.gitignore` 表达：`README.md`、`.agents/handbook/` 都是**已跟踪**文件，写进 `.gitignore` 语义不对；而且只有 `.ignore` 能做反向白名单——改 `.gitignore` 本身只会让 git 开始报未跟踪。`.ignore` 不参与 git，改它不影响提交与工作区状态。

嵌套仓库自己的 `.gitignore` 不受影响（实测：探针仓库里的 `node_modules/`、`build/` 照常被排除）。

## 为什么不用别的方案

| 方案 | 为什么没选 |
| --- | --- |
| `git submodule` | 父仓库记录 commit 指针，clone / pull 两层耦合；「顺手改一下另一个仓库」要先切子模块再切回来。`repos/` + 清单文件更松耦合 |
| 在每个仓库放 `.pi/settings.json` 声明共享 skills 路径 | 要改每个业务仓库、每个仓库单独 trust、路径跟着机器变。现在只在顶层放一个 `.claude/skills` 软链 |
| 全塞进 `~/.pi/agent/skills/` | 所有项目都加载（无关仓库白背上下文成本），且脱离版本控制 |
| 业务仓库直接放在工作区根目录下（`agent-workspace/<repo>`） | `repos.tsv`、软链、gitignore 的规则都会变复杂，根目录也会被仓库文件淹没 |

## 依据

- `AGENTS.md` — agent 读的常驻上下文（四家都读它）
- pi：`docs/skills.md`、`docs/configuration.md`（context files 与 `.pi`）、`docs/security.md`（project trust）
- Codex：<https://developers.openai.com/codex/skills>（.agents/skills 的扫描范围）
- Claude Code：<https://code.claude.com/docs/en/memory>（AGENTS.md 与 CLAUDE.md 的取舍）、<https://code.claude.com/docs/en/skills>（`.claude/skills` 与软链）
- agy：结论取自它二进制里的内置文档（“Customization Discovery and Locations”），未做本机实测
