local M = {}
local jj = require("neojj.lib.jj")
local notification = require("neojj.lib.notification")
local FuzzyFinderBuffer = require("neojj.buffers.fuzzy_finder")
local picker_cache = require("neojj.lib.picker_cache")

local function extract_change_id(selection)
  if not selection then return nil end
  return selection:match("^(%S+)")
end

function M.source_onto(popup)
  local options = picker_cache.get_all_revisions()
  local source_sel = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "Rebase source" }
  local source = extract_change_id(source_sel)
  if not source then return end

  local dest_sel = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "onto destination" }
  local dest = extract_change_id(dest_sel)
  if not dest then return end

  local args = popup:get_arguments()
  local builder = jj.cli.rebase.source(source).destination(dest)
  if #args > 0 then builder = builder.args(unpack(args)) end
  local result = builder.call()
  if result and result.code == 0 then
    picker_cache.invalidate_revisions()
    notification.info("Rebased " .. source .. " onto " .. dest, { dismiss = true })
  else
    notification.warn("Rebase failed", { dismiss = true })
  end
end

function M.bookmark_onto(popup)
  local bookmarks = picker_cache.get_all_bookmarks()
  local bm_sel = FuzzyFinderBuffer.new(bookmarks):open_async { prompt_prefix = "Rebase bookmark" }
  if not bm_sel then return end
  local bm = bm_sel:match("^(%S+)")
  if not bm then return end

  local options = picker_cache.get_all_revisions()
  local dest_sel = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "onto destination" }
  local dest = extract_change_id(dest_sel)
  if not dest then return end

  local args = popup:get_arguments()
  local builder = jj.cli.rebase.branch(bm).destination(dest)
  if #args > 0 then builder = builder.args(unpack(args)) end
  local result = builder.call()
  if result and result.code == 0 then
    picker_cache.invalidate_revisions()
    notification.info("Rebased bookmark " .. bm .. " onto " .. dest, { dismiss = true })
  else
    notification.warn("Rebase failed", { dismiss = true })
  end
end

function M.revision_onto(popup)
  local options = picker_cache.get_all_revisions()
  local rev_sel = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "Rebase revision" }
  local rev = extract_change_id(rev_sel)
  if not rev then return end

  local dest_sel = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "onto destination" }
  local dest = extract_change_id(dest_sel)
  if not dest then return end

  local args = popup:get_arguments()
  local builder = jj.cli.rebase.revision(rev).destination(dest)
  if #args > 0 then builder = builder.args(unpack(args)) end
  local result = builder.call()
  if result and result.code == 0 then
    picker_cache.invalidate_revisions()
    notification.info("Rebased " .. rev .. " onto " .. dest, { dismiss = true })
  else
    notification.warn("Rebase failed", { dismiss = true })
  end
end

function M.here_onto(popup)
  local options = picker_cache.get_all_revisions()
  local dest_sel = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "Rebase @ onto" }
  local dest = extract_change_id(dest_sel)
  if not dest then return end

  local args = popup:get_arguments()
  local builder = jj.cli.rebase.source("@").destination(dest)
  if #args > 0 then builder = builder.args(unpack(args)) end
  local result = builder.call()
  if result and result.code == 0 then
    picker_cache.invalidate_revisions()
    notification.info("Rebased @ onto " .. dest, { dismiss = true })
  else
    notification.warn("Rebase failed", { dismiss = true })
  end
end

function M.onto_trunk(popup)
  notification.info("Fetching from remote...", { dismiss = true })
  local fetch_result = jj.cli.git_fetch.call()
  if not fetch_result or fetch_result.code ~= 0 then
    notification.warn("Fetch failed", { dismiss = true })
    return
  end

  local args = popup:get_arguments()
  local builder = jj.cli.rebase.source("@-").destination("trunk()")
  if #args > 0 then builder = builder.args(unpack(args)) end
  local result = builder.call()
  if result and result.code == 0 then
    picker_cache.invalidate()
    notification.info("Rebased onto trunk", { dismiss = true })
  else
    local err = result and (type(result.stderr) == "string" and result.stderr or vim.inspect(result.stderr)) or "unknown error"
    notification.warn("Rebase onto trunk failed: " .. err, { dismiss = true })
  end
end

function M.parallelize(_popup)
  local options = picker_cache.get_all_revisions()
  local sel = FuzzyFinderBuffer.new(options):open_async { prompt_prefix = "Parallelize from" }
  local change_id = extract_change_id(sel)
  if not change_id then return end

  local result = jj.cli.parallelize.args(change_id .. "::@").call()
  if result and result.code == 0 then
    picker_cache.invalidate_revisions()
    notification.info("Parallelized changes", { dismiss = true })
  else
    notification.warn("Parallelize failed", { dismiss = true })
  end
end

return M
