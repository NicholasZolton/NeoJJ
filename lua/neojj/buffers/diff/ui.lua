local M = {}

local Ui = require("neojj.lib.ui")
local util = require("neojj.lib.util")
local common_ui = require("neojj.buffers.common")

local Diff = common_ui.Diff
local EmptyLine = common_ui.EmptyLine
local text = Ui.text
local col = Ui.col
local row = Ui.row
local map = util.map

function M.OverviewFile(file_padding)
  return function(file)
    return row.tag("OverviewFile") {
      text.highlight("NeoJJFilePath")(util.pad_right(file.path, file_padding)),
      text("  | "),
      text.highlight("Number")(util.pad_left(file.changes or "0", 5)),
      text("  "),
      text.highlight("NeoJJDiffAdditions")(file.insertions),
      text.highlight("NeoJJDiffDeletions")(file.deletions),
    }
  end
end

function M.DiffView(header, stats, diffs)
  local file_padding = util.max_length(map(diffs, function(diff)
    return diff.file
  end))

  return {
    text.highlight("NeoJJFloatHeaderHighlight")(header),
    text(stats.summary),
    col(map(stats.files, M.OverviewFile(file_padding)), { tag = "OverviewFileList" }),
    EmptyLine(),
    col(map(diffs, Diff), { tag = "DiffList" }),
  }
end
return M
