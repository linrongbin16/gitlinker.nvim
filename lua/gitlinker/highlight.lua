local M = {}

-- Highlight group used to highlight the linked line range. It can be redefined
-- by users before the plugin loads.
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
-- `start` and `finish` are the arguments of the same name of
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
--- @param bufnr integer Buffer to highlight.
--- @param start {integer,integer} 0-based `(line, column)` to start at.
--- @param finish {integer,integer} 0-based `(line, column)` to end at.
--- @param timeout integer How long to keep the highlight, in milliseconds.
--- @return uv.uv_timer_t timer The timer that will clear the highlight.
--- @return fun() clear Clears this highlight alone, leaving any other one in the
--- buffer untouched.
M.show = function(bufnr, start, finish, timeout)
  -- The buffer may be gone by the time a scheduled call runs.
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local namespace = vim.api.nvim_create_namespace(M.NAMESPACE)
  -- Define the group when the highlight is about to be drawn, unless something
  -- else already did. `vim.hl.range()` accepts an undefined group and draws
  -- nothing for it without raising anything, so a missing group shows up as a
  -- highlight that silently never appears. Building it here rather than once in
  -- `setup()` covers two more ways to end up with no definition: a scheme
  -- switch, which empties the definition of every group it does not know about
  -- but keeps their ids, and a setup that turned the highlight off while a
  -- later call asks for it again through the `highlight_duration` option of
  -- `link()`. Nothing is built for a session that never links.
  if not M.exists(M.GROUP) then
    vim.api.nvim_set_hl(0, M.GROUP, { link = "Search" })
  end
  -- Let `vim.hl.range()` own the timer. Each call records the ids of the
  -- extmarks it created and clears only those, so a highlight that expires
  -- leaves a later one alone. Clearing the namespace instead would wipe both
  -- as soon as the earlier of the two timers fired, and would also restart the
  -- id counter: the next highlight would be handed an id that a pending timer
  -- still means to delete.
  local timer, clear = vim.hl.range(bufnr, namespace, M.GROUP, start, finish, {
    inclusive = true,
    timeout = timeout,
  })
  -- Force the screen to highlight the text immediately
  vim.cmd("redraw")
  return timer, clear
end

return M
