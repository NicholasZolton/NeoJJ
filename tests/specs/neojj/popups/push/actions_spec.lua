local MODULE = "neojj.popups.push.actions"

---@param stubs table<string, any>
---@param fn fun(actions: table)
local function with_actions_module(stubs, fn)
  local saved = {}
  for name, mod in pairs(stubs) do
    saved[name] = package.loaded[name]
    package.loaded[name] = mod
  end

  local saved_subject = package.loaded[MODULE]
  package.loaded[MODULE] = nil

  local ok, err = pcall(function()
    local actions = require(MODULE)
    fn(actions)
  end)

  package.loaded[MODULE] = saved_subject
  for name, _ in pairs(stubs) do
    package.loaded[name] = saved[name]
  end

  assert.is_true(ok, err)
end

---@param kind string
---@return table
local function new_builder(kind)
  local builder = {
    kind = kind,
    called = false,
    remote_value = nil,
    args_values = nil,
    target = nil,
  }

  builder.remote = function(remote)
    builder.remote_value = remote
    return builder
  end

  builder.args = function(...)
    builder.args_values = { ... }
    return builder
  end

  builder.call = function()
    builder.called = true
    return { code = 0, stderr = {} }
  end

  return builder
end

local function has_message(messages, needle)
  for _, msg in ipairs(messages) do
    if msg:find(needle, 1, true) then
      return true
    end
  end
  return false
end

