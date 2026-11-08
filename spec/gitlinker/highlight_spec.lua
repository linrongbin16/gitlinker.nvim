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
  --- @param bufnr integer Buffer to read.
  --- @return {[1]:integer,[2]:integer,[3]:integer,[4]:table}[]
  local function shown_marks(bufnr)
    assert_true(vim.wait(1000, function()
      return #vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {}) > 0
    end, 10))
    return vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
  end

  --- Build the `start_pos`/`finish_pos` pair the way `gitlinker.lua` does.
  --- @param lstart integer
  --- @param lend integer?
  --- @return {[1]:{integer,integer},[2]:{integer,integer}}
  local function make_pos(lstart, lend)
    local llast = lend or lstart
    return {
      { lstart - 1, 0 },
      { llast - 1, vim.fn.col({ llast, "$" }) },
    }
  end

  describe("[highlight]", function()
    local bufnr
    before_each(function()
      bufnr = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "abcdef", "ghijkl" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      highlight.clear(bufnr)
    end)
    it("show", function()
      highlight.show(make_pos(1, 1), bufnr)
      shown_marks(bufnr)
    end)
    it("show covers the first character of the start line", function()
      highlight.show(make_pos(1, 1), bufnr)
      local marks = shown_marks(bufnr)
      assert_eq(#marks, 1)
      -- Columns are 0-based: column 1 would drop the leading "a".
      assert_eq(marks[1][3], 0)
      assert_eq(marks[1][4].end_col, 6)
    end)
    it("show covers the whole line range", function()
      highlight.show(make_pos(1, 2), bufnr)
      local marks = shown_marks(bufnr)
      assert_eq(#marks, 1)
      assert_eq(marks[1][2], 0)
      assert_eq(marks[1][3], 0)
      -- The range is inclusive, so it ends on the last character of `lend`.
      assert_eq(marks[1][4].end_row, 1)
      assert_eq(marks[1][4].end_col, 6)
    end)
    it("make_pos sizes the end column from the end line, not the cursor line", function()
      -- Lines that differ in length, with the cursor parked on a line that is
      -- not the end of the range: a `col("$")` that reads the cursor line
      -- would clip the last line to the width of the first.
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "abcdef", "ghijklmnopqrst" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      highlight.clear(bufnr)
      highlight.show(make_pos(1, 2), bufnr)
      local marks = shown_marks(bufnr)
      assert_eq(#marks, 1)
      assert_eq(marks[1][4].end_row, 1)
      assert_eq(marks[1][4].end_col, 14)
    end)
    it("clear", function()
      highlight.show(make_pos(1, 1), bufnr)
      shown_marks(bufnr)
      highlight.clear(bufnr)
      assert_eq(#vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {}), 0)
    end)
  end)
end)
