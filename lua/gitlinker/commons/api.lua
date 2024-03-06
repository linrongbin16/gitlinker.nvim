local NVIM_VERSION_0_8 = false
local NVIM_VERSION_0_9 = false

do
  NVIM_VERSION_0_8 = require("gitlinker.commons.version").ge({ 0, 8 })
  NVIM_VERSION_0_9 = require("gitlinker.commons.version").ge({ 0, 9 })
end

local M = {}

-- buffer {

--- @param bufnr integer
--- @param name string
--- @return any
M.get_buf_option = function(bufnr, name)
  if NVIM_VERSION_0_8 then
    return vim.api.nvim_get_option_value(name, { buf = bufnr })
  else
    return vim.api.nvim_buf_get_option(bufnr, name)
  end
end

--- @param bufnr integer
--- @param name string
--- @param value any
M.set_buf_option = function(bufnr, name, value)
  if NVIM_VERSION_0_8 then
    return vim.api.nvim_set_option_value(name, value, { buf = bufnr })
  else
    return vim.api.nvim_buf_set_option(bufnr, name, value)
  end
end

-- buffer }

-- window {

--- @param winnr integer
--- @param name string
--- @return any
M.get_win_option = function(winnr, name)
  if NVIM_VERSION_0_8 then
    return vim.api.nvim_get_option_value(name, { win = winnr })
  else
    return vim.api.nvim_win_get_option(winnr, name)
  end
end

--- @param winnr integer
--- @param name string
--- @param value any
--- @return any
M.set_win_option = function(winnr, name, value)
  if NVIM_VERSION_0_8 then
    return vim.api.nvim_set_option_value(name, value, { win = winnr })
  else
    return vim.api.nvim_win_set_option(winnr, name, value)
  end
end

-- window }

-- highlight {

--- @param hl string
--- @return {fg:integer?,bg:integer?,[string]:any,ctermfg:integer?,ctermbg:integer?,cterm:{fg:integer?,bg:integer?,[string]:any}?}
M.get_hl = function(hl)
  if NVIM_VERSION_0_9 then
    return vim.api.nvim_get_hl(0, { name = hl, link = false })
  else
    ---@diagnostic disable-next-line: undefined-field
    local ok1, rgb_value = pcall(vim.api.nvim_get_hl_by_name, hl, true)
    if not ok1 then
      return vim.empty_dict()
    end
    ---@diagnostic disable-next-line: undefined-field
    local ok2, cterm_value = pcall(vim.api.nvim_get_hl_by_name, hl, false)
    if not ok2 then
      return vim.empty_dict()
    end
    local result = vim.tbl_deep_extend("force", rgb_value, {
      ctermfg = cterm_value.foreground,
      ctermbg = cterm_value.background,
      cterm = cterm_value,
    })
    result.fg = result.foreground
    result.bg = result.background
    result.sp = result.special
    result.cterm.fg = result.cterm.foreground
    result.cterm.bg = result.cterm.background
    result.cterm.sp = result.cterm.special
    return result
  end
end

--- @param ... string?
--- @return {fg:integer?,bg:integer?,[string]:any,ctermfg:integer?,ctermbg:integer?,cterm:{fg:integer?,bg:integer?,[string]:any}?}, integer, string?
M.get_hl_with_fallback = function(...)
  for i, hl in ipairs({ ... }) do
    if type(hl) == "string" then
      local hl_value = M.get_hl(hl)
      if type(hl_value) == "table" and not vim.tbl_isempty(hl_value) then
        return hl_value, i, hl
      end
    end
  end

  return vim.empty_dict(), -1, nil
end

-- highlight }

return M