describe("push popup actions remote mode", function()
  it("does not prompt for remote when -r is disabled", function()
    local bookmark_builder = new_builder("bookmark")
    local finder_calls = {}
    local info_messages = {}
    local warn_messages = {}
    local remote_list_calls = 0
    local selections = { "main" }

    with_actions_module({
      ["neojj.lib.jj"] = {
        cli = {
          git_push = {
            bookmark = function(name)
              bookmark_builder.target = name
              return bookmark_builder
            end,
            change = function()
              error("unexpected git_push.change call")
            end,
            all = new_builder("all"),
          },
          git_remote_list = {
            call = function()
              remote_list_calls = remote_list_calls + 1
              return { code = 0, stdout = { "origin git@example/repo" } }
            end,
          },
        },
      },
      ["neojj.lib.notification"] = {
        info = function(msg)
          table.insert(info_messages, msg)
        end,
        warn = function(msg)
          table.insert(warn_messages, msg)
        end,
      },
      ["neojj.buffers.fuzzy_finder"] = {
        new = function(items)
          return {
            open_async = function(_, opts)
              table.insert(finder_calls, { items = items, prompt_prefix = opts.prompt_prefix })
              return table.remove(selections, 1)
            end,
          }
        end,
      },
      ["neojj.lib.picker_cache"] = {
        get_local_bookmark_names = function()
          return { "main", "dev" }
        end,
        get_all_revisions = function()
          return {}
        end,
        parse_selection = function(selection)
          return selection
        end,
        error_msg = function()
          return "err"
        end,
      },
    }, function(actions)
      local popup = {
        get_arguments = function()
          return { "--dry-run" }
        end,
        get_internal_arguments = function()
          return {}
        end,
      }
      actions.push_bookmark(popup)
    end)

    assert.are.equal(0, remote_list_calls)
    assert.are.equal("main", bookmark_builder.target)
    assert.is_nil(bookmark_builder.remote_value)
    assert.is_true(bookmark_builder.called)
    assert.are.same({ "--dry-run" }, bookmark_builder.args_values)
    assert.are.equal(1, #finder_calls)
    assert.are.equal("Push bookmark", finder_calls[1].prompt_prefix)
    assert.is_true(has_message(info_messages, "Pushed main"))
    assert.is_false(has_message(warn_messages, "Push failed"))
  end)

  it("prompts for remote and applies --remote when -r is enabled", function()
    local bookmark_builder = new_builder("bookmark")
    local finder_calls = {}
    local remote_list_calls = 0
    local selections = { "main", "origin" }

    with_actions_module({
      ["neojj.lib.jj"] = {
        cli = {
          git_push = {
            bookmark = function(name)
              bookmark_builder.target = name
              return bookmark_builder
            end,
            change = function()
              error("unexpected git_push.change call")
            end,
            all = new_builder("all"),
          },
          git_remote_list = {
            call = function()
              remote_list_calls = remote_list_calls + 1
              return { code = 0, stdout = { "upstream git@example/upstream", "origin git@example/origin" } }
            end,
          },
        },
      },
      ["neojj.lib.notification"] = {
        info = function() end,
        warn = function() end,
      },
      ["neojj.buffers.fuzzy_finder"] = {
        new = function(items)
          return {
            open_async = function(_, opts)
              table.insert(finder_calls, { items = items, prompt_prefix = opts.prompt_prefix })
              return table.remove(selections, 1)
            end,
          }
        end,
      },
      ["neojj.lib.picker_cache"] = {
        get_local_bookmark_names = function()
          return { "main" }
        end,
        get_all_revisions = function()
          return {}
        end,
        parse_selection = function(selection)
          return selection
        end,
        error_msg = function()
          return "err"
        end,
      },
    }, function(actions)
      local popup = {
        get_arguments = function()
          return {}
        end,
        get_internal_arguments = function()
          return { remote = true }
        end,
      }
      actions.push_bookmark(popup)
    end)

    assert.are.equal(1, remote_list_calls)
    assert.is_true(bookmark_builder.called)
    assert.are.equal("origin", bookmark_builder.remote_value)
    assert.are.equal(2, #finder_calls)
    assert.are.equal("Push bookmark", finder_calls[1].prompt_prefix)
    assert.are.equal("Push remote", finder_calls[2].prompt_prefix)
    local got_remotes = finder_calls[2].items
    table.sort(got_remotes)
    assert.are.same({ "origin", "upstream" }, got_remotes)
  end)

  it("aborts push when remote picker is canceled", function()
    local bookmark_builder = new_builder("bookmark")
    local warn_messages = {}
    local selections = { "main", nil }

    with_actions_module({
      ["neojj.lib.jj"] = {
        cli = {
          git_push = {
            bookmark = function(name)
              bookmark_builder.target = name
              return bookmark_builder
            end,
            change = function()
              error("unexpected git_push.change call")
            end,
            all = new_builder("all"),
          },
          git_remote_list = {
            call = function()
              return { code = 0, stdout = { "origin git@example/origin" } }
            end,
          },
        },
      },
      ["neojj.lib.notification"] = {
        info = function() end,
        warn = function(msg)
          table.insert(warn_messages, msg)
        end,
      },
      ["neojj.buffers.fuzzy_finder"] = {
        new = function(items)
          return {
            open_async = function(_)
              return table.remove(selections, 1)
            end,
          }
        end,
      },
      ["neojj.lib.picker_cache"] = {
        get_local_bookmark_names = function()
          return { "main" }
        end,
        get_all_revisions = function()
          return {}
        end,
        parse_selection = function(selection)
          return selection
        end,
        error_msg = function()
          return "err"
        end,
      },
    }, function(actions)
      local popup = {
        get_arguments = function()
          return {}
        end,
        get_internal_arguments = function()
          return { remote = true }
        end,
      }
      actions.push_bookmark(popup)
    end)

    assert.is_false(bookmark_builder.called)
    assert.is_true(has_message(warn_messages, "Push aborted: no remote selected"))
  end)

  it("aborts push when no remotes are configured", function()
    local bookmark_builder = new_builder("bookmark")
    local finder_calls = {}
    local warn_messages = {}
    local remote_list_calls = 0
    local selections = { "main" }

    with_actions_module({
      ["neojj.lib.jj"] = {
        cli = {
          git_push = {
            bookmark = function(name)
              bookmark_builder.target = name
              return bookmark_builder
            end,
            change = function()
              error("unexpected git_push.change call")
            end,
            all = new_builder("all"),
          },
          git_remote_list = {
            call = function()
              remote_list_calls = remote_list_calls + 1
              return { code = 0, stdout = {} }
            end,
          },
        },
      },
      ["neojj.lib.notification"] = {
        info = function() end,
        warn = function(msg)
          table.insert(warn_messages, msg)
        end,
      },
      ["neojj.buffers.fuzzy_finder"] = {
        new = function(items)
          return {
            open_async = function(_, opts)
              table.insert(finder_calls, { items = items, prompt_prefix = opts.prompt_prefix })
              return table.remove(selections, 1)
            end,
          }
        end,
      },
      ["neojj.lib.picker_cache"] = {
        get_local_bookmark_names = function()
          return { "main" }
        end,
        get_all_revisions = function()
          return {}
        end,
        parse_selection = function(selection)
          return selection
        end,
        error_msg = function()
          return "err"
        end,
      },
    }, function(actions)
      local popup = {
        get_arguments = function()
          return {}
        end,
        get_internal_arguments = function()
          return { remote = true }
        end,
      }
      actions.push_bookmark(popup)
    end)

    assert.are.equal(1, remote_list_calls)
    assert.is_false(bookmark_builder.called)
    assert.are.equal(1, #finder_calls)
    assert.are.equal("Push bookmark", finder_calls[1].prompt_prefix)
    assert.is_true(has_message(warn_messages, "No remotes configured"))
  end)

  it("applies selected remote for push_all", function()
    local all_builder = new_builder("all")
    local selections = { "origin" }

    with_actions_module({
      ["neojj.lib.jj"] = {
        cli = {
          git_push = {
            bookmark = function()
              error("unexpected git_push.bookmark call")
            end,
            change = function()
              error("unexpected git_push.change call")
            end,
            all = all_builder,
          },
          git_remote_list = {
            call = function()
              return { code = 0, stdout = { "origin git@example/origin", "upstream git@example/upstream" } }
            end,
          },
        },
      },
      ["neojj.lib.notification"] = {
        info = function() end,
        warn = function() end,
      },
      ["neojj.buffers.fuzzy_finder"] = {
        new = function()
          return {
            open_async = function(_)
              return table.remove(selections, 1)
            end,
          }
        end,
      },
      ["neojj.lib.picker_cache"] = {
        get_local_bookmark_names = function()
          return {}
        end,
        get_all_revisions = function()
          return {}
        end,
        parse_selection = function(selection)
          return selection
        end,
        error_msg = function()
          return "err"
        end,
      },
    }, function(actions)
      local popup = {
        get_arguments = function()
          return {}
        end,
        get_internal_arguments = function()
          return { remote = true }
        end,
      }
      actions.push_all(popup)
    end)

    assert.is_true(all_builder.called)
    assert.are.equal("origin", all_builder.remote_value)
  end)
end)
