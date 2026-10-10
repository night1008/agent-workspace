# agent-workspace

多仓库工作区：业务代码在 `repos/<repo>/`（各自独立的 git 仓库），跨仓库共享的配置在 `.agents/`。

## 地图

| 路径 | 是什么 |
| --- | --- |
| `repos/<repo>/` | 外部仓库的本地 checkout（业务仓库或 skill 源）；本仓库不跟踪其内容，用 `update` 拉最新 |
| `.agents/rules/` | 跨仓库规则，按需读取 |
| `.agents/skills/` | 跨仓库 skills，靠各自的 description 自动路由 |
| `repos.example.tsv` | 仓库清单模板（name / url / branch / kind 四列）；本机清单 `repos.tsv` 由它生成，不进 git |
| `scripts/workspace.sh` | init / clone / check / new / add / remove / update |
| `README.md`、`handbook/` | 面向人的脚手架说明；只在改工作区自身时读（`.ignore` 让 rg / fd 搜不到它们） |

## 开工

1. 先确定任务属于哪个 `repos/<repo>/`。
2. 读 `repos/<repo>/AGENTS.md`（存在时）。在根目录启动的会话不会自动加载它，需要显式读。
3. 按路由表读规则：

| 当你…… | 先读 |
| --- | --- |
| 做需求 / 设计 / 实现 / 测试（任何功能开发） | `.agents/rules/dev-flow.md` |
| 写或改 Go 代码 | `.agents/rules/go.md` |
| 写提示词、或评审一份需求 / 提示词 | `.agents/rules/prompt-writing.md` |
| 动手做一个非平凡改动之前 | `.agents/rules/before-implementing.md` |
| 新增一条跨仓库规则 | `.agents/rules/_template.md` |

## 约定

- 跨仓库的规则只写在 `.agents/rules/`；某个仓库自己的约定只写在该仓库的 `AGENTS.md`。同一条含义只保留一处。
- 新增共享 skill 用 `scripts/workspace.sh new <name>`；第三方 skill 用 `scripts/workspace.sh add <repo> <路径>` 软链进来（不复制，更新靠 `git -C repos/<repo> pull`）。两者都会被 pi、Codex、Claude Code 读到（`.claude/skills` 是指向 `.agents/skills` 的软链）。
- 仓库内的改动在仓库内提交：`git -C repos/<repo> ...`。本仓库的提交只包含工作区文件，`repos/*` 已 gitignore。
- 让你分析时只给分析：写代码等我明确说动手。
- 回复用中文，commit message 用中文（Conventional Commits 的类型前缀保留英文）。
