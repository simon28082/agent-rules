#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"

usage() {
  printf 'Usage: %s {cursor|opencode|antigravity}\n' "$(basename "$0")" >&2
}

# --- Shared helpers ---

replace_dir() {
  local source="$1"
  local target="$2"

  rm -rf "$target"
  mkdir -p "$(dirname "$target")"
  cp -R "$source" "$target"
}

mark_managed() {
  local target="$1"

  touch "$target/.agent-rules-managed"
}

remove_managed_skill_dirs() {
  local skills_root="$1"
  local skill_dir

  [[ -d "$skills_root" ]] || return 0

  for skill_dir in "$skills_root"/*; do
    [[ -d "$skill_dir" ]] || continue
    [[ -f "$skill_dir/.agent-rules-managed" ]] || continue
    rm -rf "$skill_dir"
  done
}

remove_managed_rules_dir() {
  local rules_root="$1"

  [[ -d "$rules_root" ]] || return 0
  [[ -f "$rules_root/.agent-rules-managed" ]] || return 0

  rm -rf "$rules_root"
}

# Inject or replace the <!-- agent-rules:start --> ... <!-- agent-rules:end --> block
# in the target AGENTS.md file. Preserves all user content outside the block.
inject_agents_block() {
  local agents_md_path="$1"
  local content_file="$2"

  mkdir -p "$(dirname "$agents_md_path")"

  if [[ ! -f "$agents_md_path" ]]; then
    # No existing AGENTS.md; just copy our content
    cp "$content_file" "$agents_md_path"
    return
  fi

  if grep -q '<!-- agent-rules:start -->' "$agents_md_path"; then
    # Replace existing block
    local tmp_path
    tmp_path="$(mktemp)"

    awk '
      /<!-- agent-rules:start -->/ { skip = 1; next }
      /<!-- agent-rules:end -->/ { skip = 0; next }
      !skip { print }
    ' "$agents_md_path" > "$tmp_path"

    # Remove trailing blank lines from user content
    local user_content
    user_content="$(awk '
      /^[[:space:]]*$/ { blank = blank $0 ORS; next }
      { printf "%s%s", blank, $0 ORS; blank = "" }
    ' "$tmp_path")"

    {
      if [[ -n "$user_content" ]]; then
        printf '%s\n\n' "$user_content"
      fi
      cat "$content_file"
    } > "$agents_md_path"

    rm -f "$tmp_path"
  else
    # No existing block; append after existing content
    {
      printf '\n'
      cat "$content_file"
    } >> "$agents_md_path"
  fi
}

# --- Cursor ---

install_cursor() {
  local cursor_rules="$HOME/.cursor/rules"
  local cursor_skills="$HOME/.cursor/skills"

  mkdir -p "$cursor_rules" "$cursor_skills"

  # Clean old rule files
  rm -f "$cursor_rules"/agent-rules-*.mdc "$cursor_rules"/personal-agent-*.mdc

  # Clean old managed skills
  remove_managed_skill_dirs "$cursor_skills"

  # Copy new rules
  cp "$DIST/cursor/rules/"*.mdc "$cursor_rules/"

  # Copy new skills
  if [[ -d "$DIST/cursor/skills" ]]; then
    for skill_dir in "$DIST/cursor/skills"/*; do
      [[ -d "$skill_dir" ]] || continue
      local name
      name="$(basename "$skill_dir")"
      local target="$cursor_skills/$name"
      replace_dir "$skill_dir" "$target"
      mark_managed "$target"
    done
  fi

  printf 'Installed Cursor rules to %s\n' "$cursor_rules"
  printf 'Installed Cursor skills to %s\n' "$cursor_skills"
}

# --- opencode ---

install_opencode() {
  local opencode_root="$HOME/.config/opencode"
  local opencode_rules="$opencode_root/rules"
  local opencode_skills="$opencode_root/skills"

  mkdir -p "$opencode_root" "$opencode_skills"

  # Clean old managed rules and skills
  remove_managed_rules_dir "$opencode_rules"
  remove_managed_skill_dirs "$opencode_skills"

  # Copy conditional rule files
  if [[ -d "$DIST/opencode/rules" ]]; then
    cp -R "$DIST/opencode/rules" "$opencode_rules"
    mark_managed "$opencode_rules"
  fi

  # Copy skills
  if [[ -d "$DIST/opencode/skills" ]]; then
    for skill_dir in "$DIST/opencode/skills"/*; do
      [[ -d "$skill_dir" ]] || continue
      local name
      name="$(basename "$skill_dir")"
      local target="$opencode_skills/$name"
      replace_dir "$skill_dir" "$target"
      mark_managed "$target"
    done
  fi

  # Inject AGENTS.md block
  inject_agents_block "$opencode_root/AGENTS.md" "$DIST/opencode/agents.md"

  printf 'Installed opencode rules to %s\n' "$opencode_rules"
  printf 'Installed opencode skills to %s\n' "$opencode_skills"
  printf 'Updated AGENTS.md at %s\n' "$opencode_root/AGENTS.md"
}

# --- antigravity ---

install_antigravity() {
  local agy_root="$HOME/.gemini/config"
  local agy_rules="$agy_root/rules"
  local agy_skills="$agy_root/skills"

  mkdir -p "$agy_root" "$agy_skills"

  # Clean old managed rules and skills
  remove_managed_rules_dir "$agy_rules"
  remove_managed_skill_dirs "$agy_skills"

  # Copy conditional rule files
  if [[ -d "$DIST/antigravity/rules" ]]; then
    cp -R "$DIST/antigravity/rules" "$agy_rules"
    mark_managed "$agy_rules"
  fi

  # Copy skills
  if [[ -d "$DIST/antigravity/skills" ]]; then
    for skill_dir in "$DIST/antigravity/skills"/*; do
      [[ -d "$skill_dir" ]] || continue
      local name
      name="$(basename "$skill_dir")"
      local target="$agy_skills/$name"
      replace_dir "$skill_dir" "$target"
      mark_managed "$target"
    done
  fi

  # Inject AGENTS.md block
  inject_agents_block "$agy_root/AGENTS.md" "$DIST/antigravity/agents.md"

  printf 'Installed antigravity rules to %s\n' "$agy_rules"
  printf 'Installed antigravity skills to %s\n' "$agy_skills"
  printf 'Updated AGENTS.md at %s\n' "$agy_root/AGENTS.md"
}

# --- Main ---

main() {
  if [[ $# -ne 1 ]]; then
    usage
    exit 2
  fi

  bash "$ROOT/scripts/build.sh"

  case "$1" in
    cursor)
      install_cursor
      ;;
    opencode)
      install_opencode
      ;;
    antigravity)
      install_antigravity
      ;;
    *)
      usage
      exit 2
      ;;
  esac
}

main "$@"
