local M = {}
local util = require("tests.util.util")

function M.prepare_repository()
  local working_dir = util.create_temp_dir("jj-working-dir")
  vim.api.nvim_set_current_dir(working_dir)

  -- Initialize jj workspace with git backend
  util.system { "jj", "git", "init" }
  util.system { "git", "-C", working_dir, "config", "user.email", "test@neojj-test.test" }
  util.system { "git", "-C", working_dir, "config", "user.name", "NeoJJ Test" }

  -- Create test files
  vim.fn.writefile({ "line 1", "line 2", "line 3" }, working_dir .. "/a.txt")
  vim.fn.writefile({ "hello world" }, working_dir .. "/b.txt")
  vim.fn.writefile({ "untracked content" }, working_dir .. "/untracked.txt")

  -- Snapshot and describe the initial change
  util.system { "jj", "describe", "-m", "initial commit" }

  -- Create a new change on top so we have a parent with content
  util.system { "jj", "new" }

  -- Create a bookmark on the parent
  util.system { "jj", "bookmark", "create", "main", "-r", "@-" }

  -- Modify a file in the working copy so there are changes to see
  vim.fn.writefile({ "line 1", "line 2 modified", "line 3" }, working_dir .. "/a.txt")

  return working_dir
end

function M.in_prepared_repo(cb)
  return function()
    local working_dir = M.prepare_repository()
    cb(working_dir)
  end
end

---@param cmd string[]
---@return string[]
local function exec(cmd)
  local output = vim.fn.system(cmd)
  local lines = output and vim.split(output, "\n") or {}
  return lines
end

function M.get_jj_status()
  return table.concat(exec { "jj", "status" }, "\n")
end

function M.get_jj_log()
  return exec { "jj", "log", "--no-graph", "-T", "change_id ++ \" \" ++ description" }
end

function M.get_jj_bookmarks()
  return exec { "jj", "bookmark", "list" }
end

function M.get_change_id()
  local lines = exec { "jj", "log", "--no-graph", "-r", "@", "-T", "change_id" }
  return vim.trim(lines[1] or "")
end

M.exec = exec

return M
