local actions = require("neojj.popups.remote.actions")
local git = require("neojj.lib.git")
local popup = require("neojj.lib.popup")

local M = {}

function M.create()
  local p = popup
    .builder()
    :name("NeoJJRemotePopup")
    :switch("f", "f", "Fetch after add", { enabled = true, cli_prefix = "-" })
    :config("u", "remote.origin.url")
    :config("U", "remote.origin.fetch")
    :config("s", "remote.origin.pushurl")
    :config("S", "remote.origin.push")
    :config("O", "remote.origin.tagOpt", {
      options = {
        { display = "", value = "" },
        { display = "--no-tags", value = "--no-tags" },
        { display = "--tags", value = "--tags" },
      },
    })
    :group_heading("Actions")
    :action("a", "Add", actions.add)
    :action("r", "Rename", actions.rename)
    :action("x", "Remove", actions.remove)
    :new_action_group()
    :action("C", "Configure...", actions.configure)
    :action("p", "Prune stale branches", actions.prune_branches)
    :action("P", "Prune stale refspecs")
    :action("b", "Update default branch")
    :action("z", "Unshallow remote")
    :env({ highlight = { git.branch.pushRemote() } })
    :build()

  p:show()

  return p
end

return M
