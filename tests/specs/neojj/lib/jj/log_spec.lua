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
  end)
end)
