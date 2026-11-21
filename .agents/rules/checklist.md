# 检查清单与裁决

适用：写规格或票据、派工给子 agent、或做验收裁决时读。微小改动（typo、单行修复）不走清单。

## 规则

1. **格式规范**：`- [ ] C<n> <可观察断言>｜证据：<命令>｜owner: dev|reviewer`。断言必须为可验证的客观结果，禁止主观定性描述。
2. **存放位置**：写入票据正文，工作区副本落 `.scratch/<repo>/<feature>/checklist.md`（或 `checklist-<task>.md`），禁止写入业务仓库。
3. **命令来源**：证据命令优先取自 `.agents/repos/<repo>/AGENTS.md` 中声明的验收口径。
4. **裁决格式**：
   - 首段：`## Verdict: PASS` 或 `## Verdict: FAIL`
   - 分项：`## Checks` 按 C1..Cn 给出 `PASS/FAIL + 命令 + 输出摘要`
   - 阻塞项：`## Blockers`（PASS 时填 `None`）
   - 编号必须与清单严格一致。
5. **一票否决**：任一项 FAIL 即整体裁决 FAIL。全项 PASS 且整体 PASS 视为完成。
6. **审查分流**：清单为闭合项逐条确认；`code-review` 发现的新问题追加为新清单项，禁止直接改判。
7. **修改权限**：清单由规格起草者制定；dev 禁止删项或改断言，reviewer 禁止直接私自加项。
8. **默认注释项**：代码任务必须包含：`新增注释为 0，或均为回答『为什么』的英文注释`，证据使用 `.agents/rules/comments.md` 检查命令，owner 为 dev。
9. **默认测试项**：代码任务必须包含：`新增测试全为端到端，或符合 tests.md 例外且无重复断言`，证据使用 `.agents/rules/tests.md` 检查命令，owner 为 dev。

## 检查

```bash
REPO=<repo>
F=<feature>

# 1) 清单与裁决编号一致性（差集为空即通过）
diff <(grep -o 'C[0-9]\+' .scratch/$REPO/$F/checklist*.md | sort -u) \
     <(grep -o 'C[0-9]\+' .scratch/$REPO/$F/verdicts/*.md | sort -u)

# 2) FAIL 项裁决一致性校验
grep -q 'FAIL' .scratch/$REPO/$F/verdicts/*.md && grep -q '## Verdict: FAIL' .scratch/$REPO/$F/verdicts/*.md
```
