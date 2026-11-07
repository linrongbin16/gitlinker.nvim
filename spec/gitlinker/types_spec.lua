local types = require("gitlinker.types")

describe("gitlinker.types", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  describe("[str_empty]", function()
    it("treats a missing or zero-length string as empty", function()
      assert_true(types.str_empty(nil))
      assert_true(types.str_empty(""))
    end)

    it("treats a string with content as not empty", function()
      assert_false(types.str_empty("a"))
      assert_false(types.str_empty(" "))
    end)

    it("treats a value that is not a string as empty", function()
      assert_true(types.str_empty(0))
      assert_true(types.str_empty(false))
      assert_true(types.str_empty({}))
      assert_true(types.str_empty(function() end))
    end)
  end)

  describe("[tbl_empty]", function()
    it("treats a missing or empty table as empty", function()
      assert_true(types.tbl_empty(nil))
      assert_true(types.tbl_empty({}))
    end)

    it("treats a table with content as not empty", function()
      assert_false(types.tbl_empty({ 1 }))
      assert_false(types.tbl_empty({ a = 1 }))
    end)

    it("treats a value that is not a table as empty", function()
      assert_true(types.tbl_empty(""))
      assert_true(types.tbl_empty("a"))
      assert_true(types.tbl_empty(0))
      assert_true(types.tbl_empty(false))
    end)
  end)

  describe("[str_blank]", function()
    it("accepts strings of whitespace", function()
      assert_true(types.str_blank(""))
      assert_true(types.str_blank("   "))
      assert_true(types.str_blank(" \t\n"))
    end)

    it("accepts values that are not strings", function()
      assert_true(types.str_blank(nil))
      assert_true(types.str_blank(5))
      assert_true(types.str_blank({}))
    end)

    it("rejects a string holding non-whitespace", function()
      assert_false(types.str_blank("a"))
      assert_false(types.str_blank("  a  "))
    end)
  end)

  describe("[str_search]", function()
    it("returns the index of a literal match", function()
      assert_eq(types.str_search("a{b}c", "{"), 2)
      assert_eq(types.str_search("a{b}c", "}"), 4)
    end)

    it("does not treat the needle as a Lua pattern", function()
      assert_eq(types.str_search("100% done", "%"), 4)
      assert_eq(types.str_search("a.b", "."), 2)
    end)

    it("starts from the given index", function()
      assert_eq(types.str_search("a{b}c", "{", 1), 2)
      assert_eq(types.str_search("a{b}c", "{", 3), nil)
    end)

    it("returns nil when the needle is absent", function()
      assert_eq(types.str_search("abc", "{"), nil)
      assert_eq(types.str_search("", "{"), nil)
    end)

    it("returns a single value", function()
      -- `string.find` also returns the index of the last matched character.
      -- Callers assign the result to one variable, so the second value would be
      -- dropped silently; the helper drops it explicitly instead.
      assert_eq(select("#", types.str_search("a{b}c", "{")), 1)
      assert_eq(select("#", types.str_search("abc", "{")), 1)
    end)
  end)

  describe("[str_strip_suffix]", function()
    it("removes the suffix when present", function()
      assert_eq(types.str_strip_suffix("gitlinker.nvim.git", ".git"), "gitlinker.nvim")
    end)

    it("leaves the string alone when the suffix is absent", function()
      assert_eq(types.str_strip_suffix("gitlinker.nvim", ".git"), "gitlinker.nvim")
    end)

    it("only removes the suffix once", function()
      assert_eq(types.str_strip_suffix("a.git.git", ".git"), "a.git")
    end)

    it("leaves the string alone for an empty suffix", function()
      assert_eq(types.str_strip_suffix("abc", ""), "abc")
    end)
  end)

  describe("[greater_equal]", function()
    it("compares numbers", function()
      assert_true(types.greater_equal(2, 1))
      assert_true(types.greater_equal(2, 2))
      assert_false(types.greater_equal(1, 2))
      assert_true(types.greater_equal(0, 0))
      assert_false(types.greater_equal(-1, 0))
    end)

    it("returns false instead of raising for a missing value", function()
      assert_false(types.greater_equal(nil, 0))
      assert_false(types.greater_equal(0, nil))
      assert_false(types.greater_equal(nil, nil))
    end)

    it("returns false instead of raising for a non-number", function()
      assert_false(types.greater_equal("2", 1))
      assert_false(types.greater_equal(1, "1"))
    end)
  end)
end)
