# 提交与 MR 规范

适用：在 `repos/<repo>/` 内提交 commit 或创建 MR/PR 之前读。

## 规则

1. **任务号提取**：任务号强制来自当前分支名 `t<编号>-<slug>`：
   ```bash
   git rev-parse --abbrev-ref HEAD | grep -Eo '^t[0-9]+'
   ```
   分支无任务号时停下向用户索取，禁止自行编造或省略。
2. **Commit 标题**：`<type>(<scope>): <中文描述> t<编号>`。类型前缀用英文，描述用中文。禁止在标题中使用 `-0`、`+∞` 等易混淆符号。
3. **Commit 正文**：除简单 typo / 单行修复外，强制填写正文。使用中文列表回答三要素：为什么改、改动影响面、验证方式与命令。
4. **Commit 正文禁止项**：禁止重复写任务号、禁止罗列改动文件清单、禁止流水账复述 diff。
5. **MR 标题与正文**：
   - 标题：以任务号结尾，格式与 Commit 标题一致。
   - 描述：分为「背景、改动点、验证方式、风险」四块；截图与长复现步骤放 MR 描述中。
6. **单一归属**：同一分支所有 commit 使用相同的尾部任务号，禁止混用多个任务号。

## 检查

```bash
branch=$(git rev-parse --abbrev-ref HEAD)
echo "$branch" | grep -Eq '^t[0-9]+' || echo "分支名未以任务号开头"
git log -1 --pretty=%s | grep -Eq 't[0-9]+$' || echo "最近一条 commit 未以任务号结尾"
git log -1 --pretty=%b | grep -q '[^[:space:]]' || echo "最近一条 commit 没有正文"
```
