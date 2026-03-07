local popup = require("neojj.lib.popup")
local actions = require("neojj.popups.squash.actions")

local M = {}

function M.create(env)
  local p = popup
    .builder()
    :name("NeoJJSquashPopup")
    :switch("i", "interactive", "Select changes interactively")
    :group_heading("Squash")
    :action("s", "into parent", actions.squash)
    :action("S", "into revision", actions.squash_into)
    :env(env or {})
    :build()

  p:show()
  return p
end

return M
