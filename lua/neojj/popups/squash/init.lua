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
    :new_action_group("Absorb")
    :action("a", "Absorb into prior changes", actions.absorb)
    :env(env or {})
    :build()

  p:show()
  return p
end

return M
