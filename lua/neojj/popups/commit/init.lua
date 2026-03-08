local popup = require("neojj.lib.popup")
local actions = require("neojj.popups.commit.actions")

local M = {}

function M.create(env)
  local p = popup
    .builder()
    :name("NeoJJCommitPopup")
    :group_heading("Create")
    :action("c", "Commit", actions.commit)
    :action("n", "New change", actions.new_change)
    :action("e", "Edit change", actions.edit_change)
    :action("E", "Edit bookmark", actions.edit_bookmark)
    :new_action_group("Describe")
    :action("d", "Describe (editor)", actions.describe)
    :action("D", "Describe (message)", actions.describe_with_message)
    :new_action_group("Modify")
    :action("a", "Abandon", actions.abandon)
    :action("u", "Duplicate", actions.duplicate)
    :action("r", "Revert", actions.revert)
    :env(env or {})
    :build()

  p:show()
  return p
end

return M
