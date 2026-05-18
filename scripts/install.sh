#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"

usage() {
  printf 'Usage: %s {cursor|codex}\n' "$(basename "$0")" >&2
}

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

append_codex_skill_config() {
  local skill_path="$1"
  local config_path="$HOME/.codex/config.toml"

  mkdir -p "$(dirname "$config_path")"
  touch "$config_path"

  if ! grep -Fq "$skill_path" "$config_path"; then
    {
      printf '\n[[skills.config]]\n'
      printf 'path = "%s"\n' "$skill_path"
      printf 'enabled = true\n'
    } >> "$config_path"
  fi
}

remove_codex_skill_config_matching() {
  local match="$1"
  local config_path="$HOME/.codex/config.toml"
  local tmp_path

  [[ -f "$config_path" ]] || return 0

  tmp_path="$(mktemp)"
  awk -v needle="$match" '
    function flush_block() {
      if (in_block) {
        if (block !~ needle) {
          printf "%s", block
        }
      } else {
        printf "%s", block
      }
      block = ""
    }

    /^\[\[skills\.config\]\]$/ {
      flush_block()
      in_block = 1
      block = $0 ORS
      next
    }

    /^\[/ && in_block {
      flush_block()
      in_block = 0
      block = $0 ORS
      next
    }

    {
      block = block $0 ORS
    }

    END {
      flush_block()
    }
  ' "$config_path" > "$tmp_path"
  mv "$tmp_path" "$config_path"
}

remove_managed_skill_dirs() {
  local skills_root="$1"
  local config_cleanup="${2:-}"
  local skill_dir

  [[ -d "$skills_root" ]] || return 0

  for skill_dir in "$skills_root"/*; do
    [[ -d "$skill_dir" ]] || continue
    [[ -f "$skill_dir/.agent-rules-managed" ]] || continue

    if [[ "$config_cleanup" == "codex" ]]; then
      remove_codex_skill_config_matching "$skill_dir/SKILL.md"
    fi

    rm -rf "$skill_dir"
  done
}

install_cursor() {
  local cursor_rules="$HOME/.cursor/rules"
  local cursor_skills="$HOME/.cursor/skills"

  mkdir -p "$cursor_rules" "$cursor_skills"
  rm -f "$cursor_rules"/agent-rules-*.mdc "$cursor_rules"/personal-agent-*.mdc
  remove_managed_skill_dirs "$cursor_skills"
  cp "$DIST/cursor/rules/"*.mdc "$cursor_rules/"

  if [[ -d "$DIST/cursor/skills" ]]; then
    for skill_dir in "$DIST/cursor/skills"/*; do
      [[ -d "$skill_dir" ]] || continue
      local target="$cursor_skills/$(basename "$skill_dir")"
      replace_dir "$skill_dir" "$target"
      mark_managed "$target"
    done
  fi

  printf 'Installed Cursor rules to %s\n' "$cursor_rules"
  printf 'Installed Cursor skills to %s\n' "$cursor_skills"
}

install_codex() {
  local codex_skills="$HOME/.codex/skills"

  mkdir -p "$codex_skills"
  rm -rf "$codex_skills/agent-rules-bootstrap"
  remove_codex_skill_config_matching 'agent-rules-bootstrap/SKILL.md'
  remove_managed_skill_dirs "$codex_skills" "codex"

  for skill_dir in "$DIST/codex/skills"/*; do
    [[ -d "$skill_dir" ]] || continue
    local target="$codex_skills/$(basename "$skill_dir")"
    replace_dir "$skill_dir" "$target"
    mark_managed "$target"

    if [[ -f "$target/SKILL.md" ]]; then
      append_codex_skill_config "$target/SKILL.md"
    fi
  done

  printf 'Installed Codex skills to %s\n' "$codex_skills"
  printf 'Updated Codex config at %s\n' "$HOME/.codex/config.toml"
}

main() {
  if [[ $# -ne 1 ]]; then
    usage
    exit 2
  fi

  "$ROOT/scripts/build.sh"

  case "$1" in
    cursor)
      install_cursor
      ;;
    codex)
      install_codex
      ;;
    *)
      usage
      exit 2
      ;;
  esac
}

main "$@"
