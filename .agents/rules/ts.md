# TypeScript 与前端规则

适用：改 `repos/` 下 TypeScript / 前端代码（React、Next、Vite 等）时读。

## 规则

1. 类型不逃逸：不写 `any`；确实未知的用 `unknown` 再收窄。需要压制时用 `@ts-expect-error` 并在同一行写清原因，不用 `@ts-ignore`（后者在错误消失后仍静默）。
2. `as` 断言只允许用在已校验的外部数据边界，并注明来源；不允许用它消掉编译器报错。
3. 导出的公共函数、hook、API 客户端显式写返回类型；组件内部可以靠推断。
4. 沿用仓库既有写法，不引入新范式：组件定义风格、样式方案（antd / Tailwind / CSS Module）、状态管理、路径别名，都按该仓库现状来，不新增第二套。
5. import 顺序交给 eslint 的排序规则，不手排；不手动改 lockfile，不切换包管理器（仓库有 `pnpm-lock.yaml` 就用 pnpm，有 `package-lock.json` 就用 npm）。
6. 副作用集中在 `useEffect` 且依赖数组写全；压制 `react-hooks/exhaustive-deps` 必须写明原因。
7. 面向用户的文案用中文且集中放置（i18n 或常量文件），不散落在组件里；内部错误、日志用英文。
8. 测试按 `.agents/rules/tests.md`。先确认该仓库有没有可跑的端到端（有 `e2e/` 且配置能跑通 spec 才算）：有就优先扩它；没有就不要在功能票里新建 Playwright 框架，验收走「构建 + 类型检查 + 按步骤走关键路径」的冒烟证据。组件测试只在 E2E 覆盖不到时写（Testing Library），不写快照测试。
9. 注释按 `.agents/rules/comments.md`：默认不写、英文优先。

## 检查

优先用仓库自己的 scripts，不自己拼参数；没有 scripts 时再退回下面的命令。

```bash
BASE=${BASE:-origin/main}

# 1) 类型
npx tsc --noEmit

# 2) lint / 单测（有就跑到）
npm run lint --if-present
npm run test --if-present

# 3) 端到端：仓库有可跑设施时才执行（例如在它自己的 e2e 目录下）
#    npx playwright test
#    没有就跳过，并在证据里写清用哪条冒烟命令代替：build + 起服务 + 走关键路径

# 4) 本次新增的类型逃逸与快照
git diff "$BASE"...HEAD -U0 -- '*.ts' '*.tsx' \
  | grep -E '^\+' | grep -E '\bany\b|@ts-ignore|toMatchSnapshot' || echo '(无新增)'
```

判定：1、2 必须通过；3 视仓库是否有端到端设施而定，没有时必须有冒烟证据；4 有输出时逐条核对，任何 `any` / `@ts-ignore` / 快照都必须有规则 1、8 允许的理由。
