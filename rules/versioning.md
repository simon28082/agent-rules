---
description: feature/fix/release 变更的版本号递增规范
alwaysApply: false
---
# 版本号规范

版本号格式统一使用 `major.minor.patch`。

## 递增策略
- 每次完成 feature 或 fix 后，必须在同一变更中更新项目版本号。
- 修复不改变外部契约的 bug：只增加 patch，`x.y.z -> x.y.(z+1)`。
- 增加向后兼容的 feature：增加 minor，并将 patch 归零，`x.y.z -> x.(y+1).0`。
- 引入已发布/稳定公共契约的重大破坏性变化：增加 major，并将 minor、patch 归零，`x.y.z -> (x+1).0.0`。
- 当前开发阶段的小范围 CLI 参数、导入规则、搜索行为或内部契约调整，即使不保留旧行为，也不自动等同于 major bump；默认按 feature 使用 minor bump，或按 bug fix 使用 patch bump。
- 准备提升到下一个 major 前，必须先说明影响范围和理由，并取得用户确认；用户明确要求 major bump 时除外。
- 若 feature/fix 不改变可发布包版本，必须在变更说明中明确说明不更新版本号的原因。
