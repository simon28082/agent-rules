# Agent Rules

Human-maintained personal agent rules kit.

## Source Layout

```text
rules/      Source rules with platform-agnostic frontmatter
skills/     Portable workflow skills
scripts/    Build and install commands
dist/       Generated artifacts, ignored by git
```

## Source Format

Each rule file uses a simple frontmatter:

```yaml
---
title: 规则名称
apply: always                          # 始终加载
---
```

```yaml
---
title: 规则名称
match: ["**/*.go", "**/go.mod"]        # 按 glob 条件加载
---
```

## Commands

Build inspectable artifacts:

```bash
bash scripts/build.sh
```

Install for Cursor:

```bash
bash scripts/install.sh cursor
```

Install for OpenCode:

```bash
bash scripts/install.sh opencode
```

Install for Antigravity:

```bash
bash scripts/install.sh antigravity
```

Install commands run build first. Repeated installs update in place.

## Source vs Runtime

Source files keep repository-relative paths and platform-agnostic frontmatter. Build transforms them into each agent's native format. Install places them in each agent's global config location.

## Cursor Runtime

`bash scripts/install.sh cursor` writes:

```text
~/.cursor/rules/agent-rules-*.mdc
~/.cursor/skills/<skill>/SKILL.md
```

Rules use Cursor's `.mdc` format with `alwaysApply` and `globs` for conditional loading. Old `agent-rules-*.mdc` and legacy `personal-agent-*.mdc` files are removed before install.

## opencode Runtime

`bash scripts/install.sh opencode` writes:

```text
~/.config/opencode/instructions.md    (managed block injected)
~/.config/opencode/rules/languages/   (conditional rule files)
~/.config/opencode/skills/<skill>/SKILL.md
```

Always-loaded rules are merged into a single `<!--agent-rules:begin/end-->` block in `instructions.md`. Conditional rules are referenced via routing instructions. User content in `instructions.md` outside the managed block is preserved.

## Antigravity Runtime

`bash scripts/install.sh antigravity` writes:

```text
~/.gemini/config/instructions.md      (managed block injected)
~/.gemini/config/rules/languages/     (conditional rule files)
~/.gemini/config/skills/<skill>/SKILL.md
```

Same structure as opencode, adapted for Antigravity's global config path.
