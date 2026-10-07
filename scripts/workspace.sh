#!/usr/bin/env bash
# agent-workspace 维护脚本
#
#   ./scripts/workspace.sh init               新实例就绪：clone 缺失的仓库 + 自检
#   ./scripts/workspace.sh clone              按 repos.tsv 克隆缺失的仓库
#   ./scripts/workspace.sh check              自检：AGENTS.md、软链、skill 元数据、仓库清单
#   ./scripts/workspace.sh new <skill-name>   生成自研 skill 模板
#   ./scripts/workspace.sh add <repo> <repo 内路径> [--name <skill>]
#                                             把 repos/<repo> 里的 skill 软链进 .agents/skills/
#   ./scripts/workspace.sh remove <skill>     移除该软链（实体目录不动）
#   ./scripts/workspace.sh update [repo...]   对比本地与上游（只读）
#   ./scripts/workspace.sh update --apply     拉到上游最新（skill 源 reset，业务仓库只 fast-forward）
#
# 第三方 skill 一律用软链，不复制内容：更新就是 git -C repos/<repo> pull。
#
# 选项：--dry-run

set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPOS_DIR="${WS}/repos"
SHARED_SKILLS="${WS}/.agents/skills"
MANIFEST="${WS}/repos.tsv"

# 共享 skills 的对外入口。一次建好、跟着 git 走，不需要按仓库做任何事。
#   .agents/skills  pi 与 Codex 直接读这个目录
#   .claude/skills  Claude Code 只认这个位置，所以指回 .agents/skills
LINKS=".claude/skills"

DRY_RUN=0
ARGS=()
for a in "$@"; do
  if [[ "${a}" == "--dry-run" ]]; then DRY_RUN=1; else ARGS+=("${a}"); fi
