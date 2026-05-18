#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"

rule_runtime_name() {
  local relative="$1"
  local without_prefix="${relative#rules/}"
  local without_ext="${without_prefix%.md}"
  local slug="${without_ext//\//-}"

  if [[ "$relative" == "rules/index.md" ]]; then
    printf 'agent-rules-index.mdc'
  else
    printf 'agent-rules-%s.mdc' "$slug"
  fi
}

collect_rule_paths() {
  (
    cd "$ROOT"
    find rules -type f -name '*.md' | LC_ALL=C sort
  )
}

count_files() {
  local directory="$1"
  local name_pattern="$2"

  find "$directory" -type f -name "$name_pattern" | wc -l | tr -d ' '
}

replace_all_literal() {
  local content="$1"
  local pattern="$2"
  local replacement="$3"

  while [[ "$content" == *"$pattern"* ]]; do
    content="${content%%"$pattern"*}$replacement${content#*"$pattern"}"
  done

  printf '%s\n' "$content"
}

rewrite_rule_links_for_cursor() {
  local content="$1"
  local relative runtime pattern replacement skill_name

  while IFS= read -r relative; do
    [[ -n "$relative" ]] || continue
    runtime="$(rule_runtime_name "$relative")"
    pattern="\`$relative\`"
    replacement="\`$runtime\`"
    content="$(replace_all_literal "$content" "$pattern" "$replacement")"
  done < <(collect_rule_paths)

  if [[ -d "$ROOT/skills" ]]; then
    for skill_dir in "$ROOT"/skills/*; do
      [[ -d "$skill_dir" ]] || continue
      skill_name="$(basename "$skill_dir")"
      pattern="\`skills/$skill_name/SKILL.md\`"
      replacement="\`$skill_name\`"
      content="$(replace_all_literal "$content" "$pattern" "$replacement")"
    done
  fi

  printf '%s\n' "$content"
}

rm -rf "$DIST"
mkdir -p "$DIST/cursor/rules" "$DIST/cursor/skills" "$DIST/codex/skills/agent-rules"

cursor_index="$(<"$ROOT/rules/index.md")"
rewrite_rule_links_for_cursor "$cursor_index" > "$DIST/cursor/rules/agent-rules-index.mdc"

while IFS= read -r relative; do
  [[ -n "$relative" ]] || continue
  [[ "$relative" != "rules/index.md" ]] || continue
  cp "$ROOT/$relative" "$DIST/cursor/rules/$(rule_runtime_name "$relative")"
done < <(collect_rule_paths)

if [[ -d "$ROOT/skills" ]]; then
  cp -R "$ROOT/skills/." "$DIST/cursor/skills/"
fi

{
  printf '%s\n' '---'
  printf '%s\n' 'name: agent-rules'
  printf '%s\n' 'description: Load personal agent rules. Use at the start of every conversation or task before answering, planning, editing, reviewing, committing, or invoking other task-specific skills.'
  printf '%s\n' '---'
  printf '%s\n\n' '# Agent Rules'
  printf '%s\n\n' 'This skill bundles the source rules for Codex runtime. Follow `rules/index.md` routing semantics and avoid loading unrelated language rules.'

  while IFS= read -r relative; do
    [[ -n "$relative" ]] || continue
    printf '## %s\n\n' "$relative"
    printf '%s\n\n' "$(<"$ROOT/$relative")"
  done < <(collect_rule_paths)
} > "$DIST/codex/skills/agent-rules/SKILL.md"

cp -R "$ROOT/rules" "$DIST/codex/skills/agent-rules/rules"

if [[ -d "$ROOT/skills" ]]; then
  cp -R "$ROOT/skills/." "$DIST/codex/skills/"
fi

{
  printf '{\n'
  printf '  "repo": ".",\n'
  printf '  "cursor": {\n'
  printf '    "rules": [\n'

  first=1
  while IFS= read -r relative; do
    [[ -n "$relative" ]] || continue
    if [[ "$first" -eq 0 ]]; then
      printf ',\n'
    fi
    first=0
    printf '      "dist/cursor/rules/%s"' "$(rule_runtime_name "$relative")"
  done < <(collect_rule_paths)

  printf '\n'
  printf '    ],\n'
  printf '    "skills": [\n'
  printf '      "dist/cursor/skills/*/SKILL.md"\n'
  printf '    ]\n'
  printf '  },\n'
  printf '  "codex": {\n'
  printf '    "rules": [\n'
  printf '      "dist/codex/skills/agent-rules/rules/**/*.md"\n'
  printf '    ],\n'
  printf '    "skills": [\n'
  printf '      "dist/codex/skills/agent-rules/SKILL.md",\n'
  printf '      "dist/codex/skills/*/SKILL.md"\n'
  printf '    ]\n'
  printf '  }\n'
  printf '}\n'
} > "$DIST/manifest.json"

self_check() {
  local source_rule_count cursor_rule_count codex_rule_count

  source_rule_count="$(count_files "$ROOT/rules" '*.md')"
  cursor_rule_count="$(count_files "$DIST/cursor/rules" '*.mdc')"
  codex_rule_count="$(count_files "$DIST/codex/skills/agent-rules/rules" '*.md')"

  if [[ "$cursor_rule_count" != "$source_rule_count" ]]; then
    printf 'Build check failed: cursor rule count %s != source rule count %s\n' "$cursor_rule_count" "$source_rule_count" >&2
    exit 1
  fi

  if [[ "$codex_rule_count" != "$source_rule_count" ]]; then
    printf 'Build check failed: codex bundled rule count %s != source rule count %s\n' "$codex_rule_count" "$source_rule_count" >&2
    exit 1
  fi

  if grep -R -q '/Users/' "$DIST"; then
    printf 'Build check failed: dist contains local absolute paths\n' >&2
    exit 1
  fi
}

self_check

printf 'Built agent runtime artifacts in %s\n' "$DIST"
