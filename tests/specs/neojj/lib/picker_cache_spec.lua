local picker_cache = require("neojj.lib.picker_cache")

describe("picker_cache", function()
  describe("parse_selection", function()
    it("extracts first token from a plain string", function()
      assert.are.equal("muvqvxnn", picker_cache.parse_selection("muvqvxnn add feature"))
    end)

    it("extracts first token from a table entry", function()
      local entry = { text = "muvqvxnn add feature", prefix_len = 4 }
      assert.are.equal("muvqvxnn", picker_cache.parse_selection(entry))
    end)

    it("returns nil for nil input", function()
      assert.is_nil(picker_cache.parse_selection(nil))
    end)

    it("handles table entry with bookmarks", function()
      local entry = { text = "muvqvxnn add feature [main]", prefix_len = 1 }
      assert.are.equal("muvqvxnn", picker_cache.parse_selection(entry))
    end)

    it("handles string with only change_id", function()
      assert.are.equal("muvqvxnn", picker_cache.parse_selection("muvqvxnn"))
    end)
  end)
end)
