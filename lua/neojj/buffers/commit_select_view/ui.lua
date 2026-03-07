local util = require("neojj.lib.util")

local Commit = require("neojj.buffers.common").CommitEntry
local Graph = require("neojj.buffers.common").CommitGraph

local M = {}

---@param commits CommitLogEntry[]
---@param remotes string[]
---@return table
function M.View(commits, remotes)
  return util.filter_map(commits, function(commit)
    if commit.oid then
      return Commit(commit, remotes, { graph = true, decorate = true })
    else
      return Graph(commit, #commits[1].abbreviated_commit + 1)
    end
  end)
end

return M
