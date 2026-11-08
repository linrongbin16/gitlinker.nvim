local M = {}

-- Highlight group used to highlight the linked line range. It is created by
-- `gitlinker.setup()` and can be redefined by users before the plugin loads.
--- @type string
M.GROUP = "NvimGitLinkerHighlightTextObject"

-- Namespace that owns every extmark this module creates.
--- @type string
M.NAMESPACE = "NvimGitLinker"

--- @param name string
M.hl_group_exists = function(name)
  if vim.fn.has("nvim-0.9") > 0 and type(vim.api.nvim_get_hl) == "function" then
    local hl = vim.api.nvim_get_hl(0, { name = name })
    -- logger.debug("|highlight.hl_group_exists| hl:%s", vim.inspect(hl))
    return type(hl) == "table" and not vim.tbl_isempty(hl)
  else
    local result = vim.fn.hlID(name)
    -- logger.debug(
    --     "|highlight.hl_group_exists| hl id:%s",
    --     vim.inspect(result)
    -- )
    return result > 0
  end
end

-- Highlights the text selected by the specified range.
--- @param range gitlinker.Range?
M.show = function(range)
  if not range then
    return
  end
  local namespace = vim.api.nvim_create_namespace(M.NAMESPACE)
  local lstart, lend = range.lstart, range.lend
  if lend and lend < lstart then
    lstart, lend = lend, lstart
  end
  -- `vim.hl.range()` documents `start` and `finish` only as "a (line, column)
  -- tuple" and never says which base they use. Both components are 0-based,
  -- unlike |getpos()|, which is 1-based and returns a four-element list:
  -- `hl.lua` adds one to each component before building that list.
  --
  --   line   -- 0-based, so buffer line `lstart` is `lstart - 1`
  --   column -- 0-based byte offset, so column 0 is the first character
  --
  -- `gitlinker.Range` numbers lines from 1, hence the `- 1` on both. The
  -- start column is 0 so the first character of the start line is included;
  -- anything higher would clip it.
  --
  -- The end column works the other way around. `col("$")` is 1-based and
  -- points one past the last character (`7` for `abcdef`), and read as a
  -- 0-based end column that is exactly what an end bound wants, so it takes
  -- no adjustment. `hl.lua` also clamps the column to the line length, so an
  -- overshoot would be harmless, but the intended value costs nothing.
  local start_pos = { lstart - 1, 0 }
  local finish_pos = { (lend or lstart) - 1, vim.fn.col("$") }
  vim.schedule(function()
    vim.hl.range(0, namespace, M.GROUP, start_pos, finish_pos, { inclusive = true })
    -- Force the screen to highlight the text immediately
    vim.cmd("redraw")
  end)
end

-- Clears the gitlinker highlights for the buffer.
M.clear = function()
  local namespace = vim.api.nvim_create_namespace(M.NAMESPACE)
  vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
  -- Force the screen to clear the highlight immediately
  vim.schedule(function()
    vim.cmd("redraw")
  end)
end

return M
