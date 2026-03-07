local popup = require("neojj.lib.popup")
local actions = require("neojj.popups.commit.actions")

local M = {}

function M.create(env)
  local p = popup
    .builder()
    :name("NeoJJCommitPopup")
    :switch("r", "reset-author", "Reset author")
    :group_heading("Create")
    :action("c", "Commit", actions.commit)
    :action("C", "Commit (message)", actions.commit_with_message)
    :new_action_group("Edit")
    :action("d", "Describe", actions.describe)
    :action("D", "Describe (message)", actions.describe_with_message)
    :env(env or {})
    :build()

  p:show()
  return p
end

return M
