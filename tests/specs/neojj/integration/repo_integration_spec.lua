-- End-to-end integration tests that exercise the primitives the rewired
-- consumers (autocmds, jump, popup/builder, popup/init) depend on. These run
-- against a real `jj` binary and cover both colocated and non-colocated
-- workspaces, since non-colocated mode is where git-only tooling regressed.

local harness = require("tests.util.jj_harness")
local Repo = require("neojj.lib.jj.repository").Repo
local jj = require("neojj.lib.jj")
local jj_config = require("neojj.lib.jj.config")

local function skip_if_no_jj()
  if not harness.jj_available() then
    pending("jj binary not available; skipping integration test")
    return true
  end
  return false
end

---@param colocated boolean
---@return string working_dir
local function make_repo(colocated)
  return harness.prepare_repository { colocated = colocated }
end

---Build a table of test cases parameterized by colocation mode so each
---assertion runs once for each layout.
local modes = {
  { name = "colocated", colocated = true },
  { name = "non-colocated", colocated = false },
}

for _, mode in ipairs(modes) do
  describe("Repo:refresh — " .. mode.name, function()
    local repo, working_dir

    before_each(function()
      if skip_if_no_jj() then return end
      working_dir = make_repo(mode.colocated)
      repo = Repo.new(working_dir)
      repo:refresh()
    end)

    it("populates head with a valid change_id and commit_id", function()
      if skip_if_no_jj() then return end
      assert.is_string(repo.state.head.change_id)
      assert.is_true(#repo.state.head.change_id > 0)
      assert.is_string(repo.state.head.commit_id)
      assert.is_true(#repo.state.head.commit_id > 0)
    end)

    it("populates parent change_id (harness creates @- via `jj new`)", function()
      if skip_if_no_jj() then return end
      assert.is_string(repo.state.parent.change_id)
      assert.is_true(#repo.state.parent.change_id > 0)
    end)

    it("lists the working-copy modification (harness modifies a.txt)", function()
      if skip_if_no_jj() then return end
      local files = repo.state.files.items
      local names = {}
      for _, f in ipairs(files) do table.insert(names, f.name) end
      assert.is_true(vim.tbl_contains(names, "a.txt"),
        "expected 'a.txt' in working-copy changes, got: " .. vim.inspect(names))
    end)

    it("includes the 'main' bookmark created by the harness", function()
      if skip_if_no_jj() then return end
      local bookmarks = repo.state.bookmarks.items
      local names = {}
      for _, b in ipairs(bookmarks) do table.insert(names, b.name) end
      assert.is_true(vim.tbl_contains(names, "main"),
        "expected 'main' bookmark, got: " .. vim.inspect(names))
    end)
  end)

  describe("jj file_show at @- — " .. mode.name, function()
    local working_dir

    before_each(function()
      if skip_if_no_jj() then return end
      working_dir = make_repo(mode.colocated)
    end)

    -- `jump.lua` and the diffview integration both rely on reading historical
    -- file contents via `jj.cli.file_show.revision(<rev>).args(<path>)`.
    it("returns the committed content of a.txt at the parent revision", function()
      if skip_if_no_jj() then return end
      local result = jj.cli.file_show
        .revision("@-")
        .args("a.txt")
        .call { await = true, trim = false, ignore_error = true }

      assert.is_not_nil(result)
      assert.are.equal(0, result.code)
      local content = type(result.stdout) == "table"
        and table.concat(result.stdout, "\n")
        or (result.stdout or "")
      assert.is_truthy(content:find("line 1", 1, true))
      assert.is_truthy(content:find("line 2", 1, true))
      assert.is_truthy(content:find("line 3", 1, true))
      assert.is_falsy(content:find("modified", 1, true),
        "@- should hold the unmodified version, but diff leaked in: " .. content)
    end)
  end)

  describe("jj config round-trip (repo-scoped) — " .. mode.name, function()
    before_each(function()
      if skip_if_no_jj() then return end
      make_repo(mode.colocated)
    end)

    -- `popup/builder.lua` and `popup/init.lua` drive repo-scoped config through
    -- this API to persist switch/option toggles.
    it("set -> get -> unset round-trips a namespaced key", function()
      if skip_if_no_jj() then return end
      local key = "neojj.test.integration." .. tostring(math.random(1, 2 ^ 30))

      assert.is_false(jj_config.get(key):is_set())

      jj_config.set(key, "hello")
      assert.are.equal("hello", jj_config.get(key):read())

      jj_config.unset(key)
      assert.is_false(jj_config.get(key):is_set())
    end)
  end)
end
