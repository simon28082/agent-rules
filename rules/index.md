---
description: AI 规则索引与按需加载说明
alwaysApply: true
---
# 规则索引

本仓库是 human-maintained personal agent rules kit。`rules/index.md` 只说明规则选择，不承载具体工程规范；实际回复与执行要求始终以 `rules/response.md` 为基础，代码与项目改动的基础工程约束始终以 `rules/project.md` 为基础。

## 始终加载

- `rules/response.md`：所有任务的沟通、证据、执行、验证与安全约束。
- `rules/project.md`：跨语言项目基础工程规范，覆盖代码组织、错误日志、测试、依赖、安全、版本号、CLI 等通用约束。

## 按需加载

- `rules/languages/nodejs.md`：涉及 JavaScript、TypeScript、Node.js、React/TSX、前端构建、npm/pnpm/yarn/bun 生态时加载。
- `rules/languages/python.md`：涉及 Python 代码、脚本、包管理、测试、CLI、数据处理时加载。
- `rules/languages/go.md`：涉及 Go 代码、Go modules、并发、测试、CLI、`go.mod` / `go.sum` 时加载。
- `skills/code-verified-design/SKILL.md`：涉及架构/设计文档、从代码验证设计、重建旧设计、核心流程图、时序图、模块 walkthrough 时加载。

## 冲突顺序

- 用户当前明确指令优先。
- 仓库内更具体规则优先于本目录通用规则。
- 语言规则优先于 `rules/project.md` 与 `rules/response.md` 中的泛化工程约束。
- `rules/project.md` 优先于 `rules/response.md` 中同主题的泛化工程约束。
- Skill 规则优先于同主题的泛化任务建议。
- 规则缺失或冲突时，先说明依据与不确定性，再选择最小可维护方案。
