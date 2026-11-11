local log = require("gitlinker.log")

--- Check whether `m` is a visual mode string.
---
--- `vim.fn.mode()` returns "v" for characterwise, "V" for linewise, and the
--- literal Ctrl-V control character `"\22"` for blockwise visual mode.
--- `string.upper` lets us match "v" and "V" with a single comparison.
---
--- @param m string|nil
--- @return boolean
local function _is_visual_mode(m)
  if type(m) ~= "string" then
    return false
  end
  return string.upper(m) == "V" or m == "\22"
end

--- @alias gitlinker.Range {lstart:integer,lend:integer,cstart:integer?,cend:integer?}

--- Build a line range covering the current selection (visual mode) or the
--- current cursor line (all other modes).
---
--- @return gitlinker.Range
local function make_range()
  local m = vim.fn.mode()
  log.debug(string.format("|make_range| mode:%s", vim.inspect(m)))

  local l1, l2
  if _is_visual_mode(m) then
    -- Leaving visual mode with `<ESC>` keeps the `'<` and `'>` marks valid,
    -- so their line numbers describe the previous selection.
    vim.cmd([[execute "normal! \<ESC>"]])
    l1 = vim.fn.getpos("'<")[2]
    l2 = vim.fn.getpos("'>")[2]
  else
    l1 = vim.fn.getcurpos()[2]
    l2 = l1
  end

  return {
    lstart = math.min(l1, l2),
    lend = math.max(l1, l2),
  }
end

--- Check whether `r` looks like a valid `gitlinker.Range`.
---
--- Line numbers are 1-based, so both `lstart` and `lend` must be positive.
---
--- @param r any?
--- @return boolean
local function is_range(r)
  return type(r) == "table"
    and type(r.lstart) == "number"
    and r.lstart > 0
    and type(r.lend) == "number"
    and r.lend > 0
end

local M = {
  _is_visual_mode = _is_visual_mode,
  is_range = is_range,
  make_range = make_range,
}

return M
