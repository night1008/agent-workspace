# Orca 编排

适用：主 agent 派工给子 agent 开发、由另一个 agent 独立验收、结果回流主 agent 直到全部完成时读。单个小改动直接做，不走编排。

## 规则

1. 主 agent 只编排：建 Run、建 Task、派 Dispatch、判裁决、路由修复；不写业务代码。
2. review-only 的 `worker_done` 只授权综合结论，不授权主 agent 改代码；修复必须派回 dev。
3. reviewer 与 dev 共用同一个 worktree 且只读；同一 worktree 只允许一个写者。
4. dev 的验收必须是可执行命令；review 的裁决必须是 `## Verdict: PASS|FAIL` 加命令证据，不接受模糊结论。
5. 派工后必须确认 agent 真的在干活：`projection.stage.activity` 为 `working`，或 transcript 出现 agent turn。`input_accepted`、`turnStart: unsupported`、`requiresAction: false` 都不是启动证据。存活看 `projection.liveness.verdict`：`exited` 是已经没了，`unverifiable` 只是没证据、不等于死了；`worker-show` 的 `observation.status` 只是 PTY 存活，终端活着也可能坐着卡死或已退出的 agent。
6. 模型：`--model` 只对 claude、codex、cursor、antigravity、muse、omp、opencode 有效，且不能与 `--terminal` 同用；pi、zcode 等不支持，模型来自自身配置（pi 见 `~/.pi/agent/settings.json`）。是否生效只看 `projection.provider.model` 或回执的 `launch.effective`，不看传了什么参数。
7. 长 prompt 注入会退化成 `[paste #N +M lines]` 占位符，worker 拿不到正文。spec 写短；完整规格让 worker 用 `orca orchestration task-list --run <run> --json` 自取。
8. worker 的 `.scratch/<feature>/` 落在它自己的 worktree 里，主 agent 要去那个 worktree 读；`scripts/orca-dispatch.sh status|close` 已经这样查。
9. 一个 feature 一个 Run；`--deps` 只编码真依赖（review 依赖 dev），review 必须等 dev 结算后再 `worker-start`。
10. 起任务：依赖已满足的 dev task 一次起满并行跑，不等整批结算——谁先结算就派它的 review；某条依赖结算解开下一个 task，就立刻补进来，按连续补位收口而不是分批收口。FAIL 用 `worker-start --terminal <dev handle>` 复用 dev 终端修复。
11. Task 被 stop 后会变 `blocked`，不能直接重派：先 `task-update --status failed`，再 `worker-start --task <id> --retry-of <旧 dispatch>`，并重述 placement 与 agent。
12. 完成判据三条（`status` 已实现）：Task 全部 `completed`；`worker-list --terminal-state reclaimable` 为空；verdict 文件至少一个且全部 PASS。
13. `worker-stop` 返回 `stop_unknown`（退出 1）时进程未证明退出，禁止 release；先看回执的 `processAction`：为 `closed_agent_terminal` 表示 Orca 已关终端，不要再跑 `terminal close`，否则显式 `terminal close` 并在报告里说明是取消而非 release。
14. 同一 Task 失败两次开 `gate-create` 决策门，不自动重试第三次。
15. 新 worktree 缺 `repos/` 与 `repos.tsv`，先跑 `scripts/worktree-setup.sh`；不要拿 `scripts/workspace.sh check` 当通用验收门槛。

## 检查

```bash
bash -n scripts/orca-dispatch.sh
./scripts/orca-dispatch.sh doctor <feature>   # 派工后确认 agent 真在干活
./scripts/orca-dispatch.sh status <feature>   # 三条完成判据，非零即未完成
./scripts/orca-dispatch.sh close <feature>    # 实质判据通过后列出待 release 的 dispatch
```

命令用法以 `orca skills get orchestration` 为准；非 Orca 终端拿不到该指南时不要猜 flag，停下报告。
