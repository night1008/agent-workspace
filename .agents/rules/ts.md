# TypeScript 与前端规范

适用：修改 `repos/` 下 TypeScript / 前端代码（React、Next、Vite 等）时读。

## 规则

1. **类型零逃逸**：严禁使用 `any`，未知类型使用 `unknown` 收窄。必须压制时使用 `@ts-expect-error` 并附带原因，禁止使用 `@ts-ignore`。
2. **断言约束**：`as` 断言仅限用于已校验的外部边界输入，禁止用于消解编译器类型错误。
3. **接口显式返回**：导出的公共函数、Hook、API 客户端必须显式声明返回类型；内部实现使用推断。
4. **既有范式优先**：严格沿用目标仓库现有的组件风格、样式方案（Tailwind / CSS Modules / UI 库）、状态库与路径别名，禁止引入第二套范式。
5. **包管理器锁定**：严格匹配锁文件（`pnpm-lock.yaml` → `pnpm`，`package-lock.json` → `npm`），严禁混用包管理器或手动修改 lockfile。
6. **副作用纯净**：副作用集中于 `useEffect` 且依赖项写全，禁止无故压制 `react-hooks/exhaustive-deps`。
7. **文案语言**：用户可见文案使用中文且集中存放在常量或 i18n 配置中；内部日志与错误一律使用英文。
8. **测试与快照**：禁止快照测试。按 `.agents/rules/tests.md` 执行，无可用 E2E 设施时走冒烟命令证据，禁止无授权搭建测试框架。

## 检查

```bash
BASE=${BASE:-origin/main}

# 1) 类型检查
npx tsc --noEmit

# 2) Lint 与测试
npm run lint --if-present
npm run test --if-present

# 3) 检查新增的类型逃逸与快照
git diff "$BASE"...HEAD -U0 -- '*.ts' '*.tsx' \
  | grep -E '^\+' | grep -E '\bany\b|@ts-ignore|toMatchSnapshot' || echo '(无新增)'
```

判定：1、2 必须通过；若 3 存在新增项，任一无合规理由即判 FAIL。
