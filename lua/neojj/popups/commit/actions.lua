local M = {}

local jj = require("neojj.lib.jj")
local input = require("neojj.lib.input")
local notification = require("neojj.lib.notification")

function M.commit(popup)
  -- jj commit without -m opens editor
  local args = popup:get_arguments()
  local builder = jj.cli.commit
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call { pty = true }
  if result and result.code == 0 then
    notification.info("Committed", { dismiss = true })
  else
    notification.warn("Commit failed", { dismiss = true })
  end
end

function M.commit_with_message(popup)
  local msg = input.get_user_input("Commit message")
  if not msg or msg == "" then
    return
  end

  local args = popup:get_arguments()
  local builder = jj.cli.commit.message(msg)
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call()
  if result and result.code == 0 then
    notification.info("Committed", { dismiss = true })
  else
    notification.warn("Commit failed", { dismiss = true })
  end
end

function M.describe(popup)
  -- jj describe without -m opens editor
  local args = popup:get_arguments()
  local builder = jj.cli.describe
  if #args > 0 then
    builder = builder.args(unpack(args))
  end
  local result = builder.call { pty = true }
  if result and result.code == 0 then
    notification.info("Description updated", { dismiss = true })
  else
    notification.warn("Describe failed", { dismiss = true })
  end
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
    notification.info("Description updated", { dismiss = true })
  else
    notification.warn("Describe failed", { dismiss = true })
  end
end

return M
