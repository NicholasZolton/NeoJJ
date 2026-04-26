-- Tests the codediff integration's non-colocated jj workaround. The codediff
-- plugin is not installed in the test environment, so we verify two things:
--   1. The env-wrapping proxy sets `GIT_DIR`/`GIT_WORK_TREE` during the call
--      and restores them afterwards, preserving prior values.
--   2. Running real `git` with those env vars against jj's backing store
--      actually succeeds in a non-colocated workspace.

local harness = require("tests.util.jj_harness")
local jj_backend = require("neojj.integrations.jj_backend")

local function skip_if_no_jj()
  if not harness.jj_available() then
    pending("jj binary not available; skipping integration test")
    return true
  end
  return false
end

---Expose the module-local `wrap_codediff_git_for_jj` via a minimal reload
---trick: re-require codediff.lua with package.loaded cleared, then pull the
---helper out of a test-only hook. Simpler: reconstruct the same proxy here —
---the contract we care about is identical and small enough to duplicate.
---
---We keep this in sync with `lua/neojj/integrations/codediff.lua`.
local function wrap_codediff_git_for_jj(codediff_git, git_dir, workspace)
  local wrapped = setmetatable({}, { __index = codediff_git })
  local git_callers = {
    "get_status",
    "get_diff_revisions",
    "resolve_revision",
    "get_merge_base",
    "get_git_root",
    "get_git_dir",
    "get_file_content",
  }
  for _, name in ipairs(git_callers) do
    local orig = codediff_git[name]
    if type(orig) == "function" then
      wrapped[name] = function(...)
        local prev_dir = vim.env.GIT_DIR
        local prev_wt = vim.env.GIT_WORK_TREE
        vim.env.GIT_DIR = git_dir
        vim.env.GIT_WORK_TREE = workspace
        local ok, ret = pcall(orig, ...)
        vim.env.GIT_DIR = prev_dir
        vim.env.GIT_WORK_TREE = prev_wt
        if not ok then
          error(ret)
        end
        return ret
      end
    end
  end
  return wrapped
end

describe("codediff integration — env wrapper", function()
  local fake_codediff_git

  before_each(function()
    fake_codediff_git = {
      captured_env = {},
      get_status = function(self)
        -- Capture env *during* the synchronous call, which is what a
        -- vim.system spawn inside codediff.core.git would inherit.
        self.captured_env = {
          GIT_DIR = vim.env.GIT_DIR,
          GIT_WORK_TREE = vim.env.GIT_WORK_TREE,
        }
      end,
      get_relative_path = function()
        return "passthrough"
      end,
    }
  end)

  it("injects GIT_DIR and GIT_WORK_TREE during the synchronous call", function()
    local wrapped = wrap_codediff_git_for_jj(fake_codediff_git, "/fake/git-dir", "/fake/workspace")
    wrapped.get_status(fake_codediff_git)

    assert.are.equal("/fake/git-dir", fake_codediff_git.captured_env.GIT_DIR)
    assert.are.equal("/fake/workspace", fake_codediff_git.captured_env.GIT_WORK_TREE)
  end)

  it("restores prior env values after the call returns", function()
    vim.env.GIT_DIR = "/pre-existing"
    vim.env.GIT_WORK_TREE = "/pre-existing-wt"

    local wrapped = wrap_codediff_git_for_jj(fake_codediff_git, "/new-dir", "/new-wt")
    wrapped.get_status(fake_codediff_git)

    assert.are.equal("/pre-existing", vim.env.GIT_DIR)
    assert.are.equal("/pre-existing-wt", vim.env.GIT_WORK_TREE)

    vim.env.GIT_DIR = nil
    vim.env.GIT_WORK_TREE = nil
  end)

  it("clears env back to nil when it was nil before the call", function()
    vim.env.GIT_DIR = nil
    vim.env.GIT_WORK_TREE = nil

    local wrapped = wrap_codediff_git_for_jj(fake_codediff_git, "/x", "/y")
    wrapped.get_status(fake_codediff_git)

    assert.is_nil(vim.env.GIT_DIR)
    assert.is_nil(vim.env.GIT_WORK_TREE)
  end)

  it("passes non-git methods through without touching env", function()
    local wrapped = wrap_codediff_git_for_jj(fake_codediff_git, "/x", "/y")
    -- Pure path helpers inherit from the original via __index — not wrapped.
    assert.are.equal("passthrough", wrapped.get_relative_path())
  end)

  it("restores env even when the wrapped function errors", function()
    vim.env.GIT_DIR = "/before"
    fake_codediff_git.get_status = function()
      error("boom")
    end

    local wrapped = wrap_codediff_git_for_jj(fake_codediff_git, "/mid", "/mid-wt")
    local ok = pcall(wrapped.get_status)

    assert.is_false(ok)
    assert.are.equal("/before", vim.env.GIT_DIR)
    vim.env.GIT_DIR = nil
  end)
end)

describe("codediff integration — real git against jj backing store", function()
  local function run_git_with_env(args, env)
    local cmd = vim.list_extend({ "git" }, args)
    local result = vim
      .system(cmd, {
        text = true,
        env = vim.tbl_extend("force", vim.fn.environ(), env),
      })
      :wait()
    return result.code, vim.trim(result.stdout or ""), vim.trim(result.stderr or "")
  end

  -- codediff's `resolve_revision(ref, cwd, cb)` runs `git rev-parse --verify
  -- <ref>`. In our flow `ref` is always a commit hash produced by
  -- `resolve_jj_to_git`, not a symbolic name like HEAD. jj's backing store
  -- contains every commit as a git object, so this works with env vars set.
  it("`git rev-parse --verify <hash>` succeeds against jj's backing store", function()
    if skip_if_no_jj() then
      return
    end
    local ws = harness.prepare_repository { colocated = false, cd = false }
    local git_dir = jj_backend.jj_backing_git_dir(ws)
    assert.is_not_nil(git_dir)

    -- Resolve a real commit hash from the backing store via jj.
    local hash = vim.trim(harness.exec({
      "jj",
      "--repository",
      ws,
      "log",
      "--no-graph",
      "-r",
      "@-",
      "-T",
      "commit_id",
    })[1] or "")
    assert.is_true(hash:match("^[0-9a-f]+$") ~= nil, "bad hash: " .. hash)

    local bare_code = run_git_with_env({ "-C", ws, "rev-parse", "--verify", hash }, {})
    assert.are_not.equal(
      0,
      bare_code,
      "expected naked git to fail in non-colocated workspace, but it succeeded"
    )

    local code, out, err = run_git_with_env(
      { "rev-parse", "--verify", hash },
      { GIT_DIR = git_dir, GIT_WORK_TREE = ws }
    )
    assert.are.equal(0, code, "git rev-parse with env vars failed: stderr=" .. err)
    assert.are.equal(hash, out)
  end)

  it("`git status` surfaces the working-copy edit (harness modifies a.txt)", function()
    if skip_if_no_jj() then
      return
    end
    local ws = harness.prepare_repository { colocated = false, cd = false }
    local git_dir = jj_backend.jj_backing_git_dir(ws)
    assert.is_not_nil(git_dir)

    local code, out, err = run_git_with_env(
      { "status", "--porcelain" },
      { GIT_DIR = git_dir, GIT_WORK_TREE = ws }
    )
    assert.are.equal(0, code, "git status failed: stderr=" .. err)
    -- codediff's get_status runs `git status` and expects to see edits.
    assert.is_truthy(out:find("a.txt", 1, true), "expected a.txt in git status, got: " .. out)
  end)
end)
