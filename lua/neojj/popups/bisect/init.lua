local M = {}

local popup = require("neojj.lib.popup")
local git = require("neojj.lib.git")
local actions = require("neojj.popups.bisect.actions")

function M.create(env)
  local in_progress = git.bisect.in_progress()
  local finished = git.bisect.is_finished()

  local p = popup
    .builder()
    :name("NeoJJBisectPopup")
    :switch_if(not in_progress, "r", "no-checkout", "Don't checkout commits")
    :switch_if(not in_progress, "p", "first-parent", "Follow only first parent of a merge")
    :group_heading_if(not in_progress, "Bisect")
    :group_heading_if(in_progress, "Actions")
    :action_if(not in_progress, "B", "Start", actions.start)
    :action_if(not in_progress, "S", "Scripted", actions.scripted)
    :action_if(not finished and in_progress, "b", "Bad", actions.bad)
    :action_if(not finished and in_progress, "g", "Good", actions.good)
    :action_if(not finished and in_progress, "s", "Skip", actions.skip)
    :action_if(not finished and in_progress, "r", "Reset", actions.reset_with_permission)
    :action_if(finished and in_progress, "r", "Reset", actions.reset)
    :action_if(not finished and in_progress, "S", "Run script", actions.run)
    :env(env)
    :build()

  p:show()

  return p
end

return M
