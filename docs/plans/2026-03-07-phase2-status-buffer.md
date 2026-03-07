# Phase 2: Status Buffer Adaptation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rewire the status buffer to display jj state instead of git state — current change, modified files, conflicts, recent changes, and bookmarks.

**Architecture:** Modify 4 files: main entry point (`neojj.lua`) to use `jj.repo`, status UI renderer (`ui.lua`) to render jj sections, status buffer (`init.lua`) to use `jj.repo.state` and jj-appropriate keymaps, and actions (`actions.lua`) to call jj commands instead of git. The existing git code paths are replaced, not wrapped.

**Tech Stack:** Lua (Neovim plugin), jj CLI via `lib/jj/` modules from Phase 1

---

### Task 1: Update main entry point to use jj backend

**Files:**
- Modify: `lua/neojj.lua`

**Context:** The main entry point currently uses `git.cli.is_inside_worktree()`, `git.repo`, and `git.init` to detect repos and open the status buffer. Switch all git references to jj equivalents.

**Step 1: Replace git imports and detection logic**

In `lua/neojj.lua`, make these changes:

1. Replace `require("neojj.lib.git")` references with `require("neojj.lib.jj")`
2. In `construct_opts()` (around line 86-100): replace `git.cli.worktree_root(".")` with `jj_cli.workspace_root(".")`
3. In `M.open()` (around line 147-177): replace `git.cli.is_inside_worktree(opts.cwd)` with `jj_cli.is_inside_workspace(opts.cwd)`
4. In `open_status_buffer()` (around line 106-115): replace `require("neojj.lib.git.repository").instance(opts.cwd)` with `require("neojj.lib.jj.repository").instance(opts.cwd)`
5. Remove the `git.init.create()` call (jj init is handled differently)
6. Update `M.dispatch_refresh` and similar helper functions to use jj.repo

Key pattern: everywhere you see `git.repo`, replace with `jj.repo`. Everywhere you see `git.cli`, replace with `jj.cli`.

**Step 2: Commit**

```bash
git add lua/neojj.lua
git commit -m "feat(jj): switch main entry point from git to jj backend"
```

---

### Task 2: Rewrite status UI renderer for jj sections

**Files:**
- Modify: `lua/neojj/buffers/status/ui.lua`

**Context:** This is the largest change. The renderer currently builds sections for HEAD, untracked, unstaged, staged, stashes, rebase, merge, bisect, etc. We need to replace these with jj-appropriate sections:

1. **Current Change** — change ID, commit ID, description
2. **Parent** — parent change ID, commit ID, bookmarks, description
3. **Modified Files** — single flat list (no staged/unstaged split)
4. **Conflicts** — files with unresolved conflicts (shown only when present)
5. **Recent Changes** — log entries with change IDs
6. **Bookmarks** — local and remote bookmarks

**Step 1: Rewrite the main `M.Status()` function**

Replace the entire body of `M.Status(state, config)` (lines 602-846). The new version reads from `NeoJJRepoState` instead of `NeoJJRepoState` (git version).

New section structure:

```lua
function M.Status(state, config)
  -- Visibility flags
  local show_files = #state.files.items > 0
  local show_conflicts = #state.conflicts.items > 0
  local show_recent = #state.recent.items > 0
  local show_bookmarks = #state.bookmarks.items > 0

  return {
    List {
      items = {
        -- HEAD: Current Change section
        HeadSection(state),
        -- Modified Files
        show_files and Section("Modified files", state.files.items, config) or nil,
        -- Conflicts
        show_conflicts and Section("Conflicts", state.conflicts.items, config) or nil,
        -- Recent Changes
        show_recent and Section("Recent changes", state.recent.items, config) or nil,
        -- Bookmarks
        show_bookmarks and Section("Bookmarks", state.bookmarks.items, config) or nil,
      },
    },
  }
end
```

**Step 2: Create `HeadSection` component**

Renders the current change and parent info:

```
Current change (@ muvqvxnn) 7809cff3
  (no description set)
Parent (@- tvonrrpo) 63990385 main
  initial commit: add hello and readme
```

The HeadSection should:
- Show change ID prominently (this is the primary identifier in jj)
- Show commit ID secondary
- Show bookmarks on the parent line
- Show description on the next line

