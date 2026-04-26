local RPC = require("neojj.lib.rpc")
local logger = require("neojj.logger")
local config = require("neojj.config")

local fn = vim.fn
local fmt = string.format

local M = {}

--- Quote a string for use in a shlex-parsed command string.
--- Uses double quotes with proper escaping (backslash for \, ", $, `).
--- This is compatible with Rust's shlex crate, unlike vim.fn.shellescape()
--- which uses the '\'' idiom that shlex does not support.
---@param s string
---@return string
local function shlex_quote(s)
  if s == "" then
    return '""'
  end
  -- If the string has no special characters, return as-is
  if not s:find("[%s'\"\\$`#&|;()<>!{}]") then
    return s
  end
  -- Double-quote with escaping for \, ", $, `
  local escaped = s:gsub('[\\"`$]', "\\%0")
  return '"' .. escaped .. '"'
end

function M.get_nvim_remote_editor(show_diff)
  local neojj_path = debug.getinfo(1, "S").source:sub(2, -#"lua/neojj/client.lua" - 2)
  local nvim_path = shlex_quote(vim.v.progpath)

  logger.debug("[CLIENT] Neojj path: " .. neojj_path)
  logger.debug("[CLIENT] Neovim path: " .. nvim_path)
  local runtimepath_cmd = shlex_quote(fmt("set runtimepath^=%s", fn.fnameescape(tostring(neojj_path))))
  local lua_cmd =
    shlex_quote("lua require('neojj.client').client({ show_diff = " .. tostring(show_diff) .. " })")

  local shell_cmd = {
    nvim_path,
    "--headless",
    "--clean",
    "--noplugin",
    "-n",
    "-R",
    "-c",
    runtimepath_cmd,
    "-c",
    lua_cmd,
  }

  return table.concat(shell_cmd, " ")
end

---@param show_diff boolean
---@param revision? string Optional revision for diff context
function M.get_envs_git_editor(show_diff, revision)
  local nvim_cmd = M.get_nvim_remote_editor(show_diff)

  local env = {
    JJ_EDITOR = nvim_cmd,
  }

  if revision then
    env.NEOJJ_DESCRIBE_REVISION = revision
  end

  if os.getenv("NEOJJ_DEBUG") then
    env.NEOJJ_LOG_LEVEL = "debug"
    env.NEOJJ_LOG_FILE = "true"
    env.NEOJJ_DEBUG = true
  end

  return env
end

--- Entry point for the headless client.
--- Starts a server and connects to the parent process rpc, opening an editor
function M.client(opts)
  local nvim_server = vim.env.NVIM
  if not nvim_server then
    error("NVIM server address not set")
  end

  local file_target = fn.fnamemodify(fn.argv()[1], ":p")
  logger.debug(("[CLIENT] File target: %s"):format(file_target))

  local client = fn.serverstart()
  logger.debug(("[CLIENT] Client address: %s"):format(client))

  -- Read revision from env (set by parent on the jj process, inherited by this headless nvim)
  local revision = vim.env.NEOJJ_DESCRIBE_REVISION
  local revision_arg = revision and fmt("%q", revision) or "nil"

  local lua_cmd = fmt(
    'lua require("neojj.client").editor(%q, %q, %s, %s)',
    file_target,
    client,
    opts.show_diff,
    revision_arg
  )
  local rpc_server = RPC.create_connection(nvim_server)
  rpc_server:send_cmd(lua_cmd)
end

--- Invoked by the `client` and starts the appropriate file editor
---@param target string Filename to open
---@param client string Address returned from vim.fn.serverstart()
---@param show_diff boolean
---@param revision? string Optional revision for diff context
function M.editor(target, client, show_diff, revision)
  logger.debug(("[CLIENT] Invoked editor with target: %s, from: %s"):format(target, client))
  require("neojj.process").hide_preview_buffers()

  local rpc_client = RPC.create_connection(client)

  ---on_unload callback when closing editor
  ---@param status integer Status code to close remote nvim instance with. 0 for success, 1 for failure
  local function send_client_quit(status)
    if status == 0 then
      rpc_client:send_cmd_async("qall")
    elseif status == 1 then
      rpc_client:send_cmd_async("cq")
    end

    rpc_client:disconnect()
  end

  local kind
  if
    target:find("COMMIT_EDITMSG$")
    or target:find("EDIT_DESCRIPTION$")
    or target:find("%.jjdescription$")
  then
    kind = config.values.commit_editor.kind
  else
    kind = "auto"
  end

  local editor = require("neojj.buffers.editor")
  editor.new(target, send_client_quit, show_diff, revision):open(kind)
end

---@class NotifyMsg
---@field setup string|nil Message to show before running
---@field success string|nil Message to show when successful
---@field fail string|nil Message to show when failed

---@class WrapOpts
---@field autocmd string
---@field msg NotifyMsg
---@field show_diff boolean?
---@field interactive boolean?
---@field revision string? Optional revision for diff context

---@param cmd any
---@param opts WrapOpts
---@return integer code of `cmd`
function M.wrap(cmd, opts)
  local notification = require("neojj.lib.notification")
  local a = require("plenary.async")

  a.util.scheduler()

  if opts.msg.setup then
    notification.info(opts.msg.setup)
  end

  logger.debug("[CLIENT] Calling editor command")
  local result = cmd.env(M.get_envs_git_editor(opts.show_diff, opts.revision)).call { pty = opts.interactive }

  a.util.scheduler()
  logger.debug("[CLIENT] DONE editor command")

  if result:success() then
    if opts.msg.success then
      notification.info(opts.msg.success, { dismiss = true })
    end
    vim.api.nvim_exec_autocmds("User", { pattern = opts.autocmd, modeline = false })
  else
    local fail_msg = opts.msg.fail
    if fail_msg then
      -- In PTY mode stderr is merged into stdout, so check both
      local output = result.stderr
      if type(output) == "table" then
        output = table.concat(output, "\n")
      end
      if (not output or output == "") and result.stdout then
        output = result.stdout
        if type(output) == "table" then
          output = table.concat(output, "\n")
        end
      end

      if output and output ~= "" then
        fail_msg = fail_msg .. ": " .. output
      end
      notification.warn(fail_msg, { dismiss = true })
    end
  end

  return result.code
end

return M
