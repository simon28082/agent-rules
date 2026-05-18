---
description: Node.js / TypeScript 语言与工具通用规范
globs:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
alwaysApply: false
---
# Node.js / TypeScript 通用规范

本文件定义 Node.js 与 TypeScript/JavaScript 层面的通用约束。仓库内更具体规则优先。

## 适用范围
- 默认遵循项目声明的 Node.js 版本；未声明时使用 Node.js 20+ LTS。
- 优先 TypeScript；新代码不写纯 JS，除非明确是配置或脚手架文件。
- 改动保持最小且局部，不顺手重构无关代码。

## 工作流程
- 编辑前先读相关文件。
- 行为不明时，先看现有实现并对齐。
- 新能力、破坏性变更、架构变化、规范工作按项目既有流程推进。
- 改动后跑最小相关验证（typecheck、lint、最贴近改动的测试），并报告跑了什么、没跑什么。

## 代码风格
- 遵循项目已有的格式化与 lint 规则（通常 Prettier + ESLint）。
- 命名显式；除非缩写已经是项目约定，否则不缩。
- 函数短小聚焦；嵌套过深用早返或提取函数。
- 注释只写非显而易见的意图、权衡或约束，不做复述。

## 类型
- 新增或显著修改的公开函数、导出类型、接口必须有类型。
- 启用严格模式（`strict`、`noUncheckedIndexedAccess` 等），禁用 `any` 泛滥；优先 `unknown` + 收窄。
- 面向边界数据（网络、存储、用户输入）使用 schema 校验器（Zod / Valibot / ArkType 之一，按项目已用为准）。
- 类型导入用 `import type`，与运行时导入分离。

## 导入与模块
- 使用 ESM（`import` / `export`）；除非项目历史要求，不再新增 CommonJS。
- 默认使用具名导出（named export），谨慎使用 default export。
- 除显式入口外不引入 import 期副作用。
- 避免循环依赖；共享逻辑下沉到更小的模块。

## 数据建模
- 数据形状用 `interface` 或 `type`，行为与状态绑定时才用类。
- 序列化、校验、业务逻辑尽量分离。
- 不可变优先：默认 `const`、`readonly`、不可变数组/对象操作。

## 错误与日志
- 抛具体错误类型；对边界异常做类型收窄（`error instanceof Error`），不吞异常。
- 错误信息要可定位原因。
- 用结构化日志，不在库或应用代码里留 `console.log`，除非是 CLI 或临时调试（调试后清理）。
- 不记录 secrets、token、密码、凭据原文。

## 异步与并发
- IO 优先 `async/await`，避免裸 Promise 链或回调。
- 不在异步路径里做同步阻塞（同步 IO、同步加密、`JSON.stringify` 超大对象等）。
- CPU 密集任务走 `worker_threads` 或独立服务，不阻塞事件循环。

## 测试
- 新行为与缺陷修复补或改测试。
- 测试确定性：避免真实网络、时间依赖、隐式全局状态。
- 测行为与契约，不测实现细节。
- 使用项目已选定的测试框架（Vitest / Jest / Playwright 等），不引入并行体系。

## 枚举与常量
- 固定取值的字段（type、status、level、role 等）优先使用 `as const` 字面量联合（`type X = typeof VALUES[number]`）。
- 不用散落的字符串字面量表达同一类取值。
- 不引入新的 TypeScript `enum`（尤其数字 enum），除非与既有契约强绑定。

## 依赖
- 内置能力够用就不引三方（原生 `fetch`、`URL`、`crypto.subtle`、`node:fs/promises` 等）。
- 需要三方能力时，优先使用成熟、活跃维护、周下载量稳定的主流库，不重复造轮子。
- 复用已有依赖，不引入近似重复包。
- 新增依赖必须说明价值是否覆盖其维护成本（bundle size、安全面、升级负担）。
