#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"

# --- Frontmatter parsing ---

# Extract raw frontmatter block (between first two --- lines), without delimiters.
extract_frontmatter() {
  local file="$1"
  awk '
    NR == 1 && /^---$/ { in_fm = 1; next }
    NR == 1 && !/^---$/ { exit }
    in_fm && /^---$/ { exit }
    in_fm { print }
  ' "$file"
}

# Extract description value from frontmatter.
parse_description() {
  local file="$1"
  extract_frontmatter "$file" | awk -F': ' '/^description:/ { $1=""; sub(/^ /, ""); print }'
}

# Extract match value. Returns "always" or a JSON-style array string like '["**/*.go","**/go.mod"]'.
parse_match() {
  local file="$1"
  local raw
  raw="$(extract_frontmatter "$file" | awk -F': ' '/^match:/ { $1=""; sub(/^ /, ""); print }')"
  printf '%s' "$raw"
}

# Output file content with frontmatter stripped.
strip_frontmatter() {
  local file="$1"
  awk '
    NR == 1 && /^---$/ { in_fm = 1; next }
    NR == 1 && !/^---$/ { print; started = 1; next }
    in_fm && /^---$/ { in_fm = 0; next }
    in_fm { next }
    { print }
  ' "$file"
}

# Parse match array into individual glob values (one per line).
# Input: '["**/*.go", "**/go.mod"]'
parse_match_globs() {
  local match="$1"
  # Strip brackets, split by comma, trim whitespace and quotes
  printf '%s' "$match" | tr -d '[]' | tr ',' '\n' | sed 's/^ *"//; s/" *$//'
}

# --- Path helpers ---

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

# --- Cursor build ---

