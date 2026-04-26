local M = {}

local jj = require("neojj.lib.jj")
local notification = require("neojj.lib.notification")
local FuzzyFinderBuffer = require("neojj.buffers.fuzzy_finder")
local picker_cache = require("neojj.lib.picker_cache")

---@param result table?
---@return string
local function push_error_msg(result)
  local stderr = picker_cache.error_msg(result)
  if
    stderr:match("not a descendant")
    or stderr:match("unexpectedly moved")
    or stderr:match("was updated")
  then
    return "Remote has changed — fetch first, then retry"
  end
  return stderr
end

---@param lines string[]?
---@return string[]
local function parse_remotes(lines)
  local names = {}
  for _, line in ipairs(lines or {}) do
    local name = line:match("^(%S+)")
    if name then
      table.insert(names, name)
    end
  end
  return names
end

---@param popup PopupData
---@return string|nil, boolean ok
local function maybe_select_remote(popup)
  local internal = popup:get_internal_arguments()
  if not internal.remote then
    return nil, true
  end

  local remotes_result = jj.cli.git_remote_list.call { hidden = true, trim = true }
  if not remotes_result or remotes_result.code ~= 0 then
    notification.warn("Push failed: " .. picker_cache.error_msg(remotes_result), { dismiss = true })
    return nil, false
  end

  local remotes = parse_remotes(remotes_result.stdout)
  if #remotes == 0 then
    notification.warn("No remotes configured", { dismiss = true })
    return nil, false
  end

  local remote = FuzzyFinderBuffer.new(remotes):open_async { prompt_prefix = "Push remote" }
  if not remote then
    notification.warn("Push aborted: no remote selected", { dismiss = true })
    return nil, false
  end

  return remote, true
end

function M.push(popup)
  local remote, ok = maybe_select_remote(popup)
  if not ok then
    return
  end

  notification.info("Pushing" .. (remote and (" to " .. remote) or ""))
  local args = popup:get_arguments()
  local builder = jj.cli.git_push
  if remote then
    builder = builder.remote(remote)
  end
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call()
  if result and result.code == 0 then
    notification.info("Pushed" .. (remote and (" to " .. remote) or ""), { dismiss = true })
  else
    notification.warn("Push failed: " .. push_error_msg(result), { dismiss = true })
  end
end

function M.push_bookmark(popup)
  local bookmarks = picker_cache.get_local_bookmark_names()
  local name = FuzzyFinderBuffer.new(bookmarks):open_async { prompt_prefix = "Push bookmark" }
  if not name then
    return
  end

  local remote, ok = maybe_select_remote(popup)
  if not ok then
    return
  end

  notification.info("Pushing bookmark " .. name .. (remote and (" to " .. remote) or ""))
  local args = popup:get_arguments()
  local builder = jj.cli.git_push.bookmark(name)
  if remote then
    builder = builder.remote(remote)
  end
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call()
  if result and result.code == 0 then
    notification.info("Pushed " .. name .. (remote and (" to " .. remote) or ""), { dismiss = true })
  else
    notification.warn("Push failed: " .. push_error_msg(result), { dismiss = true })
  end
end

function M.push_change(popup)
  local options = picker_cache.get_all_revisions()
  local selection = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "Push change" }
  local rev = picker_cache.parse_selection(selection)
  if not rev then
    return
  end

  local remote, ok = maybe_select_remote(popup)
  if not ok then
    return
  end

  notification.info("Pushing change " .. rev .. (remote and (" to " .. remote) or ""))
  local args = popup:get_arguments()
  local builder = jj.cli.git_push.change(rev)
  if remote then
    builder = builder.remote(remote)
  end
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call()
  if result and result.code == 0 then
    notification.info("Pushed change " .. rev .. (remote and (" to " .. remote) or ""), { dismiss = true })
  else
    notification.warn("Push failed: " .. push_error_msg(result), { dismiss = true })
  end
end

function M.push_all(popup)
  local remote, ok = maybe_select_remote(popup)
  if not ok then
    return
  end

  notification.info("Pushing all bookmarks" .. (remote and (" to " .. remote) or ""))
  local args = popup:get_arguments()
  local builder = jj.cli.git_push.all
  if remote then
    builder = builder.remote(remote)
  end
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call()
  if result and result.code == 0 then
    notification.info("Pushed all bookmarks" .. (remote and (" to " .. remote) or ""), { dismiss = true })
  else
    notification.warn("Push failed: " .. push_error_msg(result), { dismiss = true })
  end
end

return M
