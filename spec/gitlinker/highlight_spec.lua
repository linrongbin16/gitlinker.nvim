local cwd = vim.fn.getcwd()

describe("gitlinker.highlight", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false

  before_each(function()
    vim.api.nvim_command("cd " .. cwd)
  end)

  require("gitlinker").setup()
  local highlight = require("gitlinker.highlight")
  local ns = vim.api.nvim_create_namespace(highlight.NAMESPACE)

  --- Return the extmarks `highlight.show` created, waiting for its scheduled
  --- callback to run.
  --- @return {[1]:integer,[2]:integer,[3]:integer,[4]:table}[]
  local function shown_marks()
    assert_true(vim.wait(1000, function()
      return #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) > 0
    end, 10))
    return vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
  end

  describe("[highlight]", function()
    before_each(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "abcdef", "ghijkl" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      highlight.clear()
    end)
    it("show", function()
      highlight.show({ lstart = 1, lend = 1 })
      shown_marks()
    end)
    it("show covers the first character of the start line", function()
      highlight.show({ lstart = 1, lend = 1 })
      local marks = shown_marks()
      assert_eq(#marks, 1)
      -- Columns are 0-based: column 1 would drop the leading "a".
      assert_eq(marks[1][3], 0)
      assert_eq(marks[1][4].end_col, 6)
    end)
    it("show covers the whole line range", function()
      highlight.show({ lstart = 1, lend = 2 })
      local marks = shown_marks()
      assert_eq(#marks, 1)
      assert_eq(marks[1][2], 0)
      assert_eq(marks[1][3], 0)
      -- The range is inclusive, so it ends on the last character of `lend`.
      assert_eq(marks[1][4].end_row, 1)
      assert_eq(marks[1][4].end_col, 6)
    end)
    it("show sizes the end column from the end line, not the cursor line", function()
      -- `highlight_spec` lines that differ in length, with the cursor parked
      -- on a line that is not the end of the range: a `col("$")` that reads
      -- the cursor line would clip the last line to the width of the first.
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "abcdef", "ghijklmnopqrst" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      highlight.clear()
      highlight.show({ lstart = 1, lend = 2 })
      local marks = shown_marks()
      assert_eq(#marks, 1)
      assert_eq(marks[1][4].end_row, 1)
      assert_eq(marks[1][4].end_col, 14)
    end)
    it("clear", function()
      highlight.show({ lstart = 1, lend = 1 })
      shown_marks()
      highlight.clear()
      assert_eq(#vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}), 0)
    end)
  end)
end)
