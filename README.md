# agent-workspace

多仓库工作区脚手架：业务仓库各自 clone 在 `repos/` 下，共享同一份 `AGENTS.md`、skills 和 rules。
在根目录启动一次 agent，「跨仓库」就只是普通的一次任务。

## 怎么用

```bash
git clone https://github.com/night1008/agent-workspace.git my-workspace && cd my-workspace
git remote rename origin template            # 模板留成上游：以后 git fetch template && git merge template/main 拿脚手架更新
git remote add origin <你自己的远端>          # 可选

cp repos.example.tsv repos.tsv   # 本机清单，不进 git（缺文件时 init 也会自动生成）
$EDITOR repos.tsv                # name <TAB> url <TAB> branch <TAB> kind（kind 留空 = 业务仓库，skill = skill 源）
./scripts/workspace.sh init      # 克隆 repos.tsv 里的仓库 + 自检，幂等
pi                               # 或 claude / codex / agy，都在这个目录启动
```

接手别人的工作区：`git clone <工作区 URL> <目录>` → `./scripts/workspace.sh init`（团队共享的仓库清单写进 `repos.example.tsv`，它才跟着 git 走）。

没有安装步骤——`.claude/skills` 的软链跟着 git 走，第一次用 pi 会问一次 project trust。

其余写在 `.agents/handbook/`：命令清单与备选建仓方式、加 skill / 接仓库（`usage.md`）、坑（`pitfalls.md`）、改脚手架（`design.md`）。`./scripts/workspace.sh help` 列出全部命令。
