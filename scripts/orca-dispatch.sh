#!/usr/bin/env bash
# orca-dispatch.sh —— 把 Orca 编排里的固定步骤包成命令：Run / Task / Dispatch
#
# 用法：
#   orca-dispatch.sh init <feature> [--objective <text>]
#   orca-dispatch.sh dispatch <feature> <task-id> [--agent <id>] [--model <id>] [--effort <level>]
#                                              [--worktree current|new-top-level]
#                                              [--name <n>] [--repo <id:...>] [--base-branch <ref>]
#   orca-dispatch.sh doctor <feature>
#   orca-dispatch.sh status <feature>
#   orca-dispatch.sh close <feature>
#
# 约定：
#   - 状态只读 task-list / worker-list；不解析 worker-start 的返回（它不含 dispatch id）。
#   - 派工后必须 activity == working，否则视为未启动（input_accepted 不算）。
#   - 完成判据三条：Task 全部 completed、无可回收 worker、每个 task 都有 Verdict: PASS。
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH="${WS}/.scratch"

die()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
info() { printf '\033[2m·\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*" >&2; }

usage() { sed -n '2,/^set -/p' "${BASH_SOURCE[0]}" | sed -e '$d' -e 's/^# \{0,1\}//'; }

py_get() { # py_get <dotted.path>  —— 从 stdin 的 JSON 取值
  python3 -c '
import json, sys
path = sys.argv[1]
cur = json.load(sys.stdin)
for part in path.split("."):
    if cur is None:
        break
    if isinstance(cur, list):
        cur = cur[int(part)] if part.isdigit() and int(part) < len(cur) else None
    else:
        cur = cur.get(part)
print("" if cur is None else (json.dumps(cur, ensure_ascii=False) if isinstance(cur, (dict, list)) else cur))
' "$1"
}

read_run() {
  local f="${SCRATCH}/${1}/run"
  [[ -s "${f}" ]] || die "找不到 ${f}：先跑 orca-dispatch.sh init $1"
  cat "${f}"
}

# dispatchId taskId handle worktreeId dispatchStatus workerState outcome activity requiresAction
workers_tsv() {
  local run="$1"; shift || true
  orca orchestration worker-list --run "${run}" "$@" --json | python3 -c '
import json, sys
rows = json.load(sys.stdin)["result"].get("workers", [])
for w in rows:
    p = w.get("projection") or {}
    stage = p.get("stage") or {}
    att = p.get("attention") or {}
    print("\t".join(str(x) for x in [
        w.get("dispatchId", ""), w.get("taskId", ""),
        w.get("agentTerminalHandle") or "",
        (w.get("resource") or {}).get("worktreeId") or "",
        w.get("dispatchStatus", ""), w.get("workerState", ""),
        p.get("outcome", ""), stage.get("activity", ""),
        att.get("requiresAction"),
    ]))
'
}

# taskId status title
tasks_tsv() {
  orca orchestration task-list --run "$1" --json | python3 -c '
import json, sys
for t in json.load(sys.stdin)["result"].get("tasks", []):
    print("\t".join([t.get("id", ""), t.get("status", ""),
                     (t.get("title") or "").replace("\t", " ")]))
'
}

verdict_files() { # <feature> <run> —— 主 worktree 与各 worker worktree 的 verdict 都算
  local feature="$1" run="$2"
  local roots=("${SCRATCH}/${feature}") wt p
  while IFS=$'\t' read -r _d _t _h wt _; do
    [[ -n "${wt}" ]] || continue
    p="${wt#*::}"
    [[ -d "${p}" ]] && roots+=("${p}/.scratch/${feature}")
  done <<< "$(workers_tsv "${run}")"
  local r f
  for r in "${roots[@]}"; do
    for f in "${r}"/verdicts/*.md; do
      [[ -f "${f}" ]] && printf '%s\n' "${f}"
    done
  done | awk -F/ '!seen[$NF]++'
}

append_plan() {
  local plan="${SCRATCH}/${1}/plan.md"
  printf -- '- %s → %s @ %s (%s)\n' "$2" "$4" "${5:-<无 worktree>}" "$3" >> "${plan}"
}

cmd_init() {
  local feature="" objective=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --objective) objective="${2:-}"; shift 2 ;;
      -*) die "未知选项：$1" ;;
      *)  [[ -z "${feature}" ]] || die "多余参数：$1"; feature="$1"; shift ;;
    esac
  done
  [[ -n "${feature}" ]] || die "用法：orca-dispatch.sh init <feature> [--objective <text>]"

  local dir="${SCRATCH}/${feature}"
  mkdir -p "${dir}/briefs" "${dir}/reports" "${dir}/verdicts"

  if [[ -s "${dir}/run" ]]; then
    ok "已绑定 Run：$(cat "${dir}/run")"
    return 0
  fi

  local run
  run="$(orca orchestration run-create --objective "${objective:-${feature}}" --json | py_get result.run.id)"
  [[ -n "${run}" ]] || die "run-create 没有返回 run id"
  printf '%s\n' "${run}" > "${dir}/run"

  if [[ ! -f "${dir}/plan.md" ]]; then
    cat > "${dir}/plan.md" <<EOF
# ${feature}

Run: ${run}

## 任务图

（目标、依赖理由、每个 task 的验收判据；状态查 orca-dispatch.sh status）

## Dispatch 记录
EOF
  fi

  ok "Run 已绑定：${run}"
  info "目录：${dir}"
}

cmd_dispatch() {
  local feature="" task="" agent="codex" worktree="current" name="" repo="" base="" model="" effort=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent)       agent="${2:-}"; shift 2 ;;
      --model)       model="${2:-}"; shift 2 ;;
      --effort)      effort="${2:-}"; shift 2 ;;
      --worktree)    worktree="${2:-}"; shift 2 ;;
      --name)        name="${2:-}"; shift 2 ;;
      --repo)        repo="${2:-}"; shift 2 ;;
      --base-branch) base="${2:-}"; shift 2 ;;
      -*) die "未知选项：$1" ;;
      *)  if [[ -z "${feature}" ]]; then feature="$1"; elif [[ -z "${task}" ]]; then task="$1"; else die "多余参数：$1"; fi; shift ;;
    esac
  done
  [[ -n "${feature}" && -n "${task}" ]] || die "用法：orca-dispatch.sh dispatch <feature> <task-id> [选项]"

  local run; run="$(read_run "${feature}")"
  local args=(--task "${task}" --run "${run}" --agent "${agent}" --worktree "${worktree}")
  [[ -n "${name}" ]] && args+=(--name "${name}")
  [[ -n "${repo}" ]] && args+=(--repo "${repo}")
  [[ -n "${base}" ]] && args+=(--base-branch "${base}")
  [[ -n "${model}" ]] && args+=(--model "${model}")
  [[ -n "${effort}" ]] && args+=(--effort "${effort}")

  info "派工：task=${task} agent=${agent} worktree=${worktree}"
  local receipt="/tmp/orca-dispatch-receipt.json"
  if ! orca orchestration worker-start "${args[@]}" --json > "${receipt}" 2>&1; then
    warn "worker-start 失败。收据：${receipt}"
    head -c 1500 "${receipt}" >&2; printf '\n' >&2
    die "不要重跑；先读 failedStage / residualResources"
  fi

  local deadline=$(( SECONDS + 60 )) dispatch="" handle="" wt="" activity="" row=""
  while (( SECONDS < deadline )); do
    row="$(workers_tsv "${run}" | awk -F'\t' -v t="${task}" '$2 == t { print; exit }')"
    if [[ -n "${row}" ]]; then
      IFS=$'\t' read -r dispatch _ handle wt _ _ _ activity _ <<< "${row}"
      [[ -n "${dispatch}" ]] && break
    fi
    sleep 2
  done
  [[ -n "${dispatch}" ]] || die "60 秒内 worker-list 没有出现 task=${task} 的 dispatch 行（收据留在 ${receipt}）"

  ok "dispatch = ${dispatch}"
  info "terminal = ${handle:-<无>}"
  info "worktree = ${wt:-<无>}"
  append_plan "${feature}" "${task}" "${agent}${model:+/${model}}" "${dispatch}" "${wt}"

  if [[ "${activity}" != "working" ]]; then
    warn "activity=${activity:-?}：agent 可能停在 warning/权限菜单，未开始干活"
    warn "先 worker-read --dispatch ${dispatch} 确认，再 check --wait"
    return 2
  fi
  ok "activity = working"
}

cmd_doctor() {
  [[ -n "${1:-}" ]] || die "用法：orca-dispatch.sh doctor <feature>"
  local run; run="$(read_run "$1")"
  local rows; rows="$(workers_tsv "${run}")"
  if [[ -z "${rows}" ]]; then
    info "没有 dispatch 行"
    return 0
  fi

  local problems=0 dispatch task _handle _wt _dstatus _wstate outcome activity req
  while IFS=$'\t' read -r dispatch task _handle _wt _dstatus _wstate outcome activity req; do
    [[ -z "${dispatch}" ]] && continue
    [[ "${outcome}" == "in_progress" ]] || continue
    if [[ "${activity}" == "working" ]]; then
      ok "${task:-?} ${dispatch} activity=working"
    else
      warn "${task:-?} ${dispatch} activity=${activity:-?} requiresAction=${req:-?}"
      problems=$(( problems + 1 ))
    fi
  done <<< "${rows}"

  if (( problems > 0 )); then
    warn "${problems} 个 dispatch 未证明在干活，不要进入 check --wait"
    return 1
  fi
}

cmd_status() {
  [[ -n "${1:-}" ]] || die "用法：orca-dispatch.sh status <feature>"
  local feature="$1" allow="${2:-}" run dir
  run="$(read_run "${feature}")"
  dir="${SCRATCH}/${feature}"

  local total=0 completed=0 blocked=0 pending=0 failed=0 other=0 id status _title
  while IFS=$'\t' read -r id status _title; do
    [[ -z "${id}" ]] && continue
    total=$(( total + 1 ))
    case "${status}" in
      completed)     completed=$(( completed + 1 )) ;;
      blocked)       blocked=$(( blocked + 1 )) ;;
      failed)        failed=$(( failed + 1 )) ;;
      pending|ready) pending=$(( pending + 1 )) ;;
      *)             other=$(( other + 1 )) ;;
    esac
  done <<< "$(tasks_tsv "${run}")"

  local reclaimable=0
  reclaimable="$(workers_tsv "${run}" --terminal-state reclaimable | grep -c . || true)"

  local verdicts=0 pass=0 f
  while IFS= read -r f; do
    [[ -z "${f}" ]] && continue
    verdicts=$(( verdicts + 1 ))
    if grep -q 'Verdict: PASS' "${f}"; then pass=$(( pass + 1 )); fi
  done <<< "$(verdict_files "${feature}" "${run}")"

  printf 'Run       %s\n' "${run}"
  printf 'Task      %d 个：completed %d / blocked %d / failed %d / pending %d / 其他 %d\n' \
    "${total}" "${completed}" "${blocked}" "${failed}" "${pending}" "${other}"
  printf 'Worker    %d 个待回收\n' "${reclaimable}"
  printf 'Verdict   %d 个文件，%d 个 PASS\n' "${verdicts}" "${pass}"

  local fail=0
  if (( total == 0 )); then warn "还没有 Task"; fail=1; fi
  if (( completed != total )); then warn "Task 未全部 completed"; fail=1; fi
  if (( blocked > 0 )); then warn "${blocked} 个 blocked Task，需要决策门或改派"; fail=1; fi
  if (( failed > 0 )); then warn "${failed} 个 failed Task，需要改派或开决策门"; fail=1; fi
  if (( reclaimable > 0 )) && [[ "${allow}" != "allow-reclaimable" ]]; then
    warn "${reclaimable} 个 reclaimable worker 未处置"; fail=1
  fi
  if (( verdicts == 0 )); then warn "没有 verdict 文件，验收没做"; fail=1; fi
  if (( pass != verdicts )); then warn "有 ${verdicts} 个 verdict，其中仅 ${pass} 个 PASS"; fail=1; fi
  (( fail == 0 )) && ok "完成判据全部通过"
  return "${fail}"
}

cmd_close() {
  [[ -n "${1:-}" ]] || die "用法：orca-dispatch.sh close <feature>"
  local feature="$1" run
  run="$(read_run "${feature}")"

  if ! cmd_status "${feature}" allow-reclaimable; then
    warn "实质判据未过，先别收尾"
    return 1
  fi

  local rows; rows="$(workers_tsv "${run}")"
  if [[ -z "${rows}" ]]; then
    ok "没有 worker 行"
    return 0
  fi

  local dispatch task _h _wt dstatus _wstate _o _a _r printed=0
  while IFS=$'\t' read -r dispatch task _h _wt dstatus _wstate _o _a _r; do
    [[ -z "${dispatch}" ]] && continue
    [[ "${dstatus}" == "dispatched" ]] && continue
    printf 'orca orchestration worker-release --dispatch %s --json   # %s (%s)\n' \
      "${dispatch}" "${task:-?}" "${dstatus}"
    printed=$(( printed + 1 ))
  done <<< "${rows}"

  if (( printed == 0 )); then
    ok "没有待回收的 worker"
  fi
}

cmd="${1:-help}"; shift || true
case "${cmd}" in
  init)     cmd_init "$@" ;;
  dispatch) cmd_dispatch "$@" ;;
  doctor)   cmd_doctor "$@" ;;
  status)   cmd_status "$@" ;;
  close)    cmd_close "$@" ;;
  help|-h|--help) usage ;;
  *) die "未知子命令：${cmd}（用 --help 看用法）" ;;
esac
