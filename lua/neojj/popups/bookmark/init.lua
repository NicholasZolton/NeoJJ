local popup = require("neojj.lib.popup")
local actions = require("neojj.popups.bookmark.actions")

local M = {}

function M.create(env)
  local p = popup
    .builder()
    :name("NeoJJBookmarkPopup")
    :switch("B", "allow-backwards", "Allow moving bookmark backwards")
    :group_heading("Create")
    :action("c", "Create", actions.create)
    :new_action_group("Do")
    :action("m", "Move", actions.move)
    :action("d", "Delete", actions.delete)
    :action("f", "Forget", actions.forget)
    :action("t", "Track", actions.track)
    :env(env or {})
    :build()

  p:show()
  return p
end

return M
