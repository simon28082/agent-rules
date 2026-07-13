---
title: 规则索引
apply: always
---
# 规则索引

本仓库是 human-maintained personal agent rules kit。具体工程规范由各规则文件承载，本文件只说明冲突顺序。

## 冲突顺序

- 用户当前明确指令优先。
- 仓库内更具体规则优先于本目录通用规则。
- 语言规则优先于 `rules/project.md` 与 `rules/response.md` 中的泛化工程约束。
- `rules/project.md` 优先于 `rules/response.md` 中同主题的泛化工程约束。
- Skill 规则优先于同主题的泛化任务建议。
- 规则缺失或冲突时，先说明依据与不确定性，再选择最小可维护方案。
