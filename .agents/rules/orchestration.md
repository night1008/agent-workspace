# Orca 编排

适用：主 agent 派工给子 agent 开发、由另一个 agent 独立验收、结果回流主 agent 直到全部完成时读。单个小改动直接做，不走编排。

## 规则

1. 主 agent 只编排：建 Run、建 Task、派 Dispatch、判裁决、路由修复；不写业务代码。
2. review-only 的 `worker_done` 只授权综合结论，不授权主 agent 改代码；修复必须派回 dev。
3. dev 与 reviewer 都在目标仓库当前分支：reviewer 只读，同一分支只允许单一写者。
4. 验收命令化：dev 验收必须提供可执行命令；review 裁决按 `.agents/rules/checklist.md` 逐条提供命令证据与 PASS/FAIL。
5. 存活判定：启动证据只认 `projection.stage.activity` 为 `working` 或 transcript 出现 agent turn；存活证据只认 `projection.liveness.verdict`（`exited` 判定死亡）。禁止将 PTY 状态（`observation.status`）作为存活依据。
6. 模型生效：只看 `projection.provider.model` 或回执的 `launch.effective`。`--model` 禁止与 `--terminal` 混用；pi/zcode 等不支持命令行传参的模型在自身配置中指定。
7. 派工 spec 保持简短：禁止长文注入。完整规格让 worker 执行 `orca orchestration task-list --run <run> --json` 获取。
8. 产物路径：派工时传入工作区绝对路径 `.scratch/<feature>/{briefs,reports,verdicts}/`，禁止写入业务仓库。
9. 依赖约束：一个 feature 一个 Run。review 必须显式声明依赖 dev，且必须在 dev 结算后启动 `worker-start`。
10. 顺序单写者：一次只派一个 dev task（默认当前分支）；结算后派对应 review，PASS 后才派下一个。
    - 修复：FAIL 时使用 `worker-start --terminal <dev handle>` 复用原 dev 终端。
    - 释放：review PASS 后立即 `worker-release` 当前 task 的 dev 与 review，禁止提前或延后批量释放。
11. 重派中止的任务：Task 处于 `blocked` 时，先执行 `task-update --status failed`，再执行 `worker-start --task <id> --retry-of <旧 dispatch>` 重述 placement 与 agent。
12. 完成判据：Task 全部 `completed`；`worker-list --terminal-state reclaimable` 为空；verdict 文件至少一个、全部 PASS 且清单无 FAIL 项。
13. 异常中止：`worker-stop` 返回 `stop_unknown`（退出码 1）时禁止 release。根据 `processAction` 处置：为 `closed_agent_terminal` 时不再操作；否则执行 `terminal close` 并在报告中标记为取消。
14. 决策门：同一 Task 失败两次调用 `gate-create` 开决策门，禁止自动重试第三次。
15. 运行模式：默认在当前分支顺序执行，不使用 worktree。若启用新 worktree，必须先运行 `scripts/worktree-setup.sh` 补齐环境。

## 检查

```bash
bash -n scripts/orca-dispatch.sh
./scripts/orca-dispatch.sh doctor <feature>   # 派工后确认 agent 处于 working 状态
./scripts/orca-dispatch.sh status <feature>   # 三条完成判据，非零即未完成
./scripts/orca-dispatch.sh close <feature>    # 实质判据通过后列出待 release 的 dispatch
```

命令用法以 `orca skills get orchestration` 为准；非 Orca 终端拿不到该指南时停下报告，禁止盲猜 flag。
