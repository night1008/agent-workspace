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

## 开发一个需求

会话始终在工作区根开，别 `cd repos/<repo> && pi`（进去只剩用户级 skill）。

```text
只有一个模糊想法
  ↓ /skill:grill-with-docs      追问到能验收，术语进 GLOSSARY、决策进 ADR
  ↓ /skill:to-spec             锁成规格，进 issue tracker
  ↓ /skill:to-tickets          拆成 tracer-bullet 票据，带阻塞边
  ↓ 派 worker 实现             或 /skill:implement-spec；主会话只留指针
  ↓ 独立验收                   reviewer 给 pass / block，不过就回流
  ↓ 提交                       一个仓库一个提交
```

三条边界：

- **产物不进业务仓库**。票据、brief、report、verdict 落 `.scratch/<feature>/`；`GLOSSARY.md`、`docs/adr/`、tracker 配置落 `.agents/repos/<repo>/`。业务仓库只留代码和团队自己的文件；业务变动让团队的 `AGENTS.md` 过时就改它，随业务一起提交。
- **收尾必跑两件事**：`./scripts/workspace.sh check`（抓漏进业务仓库的流程产物）与 `git -C repos/<repo> add <显式路径>`（别用 `-A`）。
- **小改不走这套**。改名、typo、20 行以内且只有一种写法，直接做。
