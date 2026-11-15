# 检查清单与裁决

适用：写规格或票据、派工给子 agent、或做验收裁决时读。typo、单行修复这类小改动不用清单。

## 规则

1. 清单项格式固定：`- [ ] C<n> <可观察断言>｜证据：<命令>｜owner: dev|reviewer`。三要素缺一不可；断言必须是可观察结果，「代码清晰」「结构合理」不算。
2. 清单随票据走：出票时写进票据正文，本地副本落该 feature 的临时目录，与 brief / report / verdict 同级。不写进业务仓库。
3. 仓库级验收口径写在该仓库的个人配置里（`.agents/repos/<repo>/AGENTS.md`），列出必跑命令与「什么算证据」；清单里的证据命令默认从这里取。
4. 裁决格式固定：首段 `## Verdict: PASS` 或 `## Verdict: FAIL`；`## Checks` 按 C1..Cn 逐条给 PASS/FAIL + 命令 + 输出摘要；`## Blockers` 在 PASS 时写 None。裁决的编号集合必须与清单一致。
5. 任一项 FAIL 即整体 FAIL，不允许「大部分通过所以算过」。完成判据 = 清单全项 PASS 且整体裁决 PASS。
6. 清单是闭合式逐条确认，`code-review` 是开放式第二意见。code-review 发现清单外的问题，追加为新清单项，不直接改判。
7. 清单由写规格的人起草，派工时原样带过去；dev 不得删项或改断言，reviewer 不得私自加项（要加走规则 6）。
8. 涉及代码的票据默认带一条注释项：断言是「新增注释为 0，或每条都是英文且能回答『不写会怎样误解』」，证据用 `.agents/rules/comments.md` 的检查命令，owner 是 dev。写规格时不要省掉这条。
9. 涉及代码的票据默认带一条测试项：断言是「新增测试全部为端到端，或对得上 `.agents/rules/tests.md` 规则 2 的四类例外，且无与既有测试重复的断言」，证据用该规则的检查命令，owner 是 dev。

## 检查

```bash
# 清单编号与裁决编号必须一致（列出两边差集，空即通过）
F=<feature>
diff <(grep -o 'C[0-9]\+' .scratch/$F/checklist-*.md | sort -u) \
     <(grep -o 'C[0-9]\+' .scratch/$F/verdicts/*.md | sort -u)

# 有 FAIL 项时整体裁决必须也是 FAIL
grep -q 'FAIL' .scratch/$F/verdicts/*.md && grep -q '## Verdict: FAIL' .scratch/$F/verdicts/*.md
```
