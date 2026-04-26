local log = require("neojj.lib.jj.log")

describe("jj log parser", function()
  describe("parse_json_objects", function()
    it("parses concatenated JSON objects", function()
      local objects = log.parse_json_objects('{"a":1}{"b":2}{"c":3}')
      assert.are.equal(3, #objects)
      assert.are.equal(1, objects[1].a)
      assert.are.equal(2, objects[2].b)
      assert.are.equal(3, objects[3].c)
    end)

    it("handles a single JSON object", function()
      local objects = log.parse_json_objects('{"key":"value"}')
      assert.are.equal(1, #objects)
      assert.are.equal("value", objects[1].key)
    end)

    it("handles strings with braces inside", function()
      local objects = log.parse_json_objects('{"msg":"hello {world}"}{"x":1}')
      assert.are.equal(2, #objects)
      assert.are.equal("hello {world}", objects[1].msg)
      assert.are.equal(1, objects[2].x)
    end)

    it("handles escaped quotes in strings", function()
      local objects = log.parse_json_objects('{"msg":"say \\"hi\\""}{"x":2}')
      assert.are.equal(2, #objects)
      assert.are.equal('say "hi"', objects[1].msg)
      assert.are.equal(2, objects[2].x)
    end)

    it("returns empty table for empty input", function()
      local objects = log.parse_json_objects("")
      assert.are.equal(0, #objects)
    end)

    it("returns empty table for whitespace-only input", function()
      local objects = log.parse_json_objects("   ")
      assert.are.equal(0, #objects)
    end)

    it("handles nested objects", function()
      local objects = log.parse_json_objects('{"a":{"b":{"c":1}}}{"d":2}')
      assert.are.equal(2, #objects)
      assert.are.equal(1, objects[1].a.b.c)
      assert.are.equal(2, objects[2].d)
    end)

    it("handles arrays inside objects", function()
      local objects = log.parse_json_objects('{"items":[1,2,3]}')
      assert.are.equal(1, #objects)
      assert.are.equal(3, #objects[1].items)
    end)

    it("ignores leading/trailing whitespace between objects", function()
      local objects = log.parse_json_objects('  {"a":1}  {"b":2}  ')
      assert.are.equal(2, #objects)
    end)
  end)

  describe("json_to_entry", function()
    local sample_obj = {
      change_id = "muvqvxnnyrwstlmspzqvvqzmqstxmzwq",
      commit_id = "7809cff3fa826599726c858a8c387ddc46fb7a72",
      description = "add feature\n",
      author = {
        name = "Test User",
        email = "test@example.com",
        timestamp = "2026-03-07T02:38:46-05:00",
      },
    }

    it("extracts change_id", function()
      local entry = log.json_to_entry(sample_obj)
      assert.are.equal("muvqvxnnyrwstlmspzqvvqzmqstxmzwq", entry.change_id)
    end)

    it("extracts commit_id", function()
      local entry = log.json_to_entry(sample_obj)
      assert.are.equal("7809cff3fa826599726c858a8c387ddc46fb7a72", entry.commit_id)
    end)

    it("strips trailing newlines from description", function()
      local entry = log.json_to_entry(sample_obj)
      assert.are.equal("add feature", entry.description)
    end)

    it("extracts author name", function()
      local entry = log.json_to_entry(sample_obj)
      assert.are.equal("Test User", entry.author_name)
    end)

    it("extracts author email", function()
      local entry = log.json_to_entry(sample_obj)
      assert.are.equal("test@example.com", entry.author_email)
    end)

    it("extracts author timestamp", function()
      local entry = log.json_to_entry(sample_obj)
      assert.are.equal("2026-03-07T02:38:46-05:00", entry.author_date)
    end)

    it("defaults to empty string for missing fields", function()
      local entry = log.json_to_entry({})
      assert.are.equal("", entry.change_id)
      assert.are.equal("", entry.commit_id)
      assert.are.equal("", entry.description)
      assert.are.equal("", entry.author_name)
      assert.are.equal("", entry.author_email)
      assert.are.equal("", entry.author_date)
    end)

    it("defaults to empty bookmarks table", function()
      local entry = log.json_to_entry(sample_obj)
      assert.are.same({}, entry.bookmarks)
    end)

    it("defaults boolean fields to false", function()
      local entry = log.json_to_entry(sample_obj)
      assert.is_false(entry.empty)
      assert.is_false(entry.conflict)
      assert.is_false(entry.immutable)
      assert.is_false(entry.current_working_copy)
    end)

    it("handles description without trailing newline", function()
      local entry = log.json_to_entry({
        change_id = "abc",
        commit_id = "def",
        description = "no trailing newline",
      })
      assert.are.equal("no trailing newline", entry.description)
    end)

    it("handles missing author gracefully", function()
      local entry = log.json_to_entry({
        change_id = "abc",
        commit_id = "def",
        description = "test",
      })
      assert.are.equal("", entry.author_name)
      assert.are.equal("", entry.author_email)
      assert.are.equal("", entry.author_date)
    end)

    it("takes only first line of multi-line descriptions", function()
      local entry = log.json_to_entry({
        change_id = "abc",
        commit_id = "def",
        description = "subject line\n\nmore details\nand more\n",
      })
      assert.are.equal("subject line", entry.description)
    end)
  end)

  describe("parse_enriched_lines", function()
    local function make_line(json_obj, flags)
      return vim.json.encode(json_obj) .. "\t" .. flags
    end

    local sample_json = {
      change_id = "muvqvxnnyrwstlmspzqvvqzmqstxmzwq",
      commit_id = "7809cff3fa826599726c858a8c387ddc46fb7a72",
      description = "add feature\n",
    }

    it("extracts shortest_prefix from the 7th tab field", function()
      local line = make_line(sample_json, "0\t0\t0\t0\t\t\tmuvq")
      local entries = log.parse_enriched_lines({ line })
      assert.are.equal(1, #entries)
      assert.are.equal("muvq", entries[1].shortest_prefix)
    end)

    it("handles single-character shortest_prefix", function()
      local line = make_line(sample_json, "0\t0\t0\t0\t\t\tm")
      local entries = log.parse_enriched_lines({ line })
      assert.are.equal("m", entries[1].shortest_prefix)
    end)

    it("sets shortest_prefix to nil when 7th field is empty", function()
      local line = make_line(sample_json, "0\t0\t0\t0\t\t")
      local entries = log.parse_enriched_lines({ line })
      assert.is_nil(entries[1].shortest_prefix)
    end)

    it("parses bookmarks and shortest_prefix together", function()
      local line = make_line(sample_json, "0\t0\t0\t0\tmain,dev\torigin@main\tmuvq")
      local entries = log.parse_enriched_lines({ line })
      assert.are.same({ "main", "dev" }, entries[1].bookmarks)
      assert.are.same({ "origin@main" }, entries[1].remote_bookmarks)
      assert.are.equal("muvq", entries[1].shortest_prefix)
    end)

    it("parses immutable, empty, and conflict flags", function()
      local line = make_line(sample_json, "1\t1\t1\t0\t\t\tmuvq")
      local entries = log.parse_enriched_lines({ line })
      assert.is_true(entries[1].immutable)
      assert.is_true(entries[1].empty)
      assert.is_true(entries[1].conflict)
    end)

    it("skips empty lines", function()
      local entries = log.parse_enriched_lines({ "", "" })
      assert.are.equal(0, #entries)
    end)

    it("parses divergent flag (4th flag field)", function()
      local line = make_line(sample_json, "0\t0\t0\t1\t\t\tmuvq")
      local entries = log.parse_enriched_lines({ line })
      assert.is_true(entries[1].divergent)
    end)

    it("defaults divergent to false when flag is 0", function()
      local line = make_line(sample_json, "0\t0\t0\t0\tmain\t\tmuvq")
      local entries = log.parse_enriched_lines({ line })
      assert.is_false(entries[1].divergent)
      assert.are.same({ "main" }, entries[1].bookmarks)
    end)
  end)

  describe("list_with_graph parsing helper", function()
    it("parses divergent flag from trailing tab-tag", function()
      local line = '○  {"change_id":"abc","commit_id":"123","description":"x","author":{"name":"","email":"","timestamp":""}}\tdivergent'
      local entry = log.parse_with_graph_line(line)
      assert.is_true(entry.divergent)
      assert.are.equal("abc", entry.change_id)
    end)

    it("defaults divergent to false when no tab-tag", function()
      local line = '○  {"change_id":"abc","commit_id":"123","description":"x","author":{"name":"","email":"","timestamp":""}}'
      local entry = log.parse_with_graph_line(line)
      assert.is_false(entry.divergent)
    end)

    it("returns graph-only entry for connector lines", function()
      local entry = log.parse_with_graph_line("│ ╮")
      assert.is_nil(entry.change_id)
      assert.are.equal("│ ╮", entry.graph)
    end)
  end)
end)
