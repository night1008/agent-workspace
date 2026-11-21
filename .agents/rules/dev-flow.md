# 开发流程

工作区原生开发流：按 `spec.md → plan.md → task.md → checklist.md → review.md` 顺序推进，全过程白盒记录进度，支持行内人工批注，重大分歧停下决策。

## 主链

```text
spec.md (需求与边界) 
  → plan.md (技术设计与切片) 
  → task.md (顺序任务编排) 
  → checklist.md (验收命令与证据) 
  → review.md (双轴独立审查)
```

| 阶段 | 交付物 | 核心内容 | 决策门（必须停下确认） |
| --- | --- | --- | --- |
| 1. 需求对齐 | `spec.md` | 业务目标、输入输出、明确不做的范围、**分阶段（Phase）交付目标** | 存在会导致返工的阻塞问题（0~3 个，带推荐默认值） |
| 2. 技术方案 | `plan.md` | 改动文件清单、函数与类型签名、**按 Phase 划分独立可交付/可验证的工程切片** | 涉及破坏性变更、非平凡架构取舍 |
| 3. 任务编排 | `task.md` | 顺序执行的 Task 列表（以「独立可交付与带验证命令」为边界） | 任务拆分完成后，确认执行顺序 |
| 4. 编码自验 | `checklist.md` | 每个 Task 配套 C1..Cn（可观察断言 + 验证命令） | 执行中既定假设失效时立即停下说明 |
| 5. 独立验收 | `review.md` | 依据 `.agents/rules/review.md` 执行双轴审查与裁决 | 同一 Task 审查失败连续累计 5 次时停下 |

## 人工批注与变更响应

文档中若出现类似 `<!-- review: ... -->` 的行内批注，属于最高优先级的人工修改意向。主 Agent 必须按以下闭环机制处理，严禁带着未处理批注向后推进：

1. **前置扫描**：在阶段流转（如方案转任务、任务转清单）与每次派工调度前，主 Agent 必须主动扫描 `.scratch/<repo>/<feature>/*.md` 中的 `<!-- review: ... -->`。
2. **停下标记**：一旦发现未响应批注，立即停止派工与推进；将 `progress.md` 状态置为 `BLOCKED: 响应批注 <内容>`。
3. **分析与级联调整**：深入分析批注诉求，就地修订被批注文档，并级联调整下游受影响的文档（例如方案修改选型，需同步调整任务拆解范围与验证清单）。
4. **汇报对齐**：向用户明确汇报批注分析结论与文档修订差异，在获得用户明确确认后，消解批注并将状态切回 `IN_PROGRESS` 继续推进。

## 进度记录看板

进度必须实时就地记录，禁止攒批回填：

1. **实时看板**：在 `.scratch/<repo>/<feature>/progress.md` 实时记录阶段流转与各 Task 状态（`PENDING`、`IN_PROGRESS`、`BLOCKED`、`DONE`）。其中 `<feature>` 目录名格式为 `YYYYMMDD-<slug>`（如 `20261121-gateway-mvp`），严禁使用无业务语义的占位符（如 `t1-`）。
2. **遇阻标记**：触发决策门或发现人工修改意见时，状态显式置为 `BLOCKED: 等待确认 <具体问题>`；解决后更新记录并切回 `IN_PROGRESS`。
3. **仓库归档**：全部通过后，在 `.agents/repos/<repo>/progress.md` 追加一行永久记录：
   `| <日期> | <feature> | <状态> | <票据> | <分支> |`

## 角色、派工与交付纪律

主会话只做编排，通过 Subagent 执行具体任务。

1. **主 Agent (Orchestrator)**：
   - 负责生成与维护五步文档及 `progress.md`；
   - 负责派工调度与决策门把控，**禁止直接编写业务代码**；
   - 严格遵循人工批注响应流程：流转与派工前必扫批注，有批注先分析、级联调整文档并汇报对齐，严禁直接派工。
2. **Worker (实现者)**：
   - 一个 Task 派一个 Worker，在当前分支顺序执行；
   - 仅传递当前 Task 指针、分支约定、`.agents/rules/tests.md` 的 TDD 要求与当前 Checklist 项；
   - 输出 `file-only` 写入 `.scratch/<repo>/<feature>/checklist.md`（或 `checklist-<task>.md`）。
3. **Reviewer (审查者)**：
   - Worker 结算后启动，只读权限，不写业务代码；
   - 独立运行当前 Task 清单中的命令，核验命令证据，依据 `.agents/rules/review.md` 产出裁决。
4. **审查失败与重试上限**：
   - Review 判定 FAIL 时，主 Agent 将确定性证据返回原 Worker 终端重派修复；
   - **连续重试上限为 5 次**，第 5 次仍失败开启决策门，停下等待人工介入。
5. **单任务原子提交与连续推进**：
   - **每个 Task 经 Reviewer 裁决 PASS 后，立即在目标业务仓库内生成一条对应 commit**（符合 `.agents/rules/commit-and-mr.md`）；
   - 提交完成后释放该 Task 的 worker 与 reviewer 资源；
   - **自主推进纪律**：任务计划已确认的前提下，只要无未消解批注、无决策门阻塞且审查 PASS，主 Agent 必须直接自主推进下一个 Task（起草 Checklist → 派工 Worker → 派工 Reviewer → 原子提交），**严禁每完成一个 Task 就停下向用户询问确认**。仅在触发决策门（连续 5 次 FAIL、既定假设失效、新发现人工批注）时才停下。

## 产物与路径隔离

业务仓库仅包含业务代码与测试；所有流程与中间产物留在工作区。

| 产物 | 存放位置 |
| --- | --- |
| 特性五步文档与看板 | `.scratch/<repo>/<feature>/{spec,plan,task,checklist,review,progress}.md` |
| 个人编排偏好与归档进度 | `.agents/repos/<repo>/{AGENTS.md,progress.md}` |
| 领域术语与决策记录 | `.agents/repos/<repo>/{GLOSSARY.md,docs/adr/}` |
| 跨仓库通用规则 | `.agents/rules/` |

## 会话原则

1. 始终在工作区根启动会话，禁止进入 `repos/<repo>` 启动。
2. 读业务代码补齐 `repos/<repo>/` 前缀，写个人流程文件必须使用工作区绝对路径。
