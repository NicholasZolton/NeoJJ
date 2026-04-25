local Path = require("plenary.path")
local config = require("neojj.config")
local editor = require("neojj.buffers.editor")

describe("editor buffer", function()
  local events
  local group
  local tmp

  before_each(function()
    config.values = config.get_default_values()
    config.values.disable_insert_on_commit = true
    config.values.commit_editor.kind = "floating"

    events = {}
    group = vim.api.nvim_create_augroup("NeojjEditorSpec", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "jjdescription",
      callback = function()
        table.insert(events, "jjdescription")
      end,
    })

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "jjcommit",
      callback = function()
        table.insert(events, "jjcommit")
      end,
    })

    tmp = Path:new(vim.fn.tempname() .. ".jjdescription")
    tmp:write("summary\n\nJJ: Change ID: abc123\n", "w")
  end)

  after_each(function()
    pcall(vim.api.nvim_del_augroup_by_id, group)
    pcall(vim.api.nvim_buf_delete, vim.fn.bufnr(tmp:absolute()), { force = true })
    pcall(function()
      tmp:rm()
    end)
  end)

  it("uses jjdescription without triggering jjcommit filetype hooks", function()
    editor.new(tmp:absolute(), function() end, false):open("floating")

    assert.are.same({ "jjdescription" }, events)
    assert.are.equal("jjdescription", vim.bo[vim.fn.bufnr(tmp:absolute())].filetype)
  end)
end)
