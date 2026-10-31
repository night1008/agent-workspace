#!/usr/bin/env bash
# worktree-setup.sh —— 把新建的 agent-workspace worktree 变成可用环境
#
#   ./scripts/worktree-setup.sh            引导当前 worktree：补齐 repos.tsv + clone 缺失仓库 + 自检
#   ./scripts/worktree-setup.sh --help     打印本说明
#
# 固定三步，幂等：
#   [1/3] 定位主 checkout：git rev-parse --git-common-dir 得到公共 .git 目录，其父目录即主 checkout。
#         当前目录就是主 checkout 时直接成功退出，什么都不做。
#   [2/3] 当前目录缺 repos.tsv 时，从主 checkout 复制真实清单（已有的清单不覆盖、不重写）。
#   [3/3] ./scripts/workspace.sh clone、check；任一失败以非零退出并打印失败的步骤名。
#
# 非交互：不读标准输入，任意 cwd 下调用都按 workspace 根执行。

set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Orca 的 setup 跑在没有终端的会话里：git 缺凭据时会尝试交互式提问并挂死，直接让它失败。
export GIT_TERMINAL_PROMPT=0

usage() { sed -n '2,/^set -/p' "${BASH_SOURCE[0]}" | sed -e '$d' -e 's/^# \{0,1\}//'; }

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
note() { printf '  \033[2m·\033[0m %s\n' "$*"; }
step() { printf '\n\033[1m[%s]\033[0m %s\n' "$1" "$2"; }
die()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# 主 checkout 的物理路径（-C 保证任意 cwd 下都问同一个仓库）
main_checkout() {
  local common
  common="$(git -C "${WS}" rev-parse --git-common-dir 2>/dev/null)" || return 1
  case "${common}" in
    /*) ;;
    *) common="${WS}/${common}" ;;
  esac
  (cd "${common}/.." && pwd -P)
}

case "${1:-}" in
  "") ;;
  -h|--help) usage; exit 0 ;;
  *) die "未知选项：$1（试试 --help）" ;;
esac

step "1/3" "定位主 checkout"
main="$(main_checkout)" || die "[1/3] 定位主 checkout 失败：${WS} 不是 git 仓库"
ws_phys="$(cd "${WS}" && pwd -P)"
if [[ "${main}" == "${ws_phys}" ]]; then
  ok "当前目录就是主 checkout，无需引导：${main}"
  exit 0
fi
ok "主 checkout：${main}"

step "2/3" "补齐 repos.tsv"
if [[ -f "${WS}/repos.tsv" ]]; then
  note "repos.tsv 已存在，保留不动"
else
  [[ -f "${main}/repos.tsv" ]] || die "[2/3] 主 checkout 没有 repos.tsv：${main}/repos.tsv（先在主 checkout 造好真实清单）"
  cp "${main}/repos.tsv" "${WS}/repos.tsv"
  ok "已从主 checkout 复制 repos.tsv"
fi

step "3/3" "clone 缺失仓库并自检"
cd "${WS}"
./scripts/workspace.sh clone < /dev/null || die "[3/3] workspace.sh clone 失败（上面列出的仓库没能拉下来）"
./scripts/workspace.sh check < /dev/null || die "[3/3] workspace.sh check 失败（上面标了待处理项）"
ok "worktree 已就绪：${WS}"
