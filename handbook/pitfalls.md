# 已知的坑

这些是踩过或验证过的，撞上时按这里排。

- **skills 的发现会在 git 仓库根停下**（四家都一样），所以不要在 `repos/<repo>/` 里启动：那里的会话看不到顶层 `.agents/skills`。例外：agy 的规则（`AGENTS.md`、`.agents/rules/*.md`）是按你正在改的文件分层加载的，改到 `repos/<repo>/` 里的文件时会自动带上那仓库自己的 `AGENTS.md`。
- **`repos/<repo>` 自己的 `AGENTS.md` 不会在顶层会话里自动加载**（context 文件只从 cwd 往上找，不往下）。根 `AGENTS.md` 里写着「开工前先读它」。
- **`.claude/skills` 是相对软链**（`../.agents/skills`），整个工作区搬目录不会断；`check` 会验证它是否仍然指向 `.agents/skills`。
- **`CLAUDE.md` 必须是指向 `AGENTS.md` 的软链**：换成实体文件就有两份要各自维护，两边会漂移；`check` 会把它当待处理项报出来，改回 `ln -sfn AGENTS.md CLAUDE.md` 即可。
- **skill 目录内的 `.gitignore` / `.ignore` / `.fdignore` 会把 skill 从加载列表里排除掉**（pi 会读它们）。仓库根的 `.gitignore` 不影响加载。
- **`.agents/skills/` 顶层的 `.md` 会被当作 skill 加载**（没有 `description` 的静默跳过），子目录里的 `.md` 不会。所以辅助片段放进子目录（如 `_shared/`），文档放 `.agents/rules/`。
- **project trust 按最近的父目录生效**：给工作区根做过一次 trust，`repos/*` 全部继承，不会再逐仓库询问。`--no-approve` 会跳过 `.pi/*` 和 `.agents/skills`，但 `AGENTS.md` 照常加载。
- 根目录里运行的扩展（如 pi-rewind）会在工作区自动提交；`repos/*` 已 gitignore，业务仓库不会被卷进来。
