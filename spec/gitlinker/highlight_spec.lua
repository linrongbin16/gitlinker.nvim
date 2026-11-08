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
    it("show and clear target the given buffer, not the current one", function()
      -- A caller builds the positions while its own buffer is current, then
      -- hands the pair over: by the time `show`/`clear` run the current buffer
      -- may be a different one.
      local origin = bufnr
      vim.api.nvim_buf_set_lines(origin, 0, -1, false, { "abcdef", "ghijkl" })
      local pos = make_pos(1, 2)

      local other = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(other, 0, -1, false, { "x", "y" })
      vim.api.nvim_set_current_buf(other)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      highlight.show(pos, origin)
      local marks = shown_marks(origin)
      assert_eq(#marks, 1)
      -- `ghijkl` is 6 bytes wide, so the end column must come from the origin
      -- buffer, not from the one currently displayed.
      assert_eq(marks[1][4].end_row, 1)
      assert_eq(marks[1][4].end_col, 6)
      assert_eq(#vim.api.nvim_buf_get_extmarks(other, ns, 0, -1, {}), 0)

      vim.api.nvim_set_current_buf(origin)
      highlight.clear(origin)
      assert_eq(#vim.api.nvim_buf_get_extmarks(origin, ns, 0, -1, {}), 0)

      vim.api.nvim_set_current_buf(origin)
      vim.api.nvim_buf_delete(other, { force = true })
    end)
    it("show and clear survive a buffer that was deleted first", function()
      local doomed = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(doomed, 0, -1, false, { "abcdef" })
      -- The positions are built while the buffer is still alive, so the
      -- functions only have to cope with it disappearing afterwards.
      local pos = make_pos(1, 1)
      local id = doomed
      vim.api.nvim_buf_delete(doomed, { force = true })
      assert_true(pcall(highlight.show, pos, id))
      assert_true(pcall(highlight.clear, id))
    end)
    it("link highlights the requested lines of the buffer it started in", function()
      -- End to end: `gitlinker.lua` builds the positions and hands them over.
      -- The buffer needs a path inside the repository, so open a real file.
      vim.cmd("edit! lua/gitlinker.lua")
      local origin = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_lines(origin, 0, -1, false, { "short", "a much longer second line" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      highlight.clear(origin)

      local confs = require("gitlinker.configs").get()
      local saved = confs.highlight_duration
      confs.highlight_duration = 5000
      local ok = pcall(require("gitlinker")._void_link, {
        action = function() end,
        router = function()
          return "https://example.com/x"
        end,
        lstart = 1,
        lend = 2,
      })
      confs.highlight_duration = saved
      assert_true(ok)

      local marks = shown_marks(origin)
      assert_eq(#marks, 1)
      assert_eq(marks[1][2], 0)
      assert_eq(marks[1][3], 0)
      -- The end column is the width of line 2, read while the cursor was still
      -- on line 1: measuring the cursor line would give 6 instead of 25.
      assert_eq(marks[1][4].end_row, 1)
      assert_eq(marks[1][4].end_col, 25)
      highlight.clear(origin)
    end)
  end)
end)
