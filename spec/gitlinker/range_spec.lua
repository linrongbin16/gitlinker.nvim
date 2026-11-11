local cwd = vim.fn.getcwd()

describe("gitlinker.range", function()
  local assert_eq = assert.is_equal
  local assert_true = assert.is_true
  local assert_false = assert.is_false
  local assert_same = assert.same

  local range = require("gitlinker.range")
  local gitlinker = require("gitlinker")

  before_each(function()
    vim.api.nvim_command("cd " .. cwd)
    vim.opt.swapfile = false
    -- A buffer of known length, so a cursor line or a selection has a stable
    -- line number to be read back as.
    vim.cmd("silent! enew!")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "line 1",
      "line 2",
      "line 3",
      "line 4",
      "line 5",
      "line 6",
      "line 7",
    })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end)

  after_each(function()
    vim.cmd("silent! enew!")
    vim.api.nvim_command("cd " .. cwd)
  end)

  -- `gitlinker.setup()` writes the module config, so it has to be applied once
  -- and its result checked: a failure here would leave every case below
  -- running against a half-built configuration.
  local ok, err = pcall(gitlinker.setup, {})
  assert_true(ok, err)

  describe("[_is_visual_mode]", function()
    it("accepts the three visual modes", function()
      assert_true(range._is_visual_mode("V"))
      assert_true(range._is_visual_mode("v"))
      assert_true(range._is_visual_mode("\22"))
    end)

    it("rejects every other mode and a missing one", function()
      assert_false(range._is_visual_mode("n"))
      assert_false(range._is_visual_mode("i"))
      assert_false(range._is_visual_mode("R"))
      assert_false(range._is_visual_mode(""))
      assert_false(range._is_visual_mode(nil))
    end)
  end)

  describe("[make_range]", function()
    it("covers the cursor line outside visual mode", function()
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      assert_same(range.make_range(), { lstart = 3, lend = 3 })
    end)

    it("covers a linewise selection", function()
      vim.cmd("normal! 2GVj")
      assert_same(range.make_range(), { lstart = 2, lend = 3 })
    end)

    it("covers a selection made upwards", function()
      -- The marks keep the order the selection was made in, so the range has
      -- to sort them rather than assume `'<` comes first.
      vim.cmd("normal! 5GVk")
      assert_same(range.make_range(), { lstart = 4, lend = 5 })
    end)

    it("covers a blockwise selection", function()
      vim.cmd("normal! 2G\22jj")
      assert_same(range.make_range(), { lstart = 2, lend = 4 })
    end)

    it("covers a characterwise selection", function()
      vim.cmd("normal! 3Gvj")
      assert_same(range.make_range(), { lstart = 3, lend = 4 })
    end)

    it("leaves visual mode behind", function()
      -- The selection is ended before the marks are read, so the caller is not
      -- left in visual mode holding a range it can no longer see.
      vim.cmd("normal! 2GVj")
      range.make_range()
      assert_eq(vim.fn.mode(), "n")
    end)
  end)

  describe("[is_range]", function()
    it("accepts a table with two positive line numbers", function()
      assert_true(range.is_range({ lstart = 1, lend = 1 }))
      assert_true(range.is_range({ lstart = 1, lend = 9 }))
      assert_true(range.is_range({ lstart = 9, lend = 1, cstart = 1, cend = 2 }))
    end)

    it("rejects a missing or non-table value", function()
      assert_false(range.is_range(nil))
      assert_false(range.is_range(1))
      assert_false(range.is_range("1,2"))
      assert_false(range.is_range({}))
    end)

    it("rejects an end that is not a positive number", function()
      assert_false(range.is_range({ lstart = 1 }))
      assert_false(range.is_range({ lend = 1 }))
      assert_false(range.is_range({ lstart = 0, lend = 1 }))
      assert_false(range.is_range({ lstart = 1, lend = 0 }))
      assert_false(range.is_range({ lstart = -1, lend = 1 }))
      assert_false(range.is_range({ lstart = "1", lend = 1 }))
      assert_false(range.is_range({ lstart = 1, lend = "1" }))
    end)
  end)
end)
