local M = {}

local jj = require("neojj.lib.jj")
local input = require("neojj.lib.input")
local notification = require("neojj.lib.notification")
local FuzzyFinderBuffer = require("neojj.buffers.fuzzy_finder")

local function get_local_bookmarks()
  local items = jj.repo.state.bookmarks.items
  local names = {}
  for _, item in ipairs(items) do
    if not item.remote then
      table.insert(names, item.name)
    end
  end
  return names
end

local function get_remote_bookmarks()
  local items = jj.repo.state.bookmarks.items
  local names = {}
  for _, item in ipairs(items) do
    if item.remote then
      table.insert(names, item.name .. "@" .. item.remote)
    end
  end
  return names
end

function M.create(_popup)
  local name = input.get_user_input("Bookmark name")
  if not name or name == "" then
    return
  end

  local result = jj.cli.bookmark_create.args(name).call()
  if result and result.code == 0 then
    notification.info("Created bookmark " .. name, { dismiss = true })
  else
    notification.warn("Failed to create bookmark", { dismiss = true })
  end
end

function M.move(popup)
  local bookmarks = get_local_bookmarks()
  local name = FuzzyFinderBuffer.new(bookmarks):open_async { prompt_prefix = "Move bookmark" }
  if not name then
    return
  end

  local args = popup:get_arguments()
  local builder = jj.cli.bookmark_move.args(name)
  -- --allow-backwards may be in popup args
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call()
  if result and result.code == 0 then
    notification.info("Moved bookmark " .. name, { dismiss = true })
  else
    notification.warn("Failed to move bookmark", { dismiss = true })
  end
end

function M.delete(_popup)
  local bookmarks = get_local_bookmarks()
  local name = FuzzyFinderBuffer.new(bookmarks):open_async { prompt_prefix = "Delete bookmark" }
  if not name then
    return
  end

  if not input.get_permission(("Delete bookmark '%s'?"):format(name)) then
    return
  end

  local result = jj.cli.bookmark_delete.args(name).call()
  if result and result.code == 0 then
    notification.info("Deleted bookmark " .. name, { dismiss = true })
  else
    notification.warn("Failed to delete bookmark", { dismiss = true })
  end
end

function M.forget(_popup)
  local bookmarks = get_local_bookmarks()
  local name = FuzzyFinderBuffer.new(bookmarks):open_async { prompt_prefix = "Forget bookmark" }
  if not name then
    return
  end

  if not input.get_permission(("Forget bookmark '%s'?"):format(name)) then
    return
  end

  local result = jj.cli.bookmark_forget.args(name).call()
  if result and result.code == 0 then
    notification.info("Forgot bookmark " .. name, { dismiss = true })
  else
    notification.warn("Failed to forget bookmark", { dismiss = true })
  end
end

function M.track(_popup)
  local bookmarks = get_remote_bookmarks()
  local name = FuzzyFinderBuffer.new(bookmarks):open_async { prompt_prefix = "Track bookmark" }
  if not name then
    return
  end

  local result = jj.cli.bookmark_track.args(name).call()
  if result and result.code == 0 then
    notification.info("Tracking " .. name, { dismiss = true })
  else
    notification.warn("Failed to track bookmark", { dismiss = true })
  end
end

return M
