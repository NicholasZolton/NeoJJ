local popup = require("neojj.lib.popup")
local actions = require("neojj.popups.reset.actions")

local M = {}

function M.create(env)
  local p = popup
    .builder()
    :name("NeoJJResetPopup")
    :group_heading("Reset")
    :action("f", "file", actions.a_file)
    :action("b", "branch", actions.a_branch)
    :new_action_group("Reset this")
    :action("m", "mixed    (HEAD and index)", actions.mixed)
    :action("s", "soft     (HEAD only)", actions.soft)
    :action("h", "hard     (HEAD, index and files)", actions.hard)
    :action("k", "keep     (HEAD and index, keeping uncommitted)", actions.keep)
    :action("i", "index    (only)", actions.index)
    :action("w", "worktree (only)", actions.worktree)
    :env(env)
    :build()

  p:show()

  return p
end

return M
