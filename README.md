# agent-workspace

多仓库工作区脚手架：业务仓库各自 clone 在 `repos/` 下，共享同一份 `AGENTS.md`、skills 和 rules。
在根目录启动一次 agent，「跨仓库」就只是普通的一次任务。

## 怎么用

```bash
git clone https://github.com/night1008/agent-workspace.git my-workspace && cd my-workspace
git remote rename origin template                   # 模板留成上游：git fetch template && git merge template/main
cp repos.example.tsv repos.tsv && $EDITOR repos.tsv  # name / url / branch / kind；本机清单，不进 git
./scripts/workspace.sh init                         # 克隆缺失仓库 + 自检，幂等
pi                                                  # 或 claude / codex / agy，都在这个目录启动
```

接手别人的工作区就一句 `./scripts/workspace.sh init`（团队共享的仓库清单写进 `repos.example.tsv` 才跟着 git 走）。其余看 `.agents/handbook/`：命令清单、加 skill、接仓库、坑；`./scripts/workspace.sh help` 列出全部命令。

## 开发一个需求

工作区根开会话，别进 `repos/<repo>`。细节见 `.agents/rules/dev-flow.md`。

```text
模糊需求
  → /skill:grill-with-docs
  → /skill:to-spec
  → /skill:to-tickets
  → 派 worker 实现（或 /skill:implement-spec）
  → 独立验收
  → 业务仓库内提交
```