done
set -- ${ARGS[@]+"${ARGS[@]}"}

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
skip() { printf '  \033[2m·\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }
title(){ printf '\n\033[1m%s\033[0m\n' "$*"; }
run()  { if [[ ${DRY_RUN} -eq 1 ]]; then printf '  \033[2m[dry-run] %s\033[0m\n' "$*"; else "$@"; fi; }

usage() { sed -n '2,/^set -/p' "${BASH_SOURCE[0]}" | sed -e '$d' -e 's/^# \{0,1\}//'; }

# ---------------------------------------------------------------- helpers

# relpath <target> <from-dir> → 相对路径（纯 bash，兼容 macOS bash 3.2）
relpath() {
  local target="${1%/}" from="${2%/}"
  local -a t=() f=() o=()
  local i=0 j
  IFS='/' read -r -a t <<< "${target#/}"
  IFS='/' read -r -a f <<< "${from#/}"
  while [[ ${i} -lt ${#t[@]} && ${i} -lt ${#f[@]} && "${t[${i}]}" == "${f[${i}]}" ]]; do
    i=$((i + 1))
  done
  for ((j = i; j < ${#f[@]}; j++)); do o+=(".."); done
  for ((j = i; j < ${#t[@]}; j++)); do o+=("${t[${j}]}"); done
  if [[ ${#o[@]} -eq 0 ]]; then echo "."; else (IFS='/'; echo "${o[*]}"); fi
}

# 共享 skill 目录名（排除 _ 开头的片段目录）
shared_skill_dirs() {
  local s
  for s in "${SHARED_SKILLS}"/*/; do
    [[ -d "${s}" ]] || continue
    printf '%s\n' "$(basename "${s}")"
  done | grep -v '^_' || true
}

real_dir() { (cd "$1" 2>/dev/null && pwd -P) || true; }

list_repo_dirs() {
  local d
  [[ -d "${REPOS_DIR}" ]] || return 0
  for d in "${REPOS_DIR}"/*/; do
    [[ -d "${d}" ]] || continue
    d="$(basename "${d}")"
    [[ "${d}" == .* ]] && continue
    echo "${d}"
  done
}

# repos.tsv 里查 url / branch / kind
manifest_lookup() { # <name>
  local n u b k
  [[ -f "${MANIFEST}" ]] || return 1
  while IFS=$'\t' read -r n u b k || [[ -n "${n:-}" ]]; do
    n="${n%%#*}"
    n="$(echo "${n}" | tr -d '[:space:]')"
    [[ -z "${n}" ]] && continue
    if [[ "${n}" == "$1" ]]; then
      u="$(echo "${u:-}" | tr -d '[:space:]')"
      b="$(echo "${b:-}" | tr -d '[:space:]')"
      k="$(echo "${k:-}" | tr -d '[:space:]')"
      printf '%s\t%s\t%s\n' "${u}" "${b}" "${k}"
      return 0
    fi
  done < "${MANIFEST}"
  return 1
}

# 仓库在 repos.tsv 里登记的分支（没登记就用当前分支）
repo_branch() { # <name>
  local lookup b
  if lookup="$(manifest_lookup "$1")"; then
    b="$(printf '%s' "${lookup}" | cut -f2)"
    if [[ -n "${b}" ]]; then printf '%s\n' "${b}"; return 0; fi
  fi
  git -C "${REPOS_DIR}/$1" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'main\n'
}

# 仓库类型：skill = 只读的 skill 源（可 reset），其他当业务仓库（只 pull --ff-only）
repo_kind() { # <name>
  local lookup k
  if lookup="$(manifest_lookup "$1")"; then
    k="$(printf '%s' "${lookup}" | cut -f3)"
    if [[ -n "${k}" ]]; then printf '%s\n' "${k}"; return 0; fi
  fi
  printf 'repo\n'
}

# clone_repo <url> <branch> <kind> <dest>
# kind=skill 表示只是 skill 源：只读工作树，不需要历史 → 浅克隆
clone_repo() {
  local url="$1" branch="$2" kind="$3" dest="$4"
  local -a flags=()
  if [[ "${kind}" == "skill" ]]; then flags+=(--depth 1); fi
  if [[ -n "${branch}" ]]; then flags+=(--branch "${branch}"); fi
  run git clone "${flags[@]}" "${url}" "${dest}"
}

# ---------------------------------------------------------------- commands

cmd_clone() {
  if [[ ! -f "${MANIFEST}" ]]; then die "找不到 ${MANIFEST}"; fi
  title "克隆 repos.tsv 中缺失的仓库"
  local name url branch kind target
  while IFS=$'\t' read -r name url branch kind || [[ -n "${name}" ]]; do
    name="${name%%#*}"
    name="$(echo "${name}" | tr -d '[:space:]')"
    url="$(echo "${url:-}" | tr -d '[:space:]')"
    branch="$(echo "${branch:-}" | tr -d '[:space:]')"
    kind="$(echo "${kind:-}" | tr -d '[:space:]')"
    [[ -z "${name}" ]] && continue
    if [[ -z "${url}" ]]; then warn "${name}: 清单里没有 url，跳过"; continue; fi
    target="${REPOS_DIR}/${name}"
    if [[ -d "${target}" ]]; then skip "${name}: 已存在"; continue; fi
    clone_repo "${url}" "${branch}" "${kind}" "${target}"
    ok "${name}: 已克隆${kind:+（kind=${kind}）}"
  done < "${MANIFEST}"
}

cmd_update() {
  local apply=0 wanted=() a repo dir branch kind dirty head_sha up_sha changed=0
  for a in "$@"; do
    case "${a}" in
      --apply) apply=1 ;;
      -*) die "未知选项：${a}" ;;
      *) wanted+=("${a}") ;;
    esac
  done

  local repos=()
  if [[ ${#wanted[@]} -gt 0 ]]; then
    repos=("${wanted[@]}")
  else
    while read -r a; do repos+=("$a"); done < <(list_repo_dirs)
  fi
  if [[ ${#repos[@]} -eq 0 ]]; then skip "repos/ 下没有仓库"; return 0; fi

  title "$(if [[ ${apply} -eq 1 ]]; then echo "拉到上游最新（会写文件）"; else echo "对比本地与上游（只读）"; fi)"

  for repo in "${repos[@]}"; do
    dir="${REPOS_DIR}/${repo}"
    if [[ ! -d "${dir}/.git" && ! -f "${dir}/.git" ]]; then warn "${repo}: 不是 git 仓库，跳过"; continue; fi
    branch="$(repo_branch "${repo}")"
    kind="$(repo_kind "${repo}")"
    dirty="$(git -C "${dir}" status --porcelain)"
    if [[ -n "${dirty}" ]]; then
      warn "${repo}: 有未提交改动，跳过（自己先处理）"
      changed=$((changed + 1))
      continue
    fi
    if [[ "${kind}" == "skill" ]]; then
      run git -C "${dir}" fetch --depth 1 --quiet origin "${branch}" || { warn "${repo}: fetch 失败"; changed=$((changed + 1)); continue; }
    else
      run git -C "${dir}" fetch --quiet origin "${branch}" || { warn "${repo}: fetch 失败"; changed=$((changed + 1)); continue; }
    fi
    head_sha="$(git -C "${dir}" rev-parse HEAD 2>/dev/null || true)"
    up_sha="$(git -C "${dir}" rev-parse "origin/${branch}" 2>/dev/null || true)"
    if [[ -z "${up_sha}" ]]; then warn "${repo}: 找不到 origin/${branch}"; changed=$((changed + 1)); continue; fi
    if [[ "${head_sha}" == "${up_sha}" ]]; then ok "${repo}: 已是最新（${head_sha:0:7}）"; continue; fi

    changed=$((changed + 1))
    warn "${repo}: ${head_sha:0:7} → ${up_sha:0:7}"
    git -C "${dir}" log --oneline -1 "origin/${branch}" | sed 's/^/      /'
    git -C "${dir}" diff --stat HEAD "origin/${branch}" 2>/dev/null | tail -1 | sed 's/^/      /'

    if [[ ${apply} -eq 1 ]]; then
      if [[ "${kind}" == "skill" ]]; then
        run git -C "${dir}" reset --hard "origin/${branch}" >/dev/null
        ok "${repo}: 已重置到上游（skill 源是只读的，上游改写历史也照这个处理）"
      else
        if run git -C "${dir}" pull --ff-only --quiet origin "${branch}"; then
          ok "${repo}: 已 fast-forward"
        else
          warn "${repo}: 不能 fast-forward（上游改写了历史，或本地有分叉）——手动处理"
        fi
      fi
    fi
  done

  printf '\n'
  if [[ ${changed} -eq 0 ]]; then
    ok "全部已是最新"
  elif [[ ${apply} -eq 1 ]]; then
    ok "已处理 ${changed} 个仓库"
  else
    warn "${changed} 个仓库可更新——确认后跑 update --apply"
  fi
}

cmd_init() {
  cmd_clone
  cmd_check
  printf '\n'
  printf '  下一步：\n'
  printf '    1) 编辑 repos.tsv 增删仓库（kind 留空 = 业务仓库，skill = skill 源）\n'
  printf '    2) ./scripts/workspace.sh clone   # 再拉一次新建的条目\n'
  printf '    3) pi                             # 或 claude / codex，都在这个目录启动\n'
}

cmd_add() {
  local repo="" path="" name="" lookup url branch kind dest target rel
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="${2:-}"; shift 2 ;;
      -*) die "未知选项：$1" ;;
      *)
        if [[ -z "${repo}" ]]; then repo="$1"
        elif [[ -z "${path}" ]]; then path="$1"
        else die "多余的参数：$1"
        fi
        shift ;;
    esac
  done
  if [[ -z "${repo}" || -z "${path}" ]]; then
    die "用法: workspace.sh add <repos 下的仓库名> <仓库内路径> [--name <skill-name>]"
  fi
  if [[ "${path}" == /* ]]; then die "<仓库内路径> 用相对路径，例如 skills/productivity/grilling"; fi

  if [[ -z "${name}" ]]; then name="$(basename "${path}")"; fi
  if [[ "${name}" == _* ]]; then die "下划线开头是片段目录专用，用 --name 换个名字"; fi

  title "链接 ${name}"
  if [[ ! -d "${REPOS_DIR}/${repo}" ]]; then
    if lookup="$(manifest_lookup "${repo}")"; then
      url="$(printf '%s' "${lookup}" | cut -f1)"
      branch="$(printf '%s' "${lookup}" | cut -f2)"
      kind="$(printf '%s' "${lookup}" | cut -f3)"
      [[ -z "${url}" ]] && die "repos.tsv 里 ${repo} 没有 url"
      warn "repos/${repo} 还没克隆，先从 repos.tsv 拉下来${kind:+（kind=${kind}）}"
      clone_repo "${url}" "${branch}" "${kind}" "${REPOS_DIR}/${repo}"
    else
      die "repos/${repo} 不存在，repos.tsv 里也没有它的 URL"
    fi
  fi

  target="${REPOS_DIR}/${repo}/${path}"
  dest="${SHARED_SKILLS}/${name}"
  if [[ ! -d "${target}" ]]; then die "${target} 不存在"; fi
  if [[ ! -f "${target}/SKILL.md" ]]; then die "${path} 里没有 SKILL.md，不是 skill 目录"; fi
  if [[ -e "${dest}" || -L "${dest}" ]]; then die "${dest} 已存在（要换目标先 remove ${name}）"; fi

  rel="$(relpath "${target}" "${SHARED_SKILLS}")"
  run ln -s "${rel}" "${dest}"
  ok "${name} -> ${rel}"
  echo
  echo "只在本地生效的下一步：./scripts/workspace.sh check"
  echo "更新内容：git -C repos/${repo} pull（软链目标会跟着变）"
}

cmd_remove() {
  local name="${1:-}" dest
  [[ -n "${name}" ]] || die "用法: workspace.sh remove <skill-name>"
  dest="${SHARED_SKILLS}/${name}"
  if [[ -L "${dest}" ]]; then
    run rm "${dest}"
    ok "已移除软链 ${name}"
  elif [[ -d "${dest}" ]]; then
    warn "${name} 是实体目录（自研 skill），不在这里删"
  else
    warn "${name} 不存在"
  fi
}

cmd_check() {
  local name url branch repo repo_dir rel resolved target_dir
  local skill_dir skill_md fm_name desc problems=0
  local seen_names=" " s linked_target linked_real linked_repo linked_rev

  title "工作区"
  if [[ -s "${WS}/AGENTS.md" ]]; then ok "AGENTS.md 非空"; else warn "AGENTS.md 为空"; problems=$((problems + 1)); fi
  if [[ -d "${SHARED_SKILLS}" ]]; then ok ".agents/skills 存在"; else warn ".agents/skills 缺失"; problems=$((problems + 1)); fi

  target_dir="$(real_dir "${SHARED_SKILLS}")"
  for rel in ${LINKS}; do
    resolved="$(real_dir "${WS}/${rel}")"
    if [[ -z "${resolved}" ]]; then
      warn "${rel} 缺失——Claude Code 看不到共享 skills，跑：ln -s ../.agents/skills ${rel}"
      problems=$((problems + 1))
    elif [[ "${resolved}" == "${target_dir}" ]]; then
      ok "${rel} -> .agents/skills"
    else
      warn "${rel} 指向 ${resolved}，不是 .agents/skills"
      problems=$((problems + 1))
    fi
  done

  title "软链的 skill"
  local n_links=0
  # 这里用不带斜杠的 glob：坏链也要能被列出来（带斜杠的 glob 会跳过它们）
  for linked_real in "${SHARED_SKILLS}"/*; do
    if [[ ! -L "${linked_real}" ]]; then continue; fi
    n_links=$((n_links + 1))
    name="$(basename "${linked_real}")"
    linked_target="$(readlink "${linked_real}")"
    if [[ ! -d "${linked_real}" || ! -f "${linked_real}/SKILL.md" ]]; then
      warn "${name} -> ${linked_target} 是坏链（目标不存在或没有 SKILL.md）——先看 repos/ 里那个仓库在不在，不在就跑 clone"
      problems=$((problems + 1))
      continue
    fi
    linked_real="$(real_dir "${linked_real}")"
    linked_repo="$(printf '%s' "${linked_real#${WS}/repos/}" | cut -d/ -f1)"
    linked_rev="$(git -C "${REPOS_DIR}/${linked_repo}" rev-parse --short HEAD 2>/dev/null || true)"
    ok "${name} -> ${linked_target}（${linked_repo}@${linked_rev:-?}）"
  done
  if [[ ${n_links} -eq 0 ]]; then skip "还没有软链进来的第三方 skill"; fi

  title "共享 skills 元数据"
  for skill_dir in "${SHARED_SKILLS}"/*/; do
    [[ -d "${skill_dir}" ]] || continue
    name="$(basename "${skill_dir}")"
    if [[ "${name}" == _* ]]; then skip "${name}: 片段目录，不当作 skill"; continue; fi
    skill_md="${skill_dir}/SKILL.md"
    if [[ ! -f "${skill_md}" ]]; then
      warn "${name}: 缺少 SKILL.md（不会被加载）"
      problems=$((problems + 1))
      continue
    fi
    if ! head -1 "${skill_md}" | grep -qx -- '---'; then
      warn "${name}: SKILL.md 没有 frontmatter"
      problems=$((problems + 1))
      continue
    fi
    fm_name="$(sed -n '2,/^---$/p' "${skill_md}" | grep -m1 '^name:' | sed 's/^name:[[:space:]]*//')"
    desc="$(sed -n '2,/^---$/p' "${skill_md}" | grep -m1 '^description:' | sed 's/^description:[[:space:]]*//')"
    if [[ -z "${desc}" ]]; then warn "${name}: 缺少 description（不会被加载）"; problems=$((problems + 1)); fi
    if [[ -n "${fm_name}" && "${fm_name}" != "${name}" ]]; then warn "${name}: frontmatter name 是 ${fm_name}，与目录名不一致"; fi
    case "${seen_names}" in
      *" ${fm_name} "*) warn "skill 名冲突：${fm_name}"; problems=$((problems + 1)) ;;
      *) if [[ -n "${fm_name}" ]]; then seen_names="${seen_names}${fm_name} "; fi ;;
    esac
    if [[ -n "${desc}" ]]; then ok "${name}"; fi
  done

  title "仓库"
  while read -r repo; do
    repo_dir="${REPOS_DIR}/${repo}"
    if [[ ! -d "${repo_dir}" ]]; then warn "${repo}: 目录不存在"; problems=$((problems + 1)); continue; fi
    if [[ -e "${repo_dir}/AGENTS.md" ]]; then
      ok "${repo}: 自带 AGENTS.md（顶层会话不会自动加载它，根 AGENTS.md 已内置「先读它」）"
    else
      skip "${repo}: 无自带 AGENTS.md"
    fi
  done < <(list_repo_dirs)

  title "repos.tsv 与磁盘"
  if [[ -f "${MANIFEST}" ]]; then
    while IFS=$'\t' read -r name url branch || [[ -n "${name:-}" ]]; do
      name="${name%%#*}"
      name="$(echo "${name}" | tr -d '[:space:]')"
      [[ -z "${name}" ]] && continue
      if [[ -d "${REPOS_DIR}/${name}" ]]; then ok "${name}: 已就位"; else skip "${name}: 尚未克隆"; fi
    done < "${MANIFEST}"
  fi

  printf '\n'
  if [[ ${problems} -eq 0 ]]; then ok "自检通过"; else warn "${problems} 处待处理"; exit 1; fi
}

cmd_new() {
  local name="${1:-}" dir
  [[ -n "${name}" ]] || die "用法: scripts/workspace.sh new <skill-name>"
  [[ "${name}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "skill 名用「小写字母/数字/连字符」，例如 feature-spec"
  [[ "${name}" != _* ]] || die "下划线开头是片段目录专用，换个名字"
  dir="${SHARED_SKILLS}/${name}"
  [[ -e "${dir}" ]] && die "${dir} 已存在"
  run mkdir -p "${dir}"
  if [[ ${DRY_RUN} -eq 0 ]]; then
    cat > "${dir}/SKILL.md" <<EOF
---
name: ${name}
description: <做什么>；当 <什么场景> 时使用。
---

# ${name}

## 步骤

1.

## 完成标准

- output=<产物路径>
EOF
  fi
  if [[ ${DRY_RUN} -eq 1 ]]; then ok "将生成 ${dir}/SKILL.md"; else ok "已生成 ${dir}/SKILL.md"; fi
  echo
  echo "description 决定模型什么时候读这份 skill：写清「做什么 + 什么场景」，不要写「帮助处理 X」。"
  echo "接着跑：./scripts/workspace.sh check"
}

# ---------------------------------------------------------------- main

cmd="${1:-help}"
shift || true

case "${cmd}" in
  init)   cmd_init ;;
  clone)  cmd_clone ;;
  check)  cmd_check ;;
  new)    cmd_new "$@" ;;
  update) cmd_update "$@" ;;
  add)    cmd_add "$@" ;;
  remove) cmd_remove "$@" ;;
  help|-h|--help) usage ;;
  *) die "未知命令：${cmd}（试试 help）" ;;
esac
