# Agent Rules

Human-maintained personal agent rules kit.

## Source Layout

```text
rules/      Source rules and routing table
skills/     Portable workflow skills
scripts/    Build and install commands
dist/       Generated artifacts, ignored by git
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

Install for Codex:

```bash
bash scripts/install.sh codex
```

Install commands run build first.

## Source vs Runtime

Source files keep repository-relative paths. Runtime files are generated during install and may use agent-specific absolute paths or config registration.

## Cursor Runtime

`bash scripts/install.sh cursor` writes:

```text
~/.cursor/rules/agent-rules-*.mdc
~/.cursor/skills/<skill>/SKILL.md
```

Before copying generated files, install removes old `agent-rules-*.mdc` and legacy `personal-agent-*.mdc` files from the Cursor rules directory.
Installed skills are marked with `.agent-rules-managed`; future installs remove stale marked skills before copying the current `dist/cursor/skills` set.

## Codex Runtime

`bash scripts/install.sh codex` writes:

```text
~/.codex/skills/agent-rules/SKILL.md
~/.codex/skills/agent-rules/rules/**/*.md
~/.codex/skills/<workflow-skill>/SKILL.md
~/.codex/config.toml
```

Before copying generated skills, install removes the legacy `agent-rules-bootstrap` skill and its config block if present.
Installed skills are marked with `.agent-rules-managed`; future installs remove stale marked skills and their Codex config blocks before copying the current `dist/codex/skills` set.
