# Unified Rule Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform `rules/*.md` from Cursor-specific frontmatter to canonical frontmatter, and extend build + install to produce OpenCode-native output alongside existing Cursor output.

**Architecture:** Add a frontmatter parsing layer in `build.sh` that reads canonical fields (`title`, `apply`, `match`) and dispatches per-platform transforms. `install.sh` gains an `opencode` target that uses block markers (`<!--agent-rules:begin/end-->`) for idempotent `instructions.md` updates.

**Tech Stack:** Bash (build.sh, install.sh), git, OpenCode / Cursor CLI targets.

## Global Constraints

- Frontmatter is flat `key: value` only. `match` supports both single string and array syntax (`["*.py", "*.js"]`).
- `apply: always` + `match` together → build error.
- `instructions.md` uses `<!--agent-rules:begin-->` / `<!--agent-rules:end-->` block markers.
- Cursor output remains `agent-rules-<slug>.mdc` format unchanged.

---

### Task 1: Update canonical frontmatter in all `rules/*.md`

**Files:**
- Modify: `rules/response.md:1-4`
- Modify: `rules/project.md:1-4`
- Modify: `rules/index.md:1-4`
- Modify: `rules/languages/nodejs.md:1-4`
- Modify: `rules/languages/python.md:1-4`
- Modify: `rules/languages/go.md:1-4`

**Interfaces:**
- Consumes: (none)
- Produces: All rule files with canonical frontmatter that build/install scripts will parse.

**Current frontmatter pattern (all files):** `description: <text>` + `match: always` (for always-applied) or `match: ["**/*.py"]` (for language rules).

**Target:**

- [ ] **Step 1: Replace frontmatter in `rules/response.md`**

```
---
title: 回复与工作规范
apply: always
---
```

Remove old `description` line.

- [ ] **Step 2: Replace frontmatter in `rules/project.md`**

```
---
title: 项目基础规范
apply: always
---
```

- [ ] **Step 3: Replace frontmatter in `rules/index.md`**

```
---
title: 规则索引
apply: always
---
```

- [ ] **Step 4: Replace frontmatter in `rules/languages/nodejs.md`**

```
---
title: Node.js / TypeScript 规范
match: ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx"]
---
```

Keep existing `description` → change to `title`.

- [ ] **Step 5: Replace frontmatter in `rules/languages/python.md`**

```
---
title: Python 规范
match: ["**/*.py"]
---
```

- [ ] **Step 6: Replace frontmatter in `rules/languages/go.md`**

```
---
title: Go 规范
match: ["**/*.go", "**/go.mod", "**/go.sum"]
---
```

- [ ] **Step 7: Verify changes**

Run: `grep -A3 '^---$' rules/*.md rules/languages/*.md`
Expected: all files show canonical frontmatter with `title` and either `apply` or `match`.

---

### Task 2: Rewrite `build.sh` with canonical frontmatter parsing + OpenCode output

**Files:**
- Modify: `scripts/build.sh`

**Interfaces:**
- Consumes: `rules/*.md` (canonical frontmatter from Task 1)
- Produces: `dist/cursor/rules/*.mdc` (same as before), `dist/opencode/instructions.md`, `dist/opencode/rules/*.md`, `dist/opencode/skills/`

The build script needs these new capabilities:

1. **`parse_frontmatter()`** — reads a file, extracts `title`, `apply`, `match` from between `---` markers. Returns empty strings for missing fields. Validates that `apply: always` and `match` are not both present.

2. **Altered cursor output** — uses `title` → `description`, `apply: always` → `alwaysApply: true`, `match: ["*.py"]` → `globs: ["*.py"]`. Keeps same file naming and structure.

3. **New opencode output** — for each rule:
   - If `apply: always`: append content (with frontmatter stripped, `title` → `# title` heading) to `instructions.md`.
   - If `match` present: write separate file to `rules/<filename>.md` with frontmatter stripped, `title` → `# title` heading, first line as `> 此规则适用于 ...（\`<match>\`）`.
   - No frontmatter: write as separate file to `rules/` without heading hint.

4. **Block wrapping for `instructions.md`**: content wrapped in `<!--agent-rules:begin-->\n...\n<!--agent-rules:end-->`.

- [ ] **Step 1: Add frontmatter parsing to `build.sh`**

Add a function that reads a rule file and extracts `title`, `apply`, `match` into global variables. Called for each rule file at the top of the processing loop.

Implementation: scan lines between first `---` and second `---`. Each `key: value` line sets the corresponding global. After frontmatter block ends, validate `apply:always` + `match` not both set.