**Step 3: Update `SectionItemFile` component**

The existing file component works for jj too (mode + filename), but:
- Remove references to `state.staged`, `state.unstaged`, `state.untracked` sections
- The file item's `section` field should just be "files" (not "staged"/"unstaged")
- Diff loading should use `jj.diff.file_diff(item)` instead of `git.diff.build()`

**Step 4: Create `SectionItemChange` component for recent changes**

Replaces `SectionItemCommit`. Shows change ID instead of commit OID:

```
muvqvxnn 7809cff3 (no description set)
tvonrrpo 63990385 main | initial commit
```

Fields: change_id (highlighted), commit_id (dimmed), bookmarks (if any), description

**Step 5: Create `SectionItemBookmark` component**

Shows bookmark name, target change ID, and tracking status:

```
main tvonrrpo 63990385 initial commit
  @git tvonrrpo 63990385 initial commit
```

**Step 6: Remove git-only sections**

Delete or comment out: merge section, rebase section, cherry-pick section, revert section, bisect section, stash section, upstream/pushRemote sections. These will be re-added in later phases with jj equivalents where applicable.

**Step 7: Commit**

```bash
git add lua/neojj/buffers/status/ui.lua
git commit -m "feat(jj): rewrite status UI renderer for jj sections"
```

---

### Task 3: Update StatusBuffer to use jj.repo

**Files:**
- Modify: `lua/neojj/buffers/status/init.lua`

**Context:** The StatusBuffer class references `git.repo` for state and refresh. Switch to `jj.repo`.

**Step 1: Replace git.repo references**

1. Replace `local git = require("neojj.lib.git")` with `local jj = require("neojj.lib.jj")`
2. In `M:open()` render function (line 250): replace `git.repo.state` with `jj.repo.state`
3. In `M:refresh()` (lines 308-327): replace `git.repo:dispatch_refresh` with `jj.repo:dispatch_refresh`
4. In `M:redraw()` (line 338): replace `git.repo.state` with `jj.repo.state`
5. In `M:reset()` (line 371): replace `git.repo:reset()` with `jj.repo:reset()`

**Step 2: Update keymaps**

In the keymap definition block (lines 134-243), update for jj workflow:

Remove keymaps for:
- `s` (stage) — no staging in jj
- `S` (stage all)
- `u` (unstage)
- `U` (unstage all)
- `x` (discard) — will be re-added as `jj restore`

Keep keymaps for:
- Navigation: `j/k`, `<tab>`, `<s-tab>`, section navigation
- Fold/unfold: `za`, `zo`, `zc`, `zM`, `zR`
- File open: `<enter>`, `<tab>`, split, vsplit
- Refresh: `g?`, `<c-r>`
- Close: `q`

Update keymaps:
- `d` → describe (edit change description) instead of discard
- `x` → discard file (`jj restore <path>`)
- `c` → commit popup (adapted for jj commit)
- `b` → bookmark popup (replaces branch popup)
- `p` → push popup (`jj git push`)
- `f` → fetch popup (`jj git fetch`)
- `r` → rebase popup
- `n` → new change popup (`jj new`)
- `S` → squash popup (`jj squash`)
- `a` → abandon change

**Step 3: Commit**

```bash
git add lua/neojj/buffers/status/init.lua
git commit -m "feat(jj): update StatusBuffer to use jj.repo and jj keymaps"
```

---

### Task 4: Rewrite status actions for jj

**Files:**
- Modify: `lua/neojj/buffers/status/actions.lua`

**Context:** Actions currently call git.index.*, git.status.*, git.stash.* etc. Replace with jj equivalents. Many actions are removed (staging), some are adapted, some are new.

**Step 1: Replace git import with jj**

Replace `local git = require("neojj.lib.git")` with `local jj = require("neojj.lib.jj")`

**Step 2: Remove staging actions**

Delete entirely:
- `v_stage`, `v_unstage`, `n_stage`, `n_stage_all`, `n_stage_unstaged`, `n_unstage`, `n_unstage_staged`
- `v_untrack`, `n_untrack`

**Step 3: Rewrite discard action**

Replace `n_discard` and `v_discard` with jj restore:

