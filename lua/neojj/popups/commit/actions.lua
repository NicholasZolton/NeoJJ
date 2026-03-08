local M = {}

local jj = require("neojj.lib.jj")
local client = require("neojj.client")
local input = require("neojj.lib.input")
local notification = require("neojj.lib.notification")
local FuzzyFinderBuffer = require("neojj.buffers.fuzzy_finder")
local picker_cache = require("neojj.lib.picker_cache")

function M.commit(popup)
  local args = popup:get_arguments()
  local builder = jj.cli.commit
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  client.wrap(builder, {
    autocmd = "NeoJJCommitComplete",
    msg = {
      success = "Committed",
      fail = "Commit aborted",
    },
    show_diff = true,
    interactive = true,
  })
end

function M.new_change(popup)
  local args = popup:get_arguments()
  local builder = jj.cli.new
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call()
  if result and result.code == 0 then
    picker_cache.invalidate_revisions()
    notification.info("Created new change", { dismiss = true })
  else
    notification.warn("Failed to create new change", { dismiss = true })
  end
end

function M.describe(popup)
  local args = popup:get_arguments()
  local builder = jj.cli.describe
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  client.wrap(builder, {
    autocmd = "NeoJJDescribeComplete",
    msg = {
      success = "Description updated",
      fail = "Describe failed",
    },
    show_diff = true,
    interactive = true,
  })
end

function M.describe_with_message(popup)
  local msg = input.get_user_input("Describe change")
  if not msg or msg == "" then
    return
  end

  local args = popup:get_arguments()
  local builder = jj.cli.describe.no_edit.message(msg)
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call()
  if result and result.code == 0 then
    picker_cache.invalidate_revisions()
    notification.info("Description updated", { dismiss = true })
  else
    notification.warn("Describe failed", { dismiss = true })
  end
end

function M.edit_change(_popup)
  local revisions = picker_cache.get_all_revisions()
  if #revisions == 0 then
    notification.warn("No revisions found", { dismiss = true })
    return
  end

  local selection = FuzzyFinderBuffer.new(revisions):open_async { prompt_prefix = "Edit change" }
  if not selection then
    return
  end

  local change_id = selection:match("^(%S+)")
  if not change_id then
    return
  end

  local result = jj.cli.edit.args(change_id).call()
  if result and result.code == 0 then
    notification.info("Now editing " .. change_id, { dismiss = true })
  else
    notification.warn("Failed to edit change", { dismiss = true })
  end
end

function M.edit_bookmark(_popup)
  local bookmarks = picker_cache.get_all_bookmarks()
  if #bookmarks == 0 then
    notification.warn("No bookmarks found", { dismiss = true })
    return
  end

  local selection = FuzzyFinderBuffer.new(bookmarks):open_async { prompt_prefix = "Edit bookmark" }
  if not selection then
    return
  end

  local bookmark_name = selection:match("^(%S+)")
  if not bookmark_name then
    return
  end

  local result = jj.cli.edit.args(bookmark_name).call()
  if result and result.code == 0 then
    notification.info("Now editing " .. bookmark_name, { dismiss = true })
  else
    notification.warn("Failed to edit bookmark", { dismiss = true })
  end
end

function M.abandon(_popup)
  local revisions = picker_cache.get_all_revisions()
  if #revisions == 0 then
    notification.warn("No revisions found", { dismiss = true })
    return
  end

  local selection = FuzzyFinderBuffer.new(revisions):open_async { prompt_prefix = "Abandon change" }
  if not selection then
    return
  end

  local change_id = selection:match("^(%S+)")
  if not change_id then
    return
  end

  if not input.get_permission("Abandon " .. change_id .. "?") then
    return
  end

  local result = jj.cli.abandon.args(change_id).call()
  if result and result.code == 0 then
    picker_cache.remove_revision(change_id)
    notification.info("Abandoned " .. change_id, { dismiss = true })
  else
    notification.warn("Failed to abandon change", { dismiss = true })
  end
end

function M.duplicate(_popup)
  local revisions = picker_cache.get_all_revisions()
  if #revisions == 0 then
    notification.warn("No revisions found", { dismiss = true })
    return
  end

  local selection = FuzzyFinderBuffer.new(revisions):open_async { prompt_prefix = "Duplicate change" }
  if not selection then
    return
  end

  local change_id = selection:match("^(%S+)")
  if not change_id then
    return
  end

  local result = jj.cli.duplicate.args(change_id).call()
  if result and result.code == 0 then
    picker_cache.invalidate_revisions()
    notification.info("Duplicated " .. change_id, { dismiss = true })
  else
    notification.warn("Failed to duplicate change", { dismiss = true })
  end
end

function M.revert(_popup)
  local revisions = picker_cache.get_all_revisions()
  if #revisions == 0 then
    notification.warn("No revisions found", { dismiss = true })
    return
  end

  local selection = FuzzyFinderBuffer.new(revisions):open_async { prompt_prefix = "Revert change" }
  if not selection then
    return
  end

  local change_id = selection:match("^(%S+)")
  if not change_id then
    return
  end

  local result = jj.cli.revert.args(change_id).call()
  if result and result.code == 0 then
    picker_cache.invalidate_revisions()
    notification.info("Reverted " .. change_id, { dismiss = true })
  else
    notification.warn("Failed to revert change", { dismiss = true })
  end
end

return M