```bash
parse_frontmatter() {
  local file="$1"
  FRONTMATTER_TITLE=""
  FRONTMATTER_APPLY=""
  FRONTMATTER_MATCH=""
  local in_frontmatter=0
  local line

  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      if [[ "$in_frontmatter" -eq 0 ]]; then
        in_frontmatter=1
        continue
      else
        break
      fi
    fi
    [[ "$in_frontmatter" -eq 1 ]] || continue

    case "$line" in
      "title: "*)
        FRONTMATTER_TITLE="${line#title: }"
        FRONTMATTER_TITLE="${FRONTMATTER_TITLE#\"}"
        FRONTMATTER_TITLE="${FRONTMATTER_TITLE%\"}"
        ;;
      "apply: always")
        FRONTMATTER_APPLY="always"
        ;;
      "match: "*)
        FRONTMATTER_MATCH="${line#match: }"
        ;;
    esac
  done < "$file"

  if [[ "$FRONTMATTER_APPLY" == "always" && -n "$FRONTMATTER_MATCH" ]]; then
    printf 'Error: %s has both apply:always and match\n' "$file" >&2
    exit 1
  fi
}
```

- [ ] **Step 2: Add `strip_frontmatter()` function**

Reads file, outputs everything after the second `---` line. Handles files with no frontmatter by passing through unchanged.

```bash
strip_frontmatter() {
  local file="$1"
  local in_frontmatter=0
  local line

  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      in_frontmatter=$((in_frontmatter + 1))
      [[ "$in_frontmatter" -eq 2 ]] && continue
    fi
    [[ "$in_frontmatter" -ge 2 ]] || continue
    printf '%s\n' "$line"
  done < "$file"
}
```

- [ ] **Step 3: Add `parse_match_to_globs()` helper**

Converts canonical `match` (string or array) to Cursor `globs` YAML array:

```bash
parse_match_to_globs() {
  local match_value="$1"

  # Strip outer quotes if single string
  match_value="${match_value#\"}"
  match_value="${match_value%\"}"
  match_value="${match_value#\'}"
  match_value="${match_value%\'}"

  if [[ "$match_value" == \[* ]]; then
    # Array format: ["*.py", "*.js"] → yaml array items
    local cleaned
    cleaned="$(printf '%s' "$match_value" | tr -d '[]' | tr ',' '\n')"
    local line
    while IFS= read -r line; do
      line="${line# }"
      line="${line#\"}"
      line="${line%\"}"
      line="${line#\'}"
      line="${line%\'}"
      [[ -n "$line" ]] || continue
      printf '  - "%s"\n' "$line"
    done <<< "$cleaned"
  else
    # Single string
    printf '  - "%s"\n' "$match_value"
  fi
}
```

- [ ] **Step 4: Alter Cursor rule generation**

Replace the current frontmatter writing with mapped fields. Inside the existing loop that iterates `collect_rule_paths`, replace the current hardcoded frontmatter block:

```bash
# Instead of current logic, call parse_frontmatter first:
parse_frontmatter "$ROOT/$relative"

local body
body="$(strip_frontmatter "$ROOT/$relative")"

{
  printf -- '---\n'
  printf 'description: %s\n' "${FRONTMATTER_TITLE:-$slug}"
  if [[ "$FRONTMATTER_APPLY" == "always" ]]; then
    printf 'alwaysApply: true\n'
  elif [[ -n "$FRONTMATTER_MATCH" ]]; then
    parse_match_to_globs "$FRONTMATTER_MATCH"
    printf 'alwaysApply: false\n'
  fi
  printf -- '---\n'
  printf '%s\n' "$body"
} > "$DIST/cursor/rules/$(rule_runtime_name "$relative")"
```

Remove the old `rewrite_rule_links_for_cursor` logic (no longer needed since frontmatter comes from canonical fields, not inline text replacements).

- [ ] **Step 5: Add OpenCode output generation**

After existing Cursor loop, add opencode pass:

```bash
mkdir -p "$DIST/opencode/rules" "$DIST/opencode/skills"

instructions_block="<!--agent-rules:begin-->
"
while IFS= read -r relative; do
  [[ -n "$relative" ]] || continue
  parse_frontmatter "$ROOT/$relative"

  if [[ "$FRONTMATTER_APPLY" == "always" ]]; then
    local body
    body="$(strip_frontmatter "$ROOT/$relative")"
    if [[ -n "$FRONTMATTER_TITLE" ]]; then
      instructions_block+="# ${FRONTMATTER_TITLE}

"
    fi
    instructions_block+="$body

"
  fi
done < <(collect_rule_paths)
instructions_block+="<!--agent-rules:end-->"
printf '%s\n' "$instructions_block" > "$DIST/opencode/instructions.md"

while IFS= read -r relative; do
  [[ -n "$relative" ]] || continue
  parse_frontmatter "$ROOT/$relative"

  if [[ -n "$FRONTMATTER_MATCH" && "$FRONTMATTER_APPLY" != "always" ]]; then
    local body
    body="$(strip_frontmatter "$ROOT/$relative")"
    local outname
    outname="${relative#rules/}"
    outname="${outname%.md}"
    outname="${outname//\//-}.md"

    {
      if [[ -n "$FRONTMATTER_TITLE" ]]; then
        printf '# %s\n\n' "$FRONTMATTER_TITLE"
      fi
      printf '> 此规则适用于 \`%s\`\n\n' "$FRONTMATTER_MATCH"
      printf '%s\n' "$body"
    } > "$DIST/opencode/rules/$outname"
  fi
done < <(collect_rule_paths)
```

