---@class NeoJJGitLib
---@field repo        NeoJJRepo
---@field bisect      NeoJJGitBisect
---@field branch      NeoJJGitBranch
---@field cherry      NeoJJGitCherry
---@field cherry_pick NeoJJGitCherryPick
---@field cli         NeoJJGitCLI
---@field config      NeoJJGitConfig
---@field diff        NeoJJGitDiff
---@field fetch       NeoJJGitFetch
---@field files       NeoJJGitFiles
---@field index       NeoJJGitIndex
---@field init        NeoJJGitInit
---@field log         NeoJJGitLog
---@field merge       NeoJJGitMerge
---@field pull        NeoJJGitPull
---@field push        NeoJJGitPush
---@field rebase      NeoJJGitRebase
---@field reflog      NeoJJGitReflog
---@field refs        NeoJJGitRefs
---@field remote      NeoJJGitRemote
---@field reset       NeoJJGitReset
---@field rev_parse   NeoJJGitRevParse
---@field revert      NeoJJGitRevert
---@field sequencer   NeoJJGitSequencer
---@field stash       NeoJJGitStash
---@field status      NeoJJGitStatus
---@field submodule   NeoJJGitSubmodule
---@field tag         NeoJJGitTag
---@field worktree    NeoJJGitWorktree
---@field hooks       NeoJJGitHooks
local Git = {}

setmetatable(Git, {
  __index = function(_, k)
    if k == "repo" then
      return require("neojj.lib.git.repository").instance()
    else
      return require("neojj.lib.git." .. k)
    end
  end,
})

return Git
