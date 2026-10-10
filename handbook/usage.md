# 使用

日常操作：加 skill、引第三方、加规则、接仓库，以及哪些内容是示例可以删。

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
`remove <name>` 只删软链。

- 更新用 `update`（先只看，再应用）：

```bash
./scripts/workspace.sh update            # 只读：fetch 后对比本地与上游，列出差异
./scripts/workspace.sh update --apply    # 应用：软链目标跟着变
```

`repos.tsv` 的第四列标仓库类型：留空 / `repo` 是业务仓库，完整克隆（要历史），更新走 `pull --ff-only`；`skill` 是 skill 源，只读工作树，所以 `clone` 用 `--depth 1`（`mattpocock-skills` 这样是 1.5M 而不是 3.2M），更新走 `fetch --depth 1` + `reset --hard`。

**为什么 skill 源用 reset 而不是 pull**：上游会不定期改写历史（squash 发布），浅克隆下 `pull` 会直接报 `Not possible to fast-forward`——这不是异常，是常态。skill 源对我们只读（软链改不了正文），所以 reset 是安全的；业务仓库则一律只 `pull --ff-only`，绝不 reset。两边有未提交改动时 `update` 会跳过并提醒。

为什么不用复制：软链只有一份真身，`git pull` 就是更新，也不会出现「仓库里是新版、全局是旧版」这种漂移。代价是**软链必须指向工作区内**（相对路径），所以上游仓库要 clone 到 `repos/` 并有 `repos.tsv` 登记——否则别人 clone 这个工作区只会拿到一堆坏链，`check` 会把它们报出来。

两个注意点：

- 上游 skill 的内容是**只读**的：要改就得改 `repos/<repo>` 里的文件（那就变成你对那个仓库的改动），或者在 `.agents/skills/` 里自研一个同名 skill。
- 上游 SKILL.md 里的调用写法是**上游自己的约定**（mattpocock/skills 的 CHANGELOG 写明：把 10 个 skill 的跨 skill 调用统一改成「call the Skill tool」，不用 `/skill` 式散文），在 pi / Codex 里语义不对，而软链改不了。所以 `grill-me` 这种只有一行正文的转发壳不链——它本来就依赖 `grilling`（上游文档也写了：单独装 `grill-me` 会没反应），用 `/skill:grilling` 就行。

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

`repos.tsv` 是**本机**清单，不进 git（`.gitignore` 里那行）；模板是 `repos.example.tsv`，`init` 缺文件时自动生成，`clone` 缺文件时报错并给出命令。所以团队共享的仓库清单要写进 `repos.example.tsv`——它跟着 git 走，别人 `init` 就得到同一份。

### 跨仓库任务怎么提交

一次任务可能横跨好几个仓库，但**提交必须一个仓库一个**：

```bash
git -C repos/svc-a add -A && git -C repos/svc-a commit -m "feat: ..."
git -C repos/svc-b add -A && git -C repos/svc-b commit -m "feat: ..."
```

工作区仓库自己的提交只含脚手架文件——`repos/*` 已在 `.gitignore` 里，嵌套仓库不会被记成 gitlink。所以**别以为在顶层 `git add -A` 就把业务改动提交了**，那只提交了脚手架。

`repos/` 下的目录不一定是 git 仓库：本地草稿、解压来的快照、纯资产目录都可以放，`clone` 与 `update` 会跳过它们（`check` 会把它标成“非 git 仓库”的提示，不算问题）。

### 拿脚手架自身的更新

`workspace.sh update` 只管 `repos/*`，不管脚手架本身。脚手架自己的更新取决于当初怎么建的：

| 当初怎么建 | 以后怎么拿更新 |
| --- | --- |
| **默认**：`git clone <模板>` + `git remote rename origin template` | `git fetch template && git merge template/main`——线性上游就是快进；冲突只会出现在你也改过的文件上 |
| **想要干净历史**：`gh repo create --template <模板>`，或事后 `rm -rf .git` | 文件级对比：`git clone --depth 1 <模板> /tmp/tpl && diff -ru --exclude=.git /tmp/tpl .`，手动挑 |

实测过的两种情形：浅克隆 + **线性**上游 → `git pull` 正常；上游**改写历史**（squash / force-push）→ `pull --ff-only` 报 `Not possible to fast-forward`，这时用 `git fetch --depth 1 && git reset --hard origin/main`（会覆盖本地对该文件的改动）。上游是 `repos/mattpocock-skills` 那种用 squash 发布的，就按后者处理，`update --apply` 里已经这么做了。

`repos.tsv` 从跟踪改成不跟踪（`chore(workspace)` 那次）会撞一次 `delete/modify` 冲突：上游删了它，而你本地改过。按这个顺序处理，别让它把本机清单带走：

```bash
cp repos.tsv /tmp/repos.tsv.bak
git fetch template && git merge template/main   # 冲突落在 repos.tsv
git rm -f repos.tsv                             # 接受上游的删除
git commit                                      # 完成合并
mv /tmp/repos.tsv.bak repos.tsv                 # 本机那份放回来（已在 .gitignore 里）
```

### 全局 skill ↔ 工作区 skill

- 全局：`~/.pi/agent/skills/`（所有项目都加载，脱离版本控制，换机器会丢）
- 工作区：`.agents/skills/`（只服务本工作区，跟着 git 走）

只有这个工作区用得上的，搬进工作区；写通用工具的，留在全局。**同名时工作区赢**——加载顺序是 项目 `.pi/skills` → 项目 `.agents/skills` → `~/.pi/agent/skills` → `~/.agents/skills`，先加载的胜出。所以同一份内容只留一处：搬进工作区就把全局那份删掉（否则全局那份只在其它目录生效），反之则别在仓库里放。

## 有哪些是示例（想清空就清空）

脚手架本身只有六件东西：`AGENTS.md`（+ `CLAUDE.md` 软链）、`repos.example.tsv`、`.agents/{rules,skills}/`、`.claude/skills`、`scripts/workspace.sh`。其余都是实例内容：

| 路径 | 是什么 | 不要了就 |
| --- | --- | --- |
| `.agents/skills/` 里的 9 个软链 | 订阅了 [mattpocock/skills](https://github.com/mattpocock/skills) 的一套开发流程 | `for s in …; do ./scripts/workspace.sh remove $s; done` |
| `repos.example.tsv` 里的 `mattpocock-skills` 行 | 上面那 9 个软链的目标 | 删掉那行（本机 `repos.tsv` 里同步删） |
| `.agents/rules/dev-flow.md` + `AGENTS.md` 路由表里对应那行 | 跟那套流程绑定的规则 | 两处一起删，别只删一个 |
| `.agents/rules/go.md` | 示例规则（Go 专用） | 删文件 + 删路由表那行 |
| `.agents/rules/{before-implementing,prompt-writing}.md` | 通用规则，可以留 | — |
| `.agents/rules/_template.md` | 新规则的模板 | 留着 |

第三方内容在本仓库一律以**软链订阅**的形式存在：本体在 `repos/`，`.agents/skills/` 只有相对软链，升级 = `git -C repos/<repo> pull`。
另一条路是**复制自持**（`cp -R` 进 `.agents/skills/`）：能改正文，代价是失去升级能力。上游自己也提供这两种形态（plugin 订阅 vs 安装器复制进项目）。
