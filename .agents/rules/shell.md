# Shell 脚本规范

适用于 `repos/` 下所有包含 `.sh` 的仓库。

## 规则

1. **执行边界**：在目标仓库根目录执行检查，且仅检查当前变更的文件：
   ```bash
   shellcheck -x $(git diff --name-only origin/master...HEAD -- <改动目录> | grep '\.sh$')
   ```
2. **退出防御**：`cd` 命令必须带失败中断：`cd ... || exit 1`（SC2164）。
3. **变量防分词**：变量展开一律用双引号包裹，显式分词除外（SC2086 / SC2046）。
4. **控制流严谨**：禁止使用吞掉失败的 `A && B || C`，显式使用 `if` 分支（SC2015）。
5. **库文件声明**：被 source 的无 shebang 库文件，在文件头声明 `# shellcheck shell=bash`（SC2148）。
6. **动态引用处理**：动态路径 source 使用 `# shellcheck source=/dev/null`。
7. **精准抑制**：警告抑制指令必须放在目标行上方，且必须在同一行注释说明原因，禁止全局静默屏蔽。

## 检查

```bash
shellcheck -x <变更的 .sh>   # 退出码 0 为通过
```
