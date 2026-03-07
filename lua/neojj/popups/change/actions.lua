local M = {}

local jj = require("neojj.lib.jj")
local notification = require("neojj.lib.notification")
local FuzzyFinderBuffer = require("neojj.buffers.fuzzy_finder")

local function get_recent_change_ids()
  local items = jj.repo.state.recent.items
  local ids = {}
  for _, item in ipairs(items) do
    local short = string.sub(item.change_id, 1, 12)
    local desc = item.description ~= "" and item.description or "(no description)"
    table.insert(ids, short .. " " .. desc)
  end
  return ids
end

local function extract_change_id(selection)
  if not selection then
    return nil
  end
  return selection:match("^(%S+)")
end

function M.new_change(popup)
  local args = popup:get_arguments()
  local builder = jj.cli.new
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call()
  if result and result.code == 0 then
    notification.info("Created new change", { dismiss = true })
  else
    notification.warn("Failed to create new change", { dismiss = true })
  end
end

function M.new_on_revisions(popup)
  local options = get_recent_change_ids()
  local selection = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "New change on" }
  local rev = extract_change_id(selection)
  if not rev then
    return
  end

  local args = popup:get_arguments()
  local builder = jj.cli.new.revisions(rev)
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call()
  if result and result.code == 0 then
    notification.info("Created new change on " .. rev, { dismiss = true })
  else
    notification.warn("Failed to create change", { dismiss = true })
  end
end

function M.merge(popup)
  local options = get_recent_change_ids()
  local first = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "First parent" }
  local rev1 = extract_change_id(first)
  if not rev1 then
    return
  end

  local second = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "Second parent" }
  local rev2 = extract_change_id(second)
  if not rev2 then
    return
  end

  local args = popup:get_arguments()
  local builder = jj.cli.new.revisions(rev1, rev2)
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call()
  if result and result.code == 0 then
    notification.info("Created merge change", { dismiss = true })
  else
    notification.warn("Failed to create merge", { dismiss = true })
  end
end

return M
