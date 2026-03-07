local actions = require("neojj.popups.ignore.actions")
local Path = require("plenary.path")
local git = require("neojj.lib.git")
local popup = require("neojj.lib.popup")

local M = {}

---@class IgnoreEnv
---@field files string[] Absolute paths
function M.create(env)
  local excludesFile = git.config.get_global("core.excludesfile")

  local p = popup
    .builder()
    :name("NeoJJIgnorePopup")
    :group_heading("Gitignore")
    :action("t", "shared at top-level            (.gitignore)", actions.shared_toplevel)
    :action("s", "shared in sub-directory        (path/to/.gitignore)", actions.shared_subdirectory)
    :action("p", "privately for this repository  (.git/info/exclude)", actions.private_local)
    :action_if(
      excludesFile:is_set(),
      "g",
      string.format(
        "privately for all repositories (%s)",
        "~/" .. Path:new(excludesFile:read()):make_relative(vim.uv.os_homedir())
      ),
      actions.private_global
    )
    :env(env)
    :build()

  p:show()

  return p
end

return M
