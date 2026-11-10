# Shell 脚本规则

适用于 `repos/` 下所有含 `.sh` 的仓库。

## 改完 shell 脚本

在**仓库根**执行，只查本次变更的文件：

```bash
shellcheck -x $(git diff --name-only origin/master...HEAD -- <改动所在目录> | grep '\.sh$')
```

未安装：`brew install shellcheck`。

cwd 必须是仓库根：shellcheck 静态解析 `source "$root/scripts/lib/x.sh"` 时会丢掉变量、得到 `./scripts/lib/x.sh`，再相对 cwd 去找。在子目录跑会漏报 SC1091，得出假的通过。

只查变更文件。全仓 `git ls-files '*.sh'` 的历史告警不在改动范围内，不要顺手还债。

## 规则

- `cd` 一律 `cd ... || exit 1`，失败就停（SC2164）。
- 变量展开一律加引号，除非明确要分词（SC2086 / SC2046）。
- `A && B || C` 要么改成 `if`，要么把中间的失败显式处理；`|| true` 会把 `A` 的失败吞掉（SC2015）。
- 被 source 的库文件没有 shebang 是正常的，用 `# shellcheck shell=bash` 声明（SC2148）。
- 动态路径的 `source` 用 `# shellcheck source=/dev/null`；`disable=SC1091` 对 `-x` 无效。
- 抑制指令写在被抑制行**之前**，写在行尾会报 SC1126。
- 抑制要说明为什么（同一条注释里写清），不要静默屏蔽。

## 检查

```bash
shellcheck -x <变更的 .sh>   # 退出码 0 才算通过
```
