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

# Extract title value from frontmatter.
parse_title() {
  local file="$1"
  extract_frontmatter "$file" | awk -F': ' '/^title:/ { $1=""; sub(/^ /, ""); print }'
}

# Extract apply value from frontmatter. Returns "always" or empty string.
parse_apply() {
  local file="$1"
  extract_frontmatter "$file" | awk -F': ' '/^apply:/ { $1=""; sub(/^ /, ""); print }'
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

# Validate that apply:always and match are not both set (mutually exclusive).
validate_frontmatter() {
  local file="$1"
  local apply="$2"
  local match="$3"
  if [[ "$apply" == "always" && -n "$match" ]]; then
    printf 'Error: %s has both apply:always and match — these are mutually exclusive\n' "$file" >&2
    exit 1
  fi
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

  local relative match apply_val title body globs_yaml

  while IFS= read -r relative; do
    [[ -n "$relative" ]] || continue

    match="$(parse_match "$ROOT/$relative")"
    apply_val="$(parse_apply "$ROOT/$relative")"
    title="$(parse_title "$ROOT/$relative")"
    body="$(strip_frontmatter "$ROOT/$relative")"
    body="$(rewrite_rule_links_for_cursor "$body")"
    validate_frontmatter "$ROOT/$relative" "$apply_val" "$match"

    {
      printf '%s\n' '---'
      printf 'description: %s\n' "$title"

      if [[ "$apply_val" == "always" ]]; then
        printf '%s\n' 'alwaysApply: true'
      elif [[ -n "$match" ]]; then
        printf '%s\n' 'globs:'
        while IFS= read -r glob; do
          [[ -n "$glob" ]] || continue
          printf '  - "%s"\n' "$glob"
        done < <(parse_match_globs "$match")
        printf '%s\n' 'alwaysApply: false'
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

  local relative match apply_val title body
  local always_rules=()
  local conditional_rules=()

  # Classify rules
  while IFS= read -r relative; do
    [[ -n "$relative" ]] || continue
    apply_val="$(parse_apply "$ROOT/$relative")"
    match="$(parse_match "$ROOT/$relative")"
    validate_frontmatter "$ROOT/$relative" "$apply_val" "$match"
    if [[ "$apply_val" == "always" ]]; then
      always_rules+=("$relative")
    else
      conditional_rules+=("$relative")
    fi
  done < <(collect_rule_paths)

  # Generate instructions.md
  {
    printf '%s\n' '<!--agent-rules:begin-->'
    printf '%s\n\n' '# Personal Agent Rules'
    printf '%s\n\n' '以下规则始终生效。'

    for relative in "${always_rules[@]}"; do
      title="$(parse_title "$ROOT/$relative")"
      body="$(strip_frontmatter "$ROOT/$relative")"
      # Strip leading # heading and following blank lines (title comes from frontmatter)
      body="$(printf '%s' "$body" | awk 'NR==1 && /^# / {skip=1; next} skip && /^$/ {next} {skip=0; print}')"
      if [[ -n "$title" ]]; then
        printf '# %s\n\n' "$title"
      fi
      printf '%s\n\n' "$body"
    done

    if [[ ${#conditional_rules[@]} -gt 0 ]]; then
      printf '%s\n\n' '## 按需加载'
      printf '%s\n\n' '根据项目类型，按需读取以下规则文件：'

      for relative in "${conditional_rules[@]}"; do
        title="$(parse_title "$ROOT/$relative")"
        match="$(parse_match "$ROOT/$relative")"
        # Derive the target file path relative to rules/
        local rule_subpath="${relative#rules/}"
        if [[ -n "$match" ]]; then
          printf -- '- %s → `%s/%s`（适用于 `%s`）\n' "$title" "$target_rules_path" "$rule_subpath" "$match"
        else
          printf -- '- %s → `%s/%s`\n' "$title" "$target_rules_path" "$rule_subpath"
        fi
      done
      printf '\n'
    fi

    printf '%s\n' '<!--agent-rules:end-->'
  } > "$platform_dir/instructions.md"

  # Copy conditional rule files with title heading and match hint
  for relative in "${conditional_rules[@]}"; do
    title="$(parse_title "$ROOT/$relative")"
    match="$(parse_match "$ROOT/$relative")"
    local rule_subpath="${relative#rules/}"
    local target_file="$platform_dir/rules/$rule_subpath"
    mkdir -p "$(dirname "$target_file")"
    {
      local cond_body
      cond_body="$(strip_frontmatter "$ROOT/$relative")"
      # Strip leading # heading and following blank lines (title comes from frontmatter)
      cond_body="$(printf '%s' "$cond_body" | awk 'NR==1 && /^# / {skip=1; next} skip && /^$/ {next} {skip=0; print}')"
      if [[ -n "$title" ]]; then
        printf '# %s\n\n' "$title"
      fi
      if [[ -n "$match" ]]; then
        printf '> 此规则适用于 %s（`%s`）\n\n' "$title" "$match"
      fi
      printf '%s\n' "$cond_body"
    } > "$target_file"
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
    printf '      "instructions_md": "dist/opencode/instructions.md",\n'
    printf '      "rules": "dist/opencode/rules/",\n'
    printf '      "skills": "dist/opencode/skills/"\n'
    printf '    },\n'

    # antigravity
    printf '    "antigravity": {\n'
    printf '      "instructions_md": "dist/antigravity/instructions.md",\n'
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
  local apply_val match conditional_count opencode_rule_count

  source_rule_count="$(count_files "$ROOT/rules" '*.md')"
  cursor_rule_count="$(count_files "$DIST/cursor/rules" '*.mdc')"

  if [[ "$cursor_rule_count" != "$source_rule_count" ]]; then
    printf 'Build check failed: cursor rule count %s != source rule count %s\n' "$cursor_rule_count" "$source_rule_count" >&2
    exit 1
  fi

  # Verify instructions.md files contain markers
  for platform in opencode antigravity; do
    if ! grep -q 'agent-rules:begin' "$DIST/$platform/instructions.md"; then
      printf 'Build check failed: %s instructions.md missing agent-rules:begin marker\n' "$platform" >&2
      exit 1
    fi
    if ! grep -q 'agent-rules:end' "$DIST/$platform/instructions.md"; then
      printf 'Build check failed: %s instructions.md missing agent-rules:end marker\n' "$platform" >&2
      exit 1
    fi
  done

  # Verify opencode instructions.md exists
  if [[ ! -f "$DIST/opencode/instructions.md" ]]; then
    printf 'Build check failed: dist/opencode/instructions.md missing\n' >&2
    exit 1
  fi

  # Count source rules with match (conditional rules)
  conditional_count=0
  while IFS= read -r relative; do
    [[ -n "$relative" ]] || continue
    apply_val="$(parse_apply "$ROOT/$relative")"
    match="$(parse_match "$ROOT/$relative")"
    if [[ -n "$match" && "$apply_val" != "always" ]]; then
      conditional_count=$((conditional_count + 1))
    fi
  done < <(collect_rule_paths)

  opencode_rule_count="$(count_files "$DIST/opencode/rules" '*.md')"
  if [[ "$opencode_rule_count" != "$conditional_count" ]]; then
    printf 'Build check failed: opencode conditional rule count %s != source conditional count %s\n' "$opencode_rule_count" "$conditional_count" >&2
    exit 1
  fi

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
