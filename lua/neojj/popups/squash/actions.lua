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

function M.squash(popup)
  local args = popup:get_arguments()
  local builder = jj.cli.squash
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call { pty = true }
  if result and result.code == 0 then
    notification.info("Squashed into parent", { dismiss = true })
  else
    notification.warn("Squash failed", { dismiss = true })
  end
end

function M.squash_into(popup)
  local options = get_recent_change_ids()
  local selection = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "Squash into" }
  local rev = extract_change_id(selection)
  if not rev then
    return
  end

  local args = popup:get_arguments()
  local builder = jj.cli.squash.into(rev)
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call { pty = true }
  if result and result.code == 0 then
    notification.info("Squashed into " .. rev, { dismiss = true })
  else
    notification.warn("Squash failed", { dismiss = true })
  end
end

return M
