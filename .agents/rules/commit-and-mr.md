# 提交与 MR 规范

适用：在 `repos/<repo>/` 里写 commit message、开 MR/PR 之前。

## 规则

1. **任务号从分支名取**，不要自己编排。`repos/<repo>/` 的工作分支是 `t<编号>-<slug>` 形态（如 `t217244-skill-security`），开头的飞书任务号就是唯一来源：

   ```bash
   git rev-parse --abbrev-ref HEAD | grep -Eo '^t[0-9]+'
   ```

2. **commit message 以任务号结尾**：`<type>(<scope>): <中文描述> t<编号>`，形如 `fix(web): 修复分布分析零值分桶重复导致的面板查询越界 t217244`。类型前缀保留英文、描述用中文，沿用 `AGENTS.md` 的既有约定。标题用中文说清现象，不写 `-0`、`+∞` 这类符号（会被读成减号或运算符）。
3. **MR 标题也以任务号结尾**，形如 `fix(web): 修复分布分析零值分桶重复导致的面板查询越界 t217244`；描述正文不再重复写任务号。
4. 一个分支的多条 commit 用同一个尾部任务号，不混入第二个号。
5. 分支上没有任务号（`master`、`backup/*`、`mr-*` 这类）时先问用户要任务号，不要用其它编号替代，也不要省略。

## 检查

```bash
branch=$(git rev-parse --abbrev-ref HEAD)
echo "$branch" | grep -Eq '^t[0-9]+' || echo "分支名未以任务号开头"
git log -1 --pretty=%s | grep -Eq 't[0-9]+$' || echo "最近一条 commit 未以任务号结尾"
```
