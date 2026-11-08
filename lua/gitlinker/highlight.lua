local M = {}

-- Highlight group used to highlight the linked line range. It is created by
-- `gitlinker.setup()` and can be redefined by users before the plugin loads.
--- @type string
M.GROUP = "NvimGitLinkerHighlightTextObject"

-- Namespace that owns every extmark this module creates.
--- @type string
M.NAMESPACE = "NvimGitLinker"

-- Whether the highlight group `name` is defined.
--
-- A group that was defined at least once keeps an id even after its attributes
-- are cleared, so ask for its definition rather than its id: a scheme switch
-- empties the definition without removing the id.
--
-- `create = false` keeps the lookup read-only; the default creates the group as
-- a side effect, so a second call would find the group it just made up.
--- @param name string
--- @return boolean
M.exists = function(name)
  local hl = vim.api.nvim_get_hl(0, { name = name, create = false })
  return type(hl) == "table" and not vim.tbl_isempty(hl)
end

-- Highlights the region between the two positions with the highlight group.
--
-- `pos[1]` and `pos[2]` are the `start` and `finish` arguments of
-- `vim.hl.range()`, and both components of a `(line, column)` tuple are
-- 0-based. The API only says "a (line, column) tuple" and never states the
-- base, which differs from |getpos()|: that one is 1-based and returns a
-- four-element list, and `hl.lua` adds one to each component on the way there.
--
--   line   -- 0-based, so buffer line 1 is line 0
--   column -- 0-based byte offset, so column 0 is the first character
--
-- Callers build the tuples from a `gitlinker.Range` (1-based lines), so the
-- start is `{ lstart - 1, 0 }` to include the first character of the start
-- line, and the end takes its column from `col({ lnum, "$" })`. That is
-- 1-based and points one past the last character (`7` for `abcdef`), which
-- read as a 0-based end column is exactly what an end bound wants, so it
-- needs no adjustment. `hl.lua` also clamps the column to the line length, so
-- an overshoot would be harmless, but the intended value costs nothing.
--
--- @param pos {[1]:{integer,integer},[2]:{integer,integer}}
--- @param bufnr integer Buffer to highlight.
M.show = function(pos, bufnr)
  -- The buffer may be gone by the time a scheduled call runs.
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local namespace = vim.api.nvim_create_namespace(M.NAMESPACE)
  vim.hl.range(bufnr, namespace, M.GROUP, pos[1], pos[2], { inclusive = true })
  -- Force the screen to highlight the text immediately
  vim.cmd("redraw")
end

-- Clears the gitlinker highlights for the buffer.
--- @param bufnr integer Buffer to clear.
M.clear = function(bufnr)
  -- The timer that calls this may outlive the buffer it was started for.
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local namespace = vim.api.nvim_create_namespace(M.NAMESPACE)
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  -- Force the screen to clear the highlight immediately
  vim.cmd("redraw")
end

return M
