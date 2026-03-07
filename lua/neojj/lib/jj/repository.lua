local logger = require("neojj.logger")

---@class NeoJJRepoHead
---@field change_id string Short change ID
---@field commit_id string Short commit ID
---@field description string Change description
---@field bookmarks string[] Bookmarks pointing to this change
---@field empty boolean Whether the change is empty
---@field conflict boolean Whether the change has conflicts

---@class NeoJJRepoParent
---@field change_id string
---@field commit_id string
---@field description string
---@field bookmarks string[]

---@class NeoJJFileItem
---@field name string File path
---@field absolute_path string Full file path
---@field escaped_path string Vim-escaped path
---@field mode string "M", "A", "D", "R"
---@field original_name string|nil For renames
---@field diff any|nil Lazy-loaded diff
---@field folded boolean|nil

---@class NeoJJConflictItem
---@field name string File path
---@field absolute_path string
---@field escaped_path string

---@class NeoJJChangeLogEntry
---@field change_id string
---@field commit_id string
---@field description string
---@field author_name string
---@field author_email string
---@field author_date string
---@field bookmarks string[]
---@field empty boolean
---@field conflict boolean
---@field immutable boolean
---@field current_working_copy boolean
---@field graph string|nil Graph ASCII art

---@class NeoJJBookmarkItem
---@field name string
---@field change_id string
---@field commit_id string
---@field description string
---@field remote string|nil Remote name if tracking bookmark

---@class NeoJJRepoState
---@field worktree_root string
---@field head NeoJJRepoHead
---@field parent NeoJJRepoParent
---@field files { items: NeoJJFileItem[] }
---@field conflicts { items: NeoJJConflictItem[] }
---@field recent { items: NeoJJChangeLogEntry[] }
---@field bookmarks { items: NeoJJBookmarkItem[] }

local M = {}

---@return NeoJJRepoState
local function empty_state()
  return {
    worktree_root = "",
    head = {
      change_id = "",
      commit_id = "",
      description = "",
      bookmarks = {},
      empty = true,
      conflict = false,
    },
    parent = {
      change_id = "",
      commit_id = "",
      description = "",
      bookmarks = {},
    },
    files = { items = {} },
    conflicts = { items = {} },
    recent = { items = {} },
    bookmarks = { items = {} },
  }
end

---@class NeoJJRepo
---@field state NeoJJRepoState
---@field lib table<string, { update: fun(state: NeoJJRepoState) }>
---@field worktree_root string
---@field running boolean
---@field callbacks table<string, fun()>
local Repo = {}
Repo.__index = Repo

local instances = {}

---Get or create singleton repo instance for a directory
---@param dir? string
---@return NeoJJRepo
function Repo.instance(dir)
  local jj_cli = require("neojj.lib.jj.cli")
  dir = dir or vim.fn.getcwd()
  dir = vim.fn.fnamemodify(dir, ":p")

  if not instances[dir] then
    local root = jj_cli.workspace_root(dir)
    if not root then
      error("Not inside a jj workspace: " .. dir)
    end
    instances[dir] = Repo.new(root)
  end

  return instances[dir]
end

---Create a new repo instance
---@param root string Workspace root directory
---@return NeoJJRepo
function Repo.new(root)
  local self = setmetatable({}, Repo)
  self.state = empty_state()
  self.state.worktree_root = root
  self.worktree_root = root
  self.running = false
  self.callbacks = {}

  -- Register library modules for refresh
  self.lib = {}
  self:register("status", require("neojj.lib.jj.status").meta)
  self:register("log", require("neojj.lib.jj.log").meta)
  self:register("bookmark", require("neojj.lib.jj.bookmark").meta)

  return self
end

---Register a refresh module
---@param name string
---@param mod table Module with update(state) function
function Repo:register(name, mod)
  self.lib[name] = mod
end

---Register a callback to run after next refresh
function Repo:register_callback(source, fn)
  self.callbacks[source] = fn
end

---Run and clear all registered callbacks
function Repo:run_callbacks()
  local cbs = self.callbacks
  self.callbacks = {}
  for _, fn in pairs(cbs) do
    fn()
  end
end

---Reset state to empty
function Repo:reset()
  self.state = empty_state()
  self.state.worktree_root = self.worktree_root
end

---Refresh all state from jj (synchronous).
---All commands use vim.system:wait() which is ~20-90ms each.
---Async approaches (jobstart/vim.system callbacks) add ~800-900ms of event loop
---overhead per command due to Neovim plugin event processing.
---@param opts? { callback?: fun(), source?: string }
function Repo:refresh(opts)
  -- Diagnostic: measure fork and env impact
  local t_true = vim.uv.hrtime()
  local h = io.popen("/usr/bin/true")
  if h then h:close() end
  vim.notify(("[FORK] /usr/bin/true: %.0fms"):format((vim.uv.hrtime() - t_true) / 1e6))

  -- Test jj with stripped env (only PATH and HOME)
  local jj_path = vim.fn.exepath("jj")
  local cwd = self.state.worktree_root
  local t_env = vim.uv.hrtime()
  local h2 = io.popen(("env -i PATH=/usr/bin:/bin HOME=%s %s --no-pager --color=never --ignore-working-copy -R %s status 2>/dev/null"):format(
    vim.fn.shellescape(vim.env.HOME),
    vim.fn.shellescape(jj_path),
    vim.fn.shellescape(cwd)
  ))
  if h2 then h2:read("*a"); h2:close() end
  vim.notify(("[FORK] jj status (env -i): %.0fms"):format((vim.uv.hrtime() - t_env) / 1e6))

  -- Test git for comparison
  local t_git = vim.uv.hrtime()
  local h3 = io.popen("git --no-pager -C " .. vim.fn.shellescape(cwd) .. " status --porcelain 2>/dev/null")
  if h3 then h3:read("*a"); h3:close() end
  vim.notify(("[FORK] git status: %.0fms"):format((vim.uv.hrtime() - t_git) / 1e6))

  local t_refresh = vim.uv.hrtime()
  opts = opts or {}

  if opts.callback and opts.source then
    self:register_callback(opts.source, opts.callback)
  end

  -- Status first (triggers jj working copy snapshot), then log/bookmark
  for name, mod in pairs(self.lib) do
    if name == "status" and mod.update then
      mod.update(self.state)
    end
  end

  for name, mod in pairs(self.lib) do
    if name ~= "status" and mod.update then
      mod.update(self.state)
    end
  end

  vim.notify(("[REPO] refresh total: %.0fms"):format((vim.uv.hrtime() - t_refresh) / 1e6))
  self:run_callbacks()
end

---Dispatch refresh (runs synchronously, then callbacks update UI).
---Wrapped in vim.schedule to avoid blocking the caller's context.
function Repo:dispatch_refresh(opts)
  vim.schedule(function()
    self:refresh(opts)
  end)
end

M.instance = Repo.instance
M.Repo = Repo

return M