```lua
M.n_discard = function(self)
  return a.void(function()
    local selection = self.buffer.ui:get_selection()
    if not selection.item then return end

    local paths = {}
    if selection.items then
      for _, item in ipairs(selection.items) do
        table.insert(paths, item.name)
      end
    elseif selection.item then
      table.insert(paths, selection.item.name)
    end

    if #paths == 0 then return end

    local msg = ("Discard changes in %d file(s)?"):format(#paths)
    if not input.get_permission(msg) then return end

    jj.cli.restore.files(unpack(paths)).call()
    self:dispatch_refresh(nil, "discard")
  end)
end
```

**Step 4: Add describe action**

```lua
M.n_describe = function(self)
  return a.void(function()
    -- Open editor buffer for jj describe
    local msg = input.get_user_input("Change description")
    if not msg then return end
    jj.cli.describe.no_edit.message(msg).call()
    self:dispatch_refresh(nil, "describe")
  end)
end
```

**Step 5: Add abandon action**

```lua
M.n_abandon = function(self)
  return a.void(function()
    if not input.get_permission("Abandon current change?") then return end
    jj.cli.abandon.call()
    self:dispatch_refresh(nil, "abandon")
  end)
end
```

**Step 6: Update popup actions**

Replace git popup names with jj equivalents:
- `n_branch_popup` → `n_bookmark_popup` calling `popups.open("bookmark")`
- Remove: `n_stash_popup`, `n_bisect_popup`, `n_cherry_pick_popup`, `n_merge_popup`, `n_reset_popup`, `n_ignore_popup`, `n_worktree_popup`
- Keep: `n_push_popup`, `n_fetch_popup`, `n_rebase_popup`, `n_diff_popup`, `n_log_popup`, `n_help_popup`
- Add: `n_change_popup` for `jj new`, `n_squash_popup` for `jj squash`

**Step 7: Keep navigation actions unchanged**

These are VCS-agnostic: `n_down`, `n_up`, `n_toggle`, `n_open_fold`, `n_close_fold`, `n_next_section`, `n_prev_section`, `n_goto_file`, `n_tab_open`, `n_split_open`, `n_vertical_split_open`, `n_close`, `n_refresh_buffer`, `n_open_or_scroll_down`, `n_open_or_scroll_up`

**Step 8: Update yank action**

`n_yank_selected` should prefer change_id over commit_id.

**Step 9: Commit**

```bash
git add lua/neojj/buffers/status/actions.lua
git commit -m "feat(jj): rewrite status actions for jj workflow"
```

---

### Task 5: Update watcher for jj

**Files:**
- Modify: `lua/neojj/watcher.lua`

**Context:** The watcher monitors filesystem changes to auto-refresh. It currently watches `.git/` directory. For jj, it should watch `.jj/` directory. In colocated repos, both may exist.

**Step 1: Update watched paths**

Find where `.git` directory is referenced in the watcher and add/replace with `.jj` directory monitoring.

**Step 2: Commit**

```bash
git add lua/neojj/watcher.lua
git commit -m "feat(jj): update watcher to monitor .jj directory"
```

---

### Task 6: Smoke test — verify status buffer opens

**Context:** At this point the status buffer should open in a jj repo and display the current change, files, and recent changes. This task is manual verification.

**Step 1: Test in a jj repo**

1. Navigate to a jj repository
2. Open Neovim
3. Run `:NeoJJ`
4. Verify the status buffer shows:
   - Current change with change ID
   - Parent with bookmarks
   - Modified files (if any)
   - Recent changes

**Step 2: Fix any runtime errors encountered**

Common issues to watch for:
- Missing field accesses (state.staged, state.unstaged, etc. referenced from unmodified code)
- Popup references to non-existent popups
- Diff loading failures (git.diff vs jj.diff)

**Step 3: Commit fixes**

```bash
git add -A
git commit -m "fix(jj): resolve runtime errors in status buffer"
```

---

### Task 7: Update plan checklist

**Files:**
- Modify: `docs/plans/2026-03-07-neojj-port-plan.md`

**Step 1:** Mark all Phase 2 items as complete.

**Step 2: Commit**

```bash
git add docs/plans/2026-03-07-neojj-port-plan.md
git commit -m "docs: mark Phase 2 complete in plan"
```