rewrite_rule_links_for_cursor() {
  local content="$1"
  local relative runtime skill_name

  while IFS= read -r relative; do
    [[ -n "$relative" ]] || continue
    runtime="$(rule_runtime_name "$relative")"
    content="$(printf '%s' "$content" | sed "s|\`$relative\`|\`$runtime\`|g")"
  done < <(collect_rule_paths)

  if [[ -d "$ROOT/skills" ]]; then
    for skill_dir in "$ROOT"/skills/*; do
      [[ -d "$skill_dir" ]] || continue
      skill_name="$(basename "$skill_dir")"
      content="$(printf '%s' "$content" | sed "s|\`skills/$skill_name/SKILL.md\`|\`$skill_name\`|g")"
    done
  fi

  printf '%s\n' "$content"
}

build_cursor() {
  local cursor_dir="$DIST/cursor"
  mkdir -p "$cursor_dir/rules" "$cursor_dir/skills"

  local relative match description body globs_yaml

  while IFS= read -r relative; do
    [[ -n "$relative" ]] || continue

    match="$(parse_match "$ROOT/$relative")"
    description="$(parse_description "$ROOT/$relative")"
    body="$(strip_frontmatter "$ROOT/$relative")"
    body="$(rewrite_rule_links_for_cursor "$body")"

    {
      printf '%s\n' '---'
      printf 'description: %s\n' "$description"

      if [[ "$match" == "always" ]]; then
        printf '%s\n' 'alwaysApply: true'
      else
        printf '%s\n' 'alwaysApply: false'
        printf '%s\n' 'globs:'
        while IFS= read -r glob; do
          [[ -n "$glob" ]] || continue
          printf '  - "%s"\n' "$glob"
        done < <(parse_match_globs "$match")
      fi

      printf '%s\n' '---'
      printf '%s\n' "$body"
    } > "$cursor_dir/rules/$(rule_runtime_name "$relative")"
  done < <(collect_rule_paths)

  if [[ -d "$ROOT/skills" ]]; then
    cp -R "$ROOT/skills/." "$cursor_dir/skills/"
  fi

  printf 'Built Cursor artifacts\n'
}

# --- opencode / antigravity build (shared logic) ---

build_agents_platform() {
  local platform="$1"
  local target_rules_path="$2"   # runtime install path for rules, e.g. ~/.config/opencode/rules
  local platform_dir="$DIST/$platform"

  mkdir -p "$platform_dir/rules" "$platform_dir/skills"

  local relative match description body
  local always_rules=()
  local conditional_rules=()

  # Classify rules
  while IFS= read -r relative; do
    [[ -n "$relative" ]] || continue
    match="$(parse_match "$ROOT/$relative")"
    if [[ "$match" == "always" ]]; then
      always_rules+=("$relative")
    else
      conditional_rules+=("$relative")
    fi
  done < <(collect_rule_paths)

  # Generate agents.md
  {
    printf '%s\n' '<!-- agent-rules:start -->'
    printf '%s\n\n' '# Personal Agent Rules'
    printf '%s\n\n' '以下规则始终生效。'

    for relative in "${always_rules[@]}"; do
      body="$(strip_frontmatter "$ROOT/$relative")"
      printf '%s\n\n' "$body"
    done

    if [[ ${#conditional_rules[@]} -gt 0 ]]; then
      printf '%s\n\n' '## 按需加载'
      printf '%s\n\n' '根据项目类型，按需读取以下规则文件：'

      for relative in "${conditional_rules[@]}"; do
        description="$(parse_description "$ROOT/$relative")"
        # Derive the target file path relative to rules/
        local rule_subpath="${relative#rules/}"
        printf -- '- %s → `%s/%s`\n' "$description" "$target_rules_path" "$rule_subpath"
      done
      printf '\n'
    fi

    printf '%s\n' '<!-- agent-rules:end -->'
  } > "$platform_dir/agents.md"

  # Copy conditional rule files (stripped of custom frontmatter)
  for relative in "${conditional_rules[@]}"; do
    local rule_subpath="${relative#rules/}"
    local target_file="$platform_dir/rules/$rule_subpath"
    mkdir -p "$(dirname "$target_file")"
    strip_frontmatter "$ROOT/$relative" > "$target_file"
  done

  # Copy skills
  if [[ -d "$ROOT/skills" ]]; then
    cp -R "$ROOT/skills/." "$platform_dir/skills/"
  fi

  printf 'Built %s artifacts\n' "$platform"
}

build_opencode() {
  build_agents_platform "opencode" '~/.config/opencode/rules'
}

build_antigravity() {
  build_agents_platform "antigravity" '~/.gemini/config/rules'
}

# --- Manifest ---

generate_manifest() {
  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  {
    printf '{\n'
    printf '  "timestamp": "%s",\n' "$timestamp"
    printf '  "platforms": {\n'

    # Cursor
    printf '    "cursor": {\n'
    printf '      "rules": [\n'
    local first=1
    while IFS= read -r relative; do
      [[ -n "$relative" ]] || continue
      if [[ "$first" -eq 0 ]]; then
        printf ',\n'
      fi
      first=0
      printf '        "dist/cursor/rules/%s"' "$(rule_runtime_name "$relative")"
    done < <(collect_rule_paths)
    printf '\n'
    printf '      ],\n'
    printf '      "skills": [\n'
    printf '        "dist/cursor/skills/*/SKILL.md"\n'
    printf '      ]\n'
    printf '    },\n'

    # opencode
    printf '    "opencode": {\n'
    printf '      "agents_md": "dist/opencode/agents.md",\n'
    printf '      "rules": "dist/opencode/rules/",\n'
    printf '      "skills": "dist/opencode/skills/"\n'
    printf '    },\n'

    # antigravity
    printf '    "antigravity": {\n'
    printf '      "agents_md": "dist/antigravity/agents.md",\n'
    printf '      "rules": "dist/antigravity/rules/",\n'
    printf '      "skills": "dist/antigravity/skills/"\n'
    printf '    }\n'

    printf '  }\n'
    printf '}\n'
  } > "$DIST/manifest.json"
}

# --- Self-check ---

self_check() {
  local source_rule_count cursor_rule_count
  local opencode_agents antigravity_agents

  source_rule_count="$(count_files "$ROOT/rules" '*.md')"
  cursor_rule_count="$(count_files "$DIST/cursor/rules" '*.mdc')"

  if [[ "$cursor_rule_count" != "$source_rule_count" ]]; then
    printf 'Build check failed: cursor rule count %s != source rule count %s\n' "$cursor_rule_count" "$source_rule_count" >&2
    exit 1
  fi

  # Verify agents.md files contain markers
  for platform in opencode antigravity; do
    if ! grep -q 'agent-rules:start' "$DIST/$platform/agents.md"; then
      printf 'Build check failed: %s agents.md missing agent-rules:start marker\n' "$platform" >&2
      exit 1
    fi
    if ! grep -q 'agent-rules:end' "$DIST/$platform/agents.md"; then
      printf 'Build check failed: %s agents.md missing agent-rules:end marker\n' "$platform" >&2
      exit 1
    fi
  done

  # Verify no local absolute paths leaked into dist
  if grep -R -q '/Users/' "$DIST"; then
    printf 'Build check failed: dist contains local absolute paths\n' >&2
    exit 1
  fi
}

# --- Main ---

rm -rf "$DIST"
mkdir -p "$DIST"

build_cursor
build_opencode
build_antigravity
generate_manifest
self_check

printf 'Built agent runtime artifacts in %s\n' "$DIST"
