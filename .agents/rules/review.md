# 独立双轴审查规范

适用：独立审查代码变更、执行 Task 或 Feature 验收裁决时读。

## 核心纪律：FAIL 必须提供确定性证据

严禁给出无证据的模糊结论（如仅写「未通过」或「实现不符」）。任何判定为 FAIL 的检查项，必须提供以下三类客观证据之一：

1. **命令执行证据**：复跑的完整命令、非零退出码与原始终端错误输出片段；
2. **代码违规证据**：精确的文件路径、行号与提取出的违规 diff 代码片段；
3. **断言不符证据**：实际输出值与预期断言值的明确差异对照。

无客观证据的 FAIL 判定视为无效审查。

## 规则

1. **审查范围**：
   ```bash
   BASE=${BASE:-origin/main}
   git rev-parse --verify "$BASE" >/dev/null || exit 1
   git diff "$BASE"...HEAD --stat
   ```
2. **Standards 轴审查（规范红线）**：
   - **注释**：执行 `.agents/rules/comments.md` 检查命令，无新增显见注释，新增注释为纯英文且能回答「为什么」；FAIL 时贴出违规行与文件；
   - **测试**：执行 `.agents/rules/tests.md` 检查命令，新增测试均为端到端，或符合四类单测例外；FAIL 时贴出违规文件；
   - **语言**：按文件类型执行对应规则命令（`ts.md` 跑 `tsc --noEmit`、`go.md` 跑 `go test -race`、`shell.md` 跑 `shellcheck`）；FAIL 时贴出报错原文；
   - **提交**：执行 `.agents/rules/commit-and-mr.md` 检查命令，分支与 commit 标题带任务号，正文符合三要素。
3. **Spec 轴审查（需求与断言核验）**：
   - 只读模式下逐条独立复跑 `.scratch/<feature>/checklist.md` 中对应当前 Task 的命令；
   - 检查实际输出与预期断言是否严格一致；FAIL 时完整保留命令失败的输出。
4. **输出格式**：
   裁决写入 `.scratch/<feature>/review.md`（或子任务裁决文件）：

   ```markdown
   ## Verdict: PASS | FAIL

   ## Standards
   - 注释规范: PASS | FAIL
     - 证据: <无新增注释通过 | 违规 diff 代码与行号>
   - 测试规范: PASS | FAIL
     - 证据: <端到端用例列表 | 违规单测或重复断言>
   - 语言检查: PASS | FAIL
     - 证据: <执行命令及退出码 0 | 编译或 linter 报错片段>
   - 提交规范: PASS | FAIL
     - 证据: <符合规范的 commit message | 违规标题/正文>

   ## Checks (Spec)
   - C1: PASS | FAIL
     - 命令: <复跑命令>
     - 证据: <命令输出与断言对照>

   ## Blockers
   - None（若 PASS）
   - <阻断问题与精准修复指引，附带上述证据引用>（若 FAIL）
   ```

5. **裁决效力**：任一项 FAIL 即最终裁决 FAIL。全项 PASS 且证据链完整才判通过。
