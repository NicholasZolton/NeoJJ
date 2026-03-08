local M = {}

local jj = require("neojj.lib.jj")
local notification = require("neojj.lib.notification")
local FuzzyFinderBuffer = require("neojj.buffers.fuzzy_finder")
local picker_cache = require("neojj.lib.picker_cache")

---@param result table?
---@return string
local function push_error_msg(result)
  local stderr = picker_cache.error_msg(result)
  if stderr:match("not a descendant") or stderr:match("unexpectedly moved") or stderr:match("was updated") then
    return "Remote has changed — fetch first, then retry"
  end
  return stderr
end

function M.push_bookmark(popup)
  local bookmarks = picker_cache.get_local_bookmark_names()
  local name = FuzzyFinderBuffer.new(bookmarks):open_async { prompt_prefix = "Push bookmark" }
  if not name then
    return
  end

  notification.info("Pushing bookmark " .. name)
  local args = popup:get_arguments()
  local builder = jj.cli.git_push.bookmark(name)
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call()
  if result and result.code == 0 then
    notification.info("Pushed " .. name, { dismiss = true })
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

  notification.info("Pushing change " .. rev)
  local args = popup:get_arguments()
  local builder = jj.cli.git_push.change(rev)
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call()
  if result and result.code == 0 then
    notification.info("Pushed change " .. rev, { dismiss = true })
  else
    notification.warn("Push failed: " .. push_error_msg(result), { dismiss = true })
  end
end

function M.push_all(popup)
  notification.info("Pushing all bookmarks")
  local args = popup:get_arguments()
  local builder = jj.cli.git_push.all
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call()
  if result and result.code == 0 then
    notification.info("Pushed all bookmarks", { dismiss = true })
  else
    notification.warn("Push failed: " .. push_error_msg(result), { dismiss = true })
  end
end

return M
