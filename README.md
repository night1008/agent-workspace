# agent-workspace

多仓库工作区脚手架：业务仓库各自 clone 在 `repos/` 下，共享同一份 `AGENTS.md`、skills 和 rules。
在根目录启动一次 agent，「跨仓库」就只是普通的一次任务。

## 怎么用

```bash
# 开一个新工作区
git clone https://github.com/night1008/agent-workspace.git my-workspace && cd my-workspace
git remote rename origin template            # 模板留成上游：以后 git fetch template && git merge template/main 拿脚手架更新
git remote add origin <你自己的远端>          # 可选

cp repos.example.tsv repos.tsv   # 本机清单，不进 git（缺文件时 init 也会自动生成）
$EDITOR repos.tsv                # name <TAB> url <TAB> branch <TAB> kind（kind 留空 = 业务仓库，skill = skill 源）
./scripts/workspace.sh init      # 克隆 repos.tsv 里的仓库 + 自检，幂等
pi                            # 或 claude / codex / agy，都在这个目录启动
```

想要不带模板历史的干净副本：`gh repo create --template night1008/agent-workspace --private`（需装 `gh` 并登录 + 模板仓库勾了 Template repository），代价是以后只能靠文件对比拿更新，两种方式都写在 `handbook/usage.md` 的「拿脚手架自身的更新」里。

接手一个已存在的工作区就两步：`git clone <工作区 URL> <目录>` → `./scripts/workspace.sh init`（`repos.tsv` 不进 git，`init` 会用 `repos.example.tsv` 生成本机那份；团队共享的仓库清单写进 example，它才跟着 git 走）。
从别人的 fork 复制时，把上面的 `night1008/agent-workspace` 换成你正在看的那份。
没有安装步骤：`.claude/skills` 指向 `.agents/skills` 的软链跟着 git 走；第一次用 pi 会问一次 project trust（`.agents/skills` 属于 trust 相关资源）。

| 命令 | 干什么 |
| --- | --- |
| `init` | `clone` + `check`，新实例跑这个 |
| `clone` | 按 `repos.tsv` 克隆缺失的仓库（已存在的目录不动） |
| `check` | 自检：AGENTS.md、软链、skill 元数据、仓库清单（有问题退出码 1） |
| `new <name>` | 生成自研 skill 模板 |
| `add <repo> <路径>` | 把 `repos/<repo>` 里的 skill 软链进 `.agents/skills/` |
| `remove <name>` | 移除该软链（实体目录不动） |
| `update [--apply]` | 对比本地与上游；`--apply` 拉到最新（skill 源 reset，业务仓库只 fast-forward） |

任何命令都可加 `--dry-run`。

## 进一步阅读

**用这个工作区**（日常操作）：[`usage.md`](handbook/usage.md) — 新增 / 引入 skill、加规则、接仓库、清理示例内容；[`pitfalls.md`](handbook/pitfalls.md) — 已知的坑。

**改脚手架本身**（改目录结构、加载规则、方案取舍时才需要）：[`design.md`](handbook/design.md) — 三层资源模型、四个 CLI 从哪读、否决过哪些方案；各 CLI 的官方依据也在它末尾。
