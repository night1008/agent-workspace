# 开发流程

主流程基于 [mattpocock/skills](https://github.com/mattpocock/skills)，软链在 `.agents/skills/`，源码在 `repos/mattpocock-skills`。更新执行 `git -C repos/mattpocock-skills pull`。

## 主链

```text
grill-with-docs → to-spec → to-tickets → implement-spec（内含 tdd 与 code-review）
```

| 阶段 | 命令 | 产出 |
| --- | --- | --- |
| 仓库初始化 | `clone` 自动跑 `repo-init` | tracker 与领域文档配置落 `.agents/repos/<repo>/docs/agents/` |
| 对齐与定术语 | `/skill:grill-with-docs` | 就地更新术语与决策 |
| 输出规格 | `/skill:to-spec` | 规格录入 issue tracker |
| 拆解任务 | `/skill:to-tickets` | 任务票据与依赖图 |
| 实现与验证 | `/skill:implement-spec` | 业务代码与测试（内部调用 `tdd`、`code-review`） |

初始化命令：

```bash
./scripts/workspace.sh repo-init <repo> [--tracker github|gitlab|local] [--domain single|multi]
```

## 会话与路径约束

1. **唯一启动点**：始终在工作区根启动会话，禁止在 `repos/<repo>` 内启动。
2. **读操作**：补齐 `repos/<repo>/` 前缀。
3. **写操作**：个人流程产物使用工作区绝对路径，禁止污染业务仓库。
4. **交接差异**：上游 skill 提及的 `Call the Skill tool with "tdd"` 统一转换为「读取 `.agents/skills/<name>/SKILL.md` 并执行」。

## 产物分布

业务仓库只提交代码与公共事实；编排与个人流程文件留在工作区。

| 产物 | 存放位置 |
| --- | --- |
| 规格 / 票据 | GitHub / GitLab issues，或本地 `.scratch/<feature>/` |
| 检查清单与报告 | `.scratch/<feature>/{checklist-*,briefs,reports,verdicts}/` |
| 领域术语与 ADR | `.agents/repos/<repo>/{GLOSSARY.md,GLOSSARY-MAP.md,docs/adr/}` |
| Tracker / 流程配置 | `.agents/repos/<repo>/docs/agents/` |
| 个人编排偏好与进度 | `.agents/repos/<repo>/{AGENTS.md,progress.md}` |
| 跨仓库规则 | `.agents/rules/`（在根 `AGENTS.md` 注册路由） |
| 临时笔记 / handoff | 系统临时目录 |

## 任务派工规范

主会话只做编排，通过 Subagent 执行具体任务。单个任务派工包含五项：

1. **执行者**：`agent: "worker"`。
2. **工作目录**：`cwd: "repos/<repo>"`，在当前分支顺序执行，不建 worktree。
3. **输出模式**：`outputMode: "file-only"`，写入绝对路径 `.scratch/<feature>/<ticket>.md`。
4. **任务内容**：仅传递 ticket 引用、分支约定、遵循 `.agents/rules/tests.md` 的 TDD 要求及检查清单；禁止粘贴长代码。
5. **规则上下文**：显式传入相关规则的绝对路径（根与仓库的 `AGENTS.md`，以及适用的语言/测试规范）。

执行纪律：
- 严格单写者：一次派一个，顺序推进，禁止跨任务并行写。
- 收尾验收：先跑检查清单逐条确认（见 `.agents/rules/checklist.md`），再执行 `code-review` 作为第二意见。