- [ ] **Step 6: Copy skills to opencode target**

```bash
if [[ -d "$ROOT/skills" ]]; then
  cp -R "$ROOT/skills/." "$DIST/opencode/skills/"
fi
```

- [ ] **Step 7: Update self_check for opencode counts**

Verify that the number of `apply:always` rule files equals 1 (`instructions.md`), and the number of `match` rule files matches the source count.

- [ ] **Step 8: Run build and verify output**

Run: `bash scripts/build.sh`
Expected exit: 0
Expected structure:
```
dist/
  cursor/     (existing, unchanged structure)
  opencode/
    instructions.md
    rules/
    skills/
```

Verify `instructions.md` contains `<!--agent-rules:begin-->` / `<!--agent-rules:end-->` with content.
Verify no `/Users/` absolute paths in dist (self_check catches this).

---

### Task 3: Extend `install.sh` with opencode target + block replace

**Files:**
- Modify: `scripts/install.sh`

**Interfaces:**
- Consumes: `dist/opencode/instructions.md`, `dist/opencode/rules/`, `dist/opencode/skills/`
- Produces: Installed files at `~/.config/opencode/`

- [ ] **Step 1: Add `install_opencode()` function**

```bash
install_opencode() {
  local oc_config="$HOME/.config/opencode"
  local target="$oc_config/instructions.md"
  local begin_marker="<!--agent-rules:begin-->"
  local end_marker="<!--agent-rules:end-->"
  local new_block
  new_block="$(<"$DIST/opencode/instructions.md")"

  mkdir -p "$oc_config/rules" "$oc_config/skills"

  if [[ -f "$target" ]]; then
    local content
    content="$(<"$target")"
    local prefix="${content%%${begin_marker}*}"
    local suffix="${content##*${end_marker}}"

    if [[ "$prefix" != "$content" ]]; then
      # Block found — replace in-place
      printf '%s%s%s' "$prefix" "$new_block" "$suffix" > "$target"
    else
      # No block — append
      printf '%s\n\n%s\n' "$content" "$new_block" > "$target"
    fi
  else
    printf '%s\n' "$new_block" > "$target"
  fi

  rm -rf "$oc_config/rules"
  cp -R "$DIST/opencode/rules" "$oc_config/rules"

  if [[ -d "$DIST/opencode/skills" ]]; then
    local skill_dir target_dir
    for skill_dir in "$DIST/opencode/skills"/*; do
      [[ -d "$skill_dir" ]] || continue
      target_dir="$oc_config/skills/$(basename "$skill_dir")"
      replace_dir "$skill_dir" "$target_dir"
      mark_managed "$target_dir"
    done
  fi

  printf 'Installed OpenCode instructions to %s\n' "$target"
  printf 'Installed OpenCode rules to %s/rules/\n' "$oc_config"
  printf 'Installed OpenCode skills to %s/skills/\n' "$oc_config"
}
```

- [ ] **Step 2: Add opencode case in `main()`**

```bash
opencode)
  install_opencode
  ;;
```

- [ ] **Step 3: Run install and verify**

Run: `bash scripts/install.sh opencode`
Expected: creates `~/.config/opencode/instructions.md` with block markers.
Run: `bash scripts/install.sh opencode` (again)
Expected: idempotent — block content replaced, not duplicated.

---

### Task 4: Update `README.md` with OpenCode support

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add OpenCode runtime section**

```markdown
## OpenCode Runtime

`bash scripts/install.sh opencode` writes:

```text
~/.config/opencode/instructions.md
~/.config/opencode/rules/<name>.md
~/.config/opencode/skills/<skill>/SKILL.md
```

`instructions.md` uses `<!--agent-rules:begin/end-->` block markers. Re-running install updates the block in-place without touching user content outside it.

To activate globally, add to `~/.config/opencode/opencode.json`:

```jsonc
{
  "instructions": [
    "~/.config/opencode/instructions.md",
    "~/.config/opencode/rules/*.md"
  ]
}
```

Installed skills are marked with `.agent-rules-managed`; future installs remove stale marked skills before copying the current `dist/opencode/skills` set.
```

- [ ] **Step 2: Add opencode to Commands section and Usage section**

Update the commands table to include `opencode`.

---

### Task 5: Verify end-to-end

- [ ] **Step 1: Full build + install cycle**

```bash
bash scripts/build.sh
bash scripts/install.sh cursor
bash scripts/install.sh opencode
```

Expected: all three succeed.

- [ ] **Step 2: Verify Cursor output**

Check `~/.cursor/rules/agent-rules-*.mdc` files exist and have correct frontmatter.

- [ ] **Step 3: Verify OpenCode output**

Check `~/.config/opencode/instructions.md` exists with block markers.
Check `~/.config/opencode/rules/` has language rule files.

- [ ] **Step 4: Verify idempotency**

Run `bash scripts/install.sh opencode` twice. Check `instructions.md` — block content should be the same, no duplicate blocks.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: unified rule format with Cursor + OpenCode build targets"
```

- [ ] **Step 6: Push**

```bash
git push
```
