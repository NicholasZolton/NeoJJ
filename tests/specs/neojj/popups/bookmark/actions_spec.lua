local MODULE = "neojj.popups.bookmark.actions"

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

local function base_stubs(overrides)
  overrides = overrides or {}
  local stubs = {
    ["neojj.lib.jj"] = {
      cli = {
        bookmark_track = {
          args = function(name)
            return {
              _name = name,
              remote = function()
                return {
                  call = function()
                    return { code = 0, stderr = {} }
                  end,
                }
              end,
            }
          end,
        },
        git_remote_list = {
          call = function()
            return { code = 0, stdout = { "origin git@example.com:org/repo.git" } }
          end,
        },
      },
    },
    ["neojj.lib.notification"] = {
      info = function() end,
      warn = function() end,
    },
    ["neojj.lib.input"] = {
      get_user_input = function()
        return nil
      end,
      get_permission = function()
        return false
      end,
    },
    ["neojj.lib.picker_cache"] = {
      get_local_bookmark_names = function()
        return { "main", "dev" }
      end,
      get_remote_bookmark_names = function()
        return { "main@origin" }
      end,
      get_all_revisions = function()
        return {}
      end,
      parse_selection = function(s)
        return s
      end,
      error_msg = function()
        return "err"
      end,
    },
    ["neojj.buffers.fuzzy_finder"] = overrides["neojj.buffers.fuzzy_finder"] or {
      new = function()
        return {
          open_async = function()
            return nil
          end,
        }
      end,
    },
  }
  for k, v in pairs(overrides) do
    stubs[k] = v
  end
  return stubs
end

describe("bookmark track action", function()
  it("shows cross-product of local bookmarks and remotes in picker", function()
    local finder_calls = {}
    local selections = { "main@origin" }

    local tracked_name = nil
    local tracked_remote = nil
    local track_builder_factory = function(name)
      tracked_name = name
      return {
        remote = function(r)
          tracked_remote = r
          return {
            call = function()
              return { code = 0, stderr = {} }
            end,
          }
        end,
      }
    end

    with_actions_module(
      base_stubs {
        ["neojj.lib.jj"] = {
          cli = {
            bookmark_track = { args = track_builder_factory },
            git_remote_list = {
              call = function()
                return { code = 0, stdout = { "origin git@example.com:org/repo.git" } }
              end,
            },
          },
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
      },
      function(actions)
        actions.track()
      end
    )

    assert.are.equal(1, #finder_calls)
    assert.are.equal("Track bookmark", finder_calls[1].prompt_prefix)
    local items = finder_calls[1].items
    table.sort(items)
    assert.are.same({ "dev@origin", "main@origin" }, items)
    assert.are.equal("main", tracked_name)
    assert.are.equal("origin", tracked_remote)
  end)

  it("builds cross-product for multiple remotes", function()
    local finder_calls = {}
    local selections = { "dev@upstream" }

    local tracked_name = nil
    local tracked_remote = nil

    with_actions_module(
      base_stubs {
        ["neojj.lib.jj"] = {
          cli = {
            bookmark_track = {
              args = function(name)
                tracked_name = name
                return {
                  remote = function(r)
                    tracked_remote = r
                    return {
                      call = function()
                        return { code = 0, stderr = {} }
                      end,
                    }
                  end,
                }
              end,
            },
            git_remote_list = {
              call = function()
                return {
                  code = 0,
                  stdout = {
                    "origin git@example.com:org/repo.git",
                    "upstream git@example.com:upstream/repo.git",
                  },
                }
              end,
            },
          },
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
      },
      function(actions)
        actions.track()
      end
    )

    local items = finder_calls[1].items
    table.sort(items)
    assert.are.same({ "dev@origin", "dev@upstream", "main@origin", "main@upstream" }, items)
    assert.are.equal("dev", tracked_name)
    assert.are.equal("upstream", tracked_remote)
  end)

  it("aborts when picker is canceled", function()
    local track_called = false

    with_actions_module(
      base_stubs {
        ["neojj.lib.jj"] = {
          cli = {
            bookmark_track = {
              args = function()
                return {
                  remote = function()
                    return {
                      call = function()
                        track_called = true
                        return { code = 0, stderr = {} }
                      end,
                    }
                  end,
                }
              end,
            },
            git_remote_list = {
              call = function()
                return { code = 0, stdout = { "origin git@example.com:org/repo.git" } }
              end,
            },
          },
        },
        ["neojj.buffers.fuzzy_finder"] = {
          new = function()
            return {
              open_async = function()
                return nil
              end,
            }
          end,
        },
      },
      function(actions)
        actions.track()
      end
    )

    assert.is_false(track_called)
  end)

  it("shows empty picker when no remotes are configured", function()
    local finder_calls = {}

    with_actions_module(
      base_stubs {
        ["neojj.lib.jj"] = {
          cli = {
            bookmark_track = {
              args = function()
                return {
                  remote = function()
                    return {
                      call = function()
                        return { code = 0, stderr = {} }
                      end,
                    }
                  end,
                }
              end,
            },
            git_remote_list = {
              call = function()
                return { code = 0, stdout = {} }
              end,
            },
          },
        },
        ["neojj.buffers.fuzzy_finder"] = {
          new = function(items)
            return {
              open_async = function(_, opts)
                table.insert(finder_calls, { items = items, prompt_prefix = opts.prompt_prefix })
                return nil
              end,
            }
          end,
        },
      },
      function(actions)
        actions.track()
      end
    )

    assert.are.equal(1, #finder_calls)
    assert.are.same({}, finder_calls[1].items)
  end)

  it("shows warning on track failure", function()
    local warn_messages = {}
    local selections = { "main@origin" }

    with_actions_module(
      base_stubs {
        ["neojj.lib.jj"] = {
          cli = {
            bookmark_track = {
              args = function()
                return {
                  remote = function()
                    return {
                      call = function()
                        return { code = 1, stderr = { "error" } }
                      end,
                    }
                  end,
                }
              end,
            },
            git_remote_list = {
              call = function()
                return { code = 0, stdout = { "origin git@example.com:org/repo.git" } }
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
          new = function()
            return {
              open_async = function()
                return table.remove(selections, 1)
              end,
            }
          end,
        },
      },
      function(actions)
        actions.track()
      end
    )

    assert.are.equal(1, #warn_messages)
    assert.is_truthy(warn_messages[1]:find("Failed to track bookmark", 1, true))
  end)
end)
