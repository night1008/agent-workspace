# 提交与 MR 规范

适用：在 `repos/<repo>/` 内提交 commit 或创建 MR/PR 之前读。

## 规则

1. **任务号提取**：若分支名以任务号开头（如关联工单的 `t<编号>-<slug>`），从分支名提取：
   ```bash
   git rev-parse --abbrev-ref HEAD | grep -Eo '^t[0-9]+'
   ```
   若为常规特性分支（如 `YYYYMMDD-<slug>`），严禁人为编造无业务含义的占位编号（如 `t1-`），直接使用语义化描述。
2. **Commit 标题**：`<type>(<scope>): <中文描述>[ <任务号>]`。类型前缀用英文，描述用中文。有任务号时末尾空格追加，无任务号时不加。禁止在标题中使用 `-0`、`+∞` 等易混淆符号。
3. **Commit 正文**：除简单 typo / 单行修复外，强制填写正文。使用中文列表回答三要素：为什么改、改动影响面、验证方式与命令。
4. **Commit 正文禁止项**：禁止重复写任务号、禁止罗列改动文件清单、禁止流水账复述 diff。
5. **MR 标题与正文**：
   - 标题：与 Commit 标题格式一致。
   - 描述：分为「背景、改动点、验证方式、风险」四块；截图与长复现步骤放 MR 描述中。
6. **单一归属**：同一分支所有 commit 使用相同的尾部任务号（若有），禁止混用多个任务号。

## 检查

```bash
branch=$(git rev-parse --abbrev-ref HEAD)
ticket=$(echo "$branch" | grep -Eo '^t[0-9]+' || true)
if [[ -n "$ticket" ]]; then
  git log -1 --pretty=%s | grep -Eq "${ticket}$" || echo "最近一条 commit 未以任务号 ${ticket} 结尾"
fi
git log -1 --pretty=%b | grep -q '[^[:space:]]' || echo "最近一条 commit 没有正文"
```
