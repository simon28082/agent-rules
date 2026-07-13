# Unified Rule Build — Personal Agent Rules Kit

## Problem

Personal agent rules (`rules/`) are authored in a format tied to Cursor (`.mdc` frontmatter conventions). Other agents — Codex, OpenCode — cannot consume them directly. Build and install scripts lack a generic abstraction: they hardcode target-specific transformations inline, making extension brittle.

## Goal

A single source of truth (`rules/*.md` with canonical frontmatter) that builds into agent-native formats for Cursor and OpenCode. Install is idempotent — re-running install replaces managed content without touching user additions.

Out of scope: Codex support, project-level rules, version negotiation.

## Source Rule Format

Each file under `rules/` is Markdown + optional YAML frontmatter. Frontmatter is limited to flat `key: value` pairs — no nesting, no multi-line values.

```yaml
---
title: Python 规范
apply: always
match: "**/*.py"
---
```

| Field | Semantics | Values |
|-------|-----------|--------|
| `title` | Rule name | Any string |
| `apply` | Load strategy | `always` or absent |
| `match` | Auto-match glob | Glob pattern like `**/*.py`. Ignored if `apply: always` |

Validation rules:
- `apply: always` + `match` both present → build error.
- No frontmatter or empty `---` shell → plain markdown file, referenced only via index.

## Platform Mapping

### Cursor (`.mdc`)

| Source | Cursor frontmatter |
|--------|--------------------|
| `title: Python 规范` | `description: Python 规范` |
| `apply: always` | `alwaysApply: true` (no `globs`) |
| `match: "**/*.py"` | `globs: ["**/*.py"]` (no `alwaysApply`) |
| No frontmatter | `alwaysApply: false`, no `globs` |

Filename: `agent-rules-<slug>.mdc` (unchanged from current convention).

### OpenCode (`.md`)

Rules are output as flat Markdown (no frontmatter) into `dist/opencode/`:

```
dist/opencode/
  instructions.md       ← apply:always rules, block-wrapped
  rules/                ← match rules, with text hint
    python.md
    nodejs.md
    go.md
  skills/               ← copied as-is
```

Transform rules:

| Source | OpenCode output |
|--------|-----------------|
| `title` | `# title` heading |
| `apply: always` | Included in `instructions.md` |
| `match: **/*.py` | Included in `rules/python.md`. First line: `> 此规则适用于 Python 项目（\`**/*.py\`）` |
| `---` frontmatter | Stripped entirely |

## Block Markers for `instructions.md`

All `apply:always` rules are merged into a single block delimited by HTML comments:

```markdown
<!--agent-rules:begin-->
# 回复与工作规范

内容...

# 项目基础规范

内容...
<!--agent-rules:end-->
```

Block semantics:
- Install script finds `<!--agent-rules:begin-->` … `<!--agent-rules:end-->` and replaces the entire block with new content.
- If the block does not exist in the target file, it is appended at the end.
- Content outside the block is never touched — users can add their own notes above or below.

## Build Pipeline (`build.sh`)

```
1. Walk rules/*.md
2. Parse frontmatter (line-based: detect ---, read key: value until next ---)
3. Per rule:
   a. Cursor: emit .mdc with mapped frontmatter
   b. OpenCode: if apply:always → append to instructions.md block
                if match → emit rules/<name>.md with text hint
                strip frontmatter in both cases
4. Copy skills/ to both targets
5. Self-check: file count, absolute paths in dist
```

## Install Pipeline (`install.sh`)

| Target | Destination |
|--------|-------------|
| `cursor` | `~/.cursor/rules/` (unchanged) |
| `opencode` | `~/.config/opencode/instructions.md` — block replace or append |
| | `~/.config/opencode/rules/*.md` — overwrite |
| | `~/.config/opencode/skills/` — overwrite with managed marker |

`install.sh opencode` uses the block markers for `instructions.md`:
1. Read target file.
2. Scan for `<!--agent-rules:begin-->` … `<!--agent-rules:end-->`.
3. If found → replace block content.
4. If not found → append new block to end.
5. Write back.

User must configure `~/.config/opencode/opencode.json` once:
```jsonc
{
  "instructions": [
    "~/.config/opencode/instructions.md",
    "~/.config/opencode/rules/*.md"
  ]
}
```
This is not automated — the user owns their opencode.json.

## Out of Scope (Phase 1)

- Codex target (deferred)
- Project-level rules
- Rule dependency/ordering
- Version detection in block markers
- Uninstall logic (rm -rf the managed markers/dirs is sufficient)
