local NVIM_VERSION_0_8 = false

do
  if
    vim.is_callable(vim.version)
    and type(vim.version) == "table"
    and vim.is_callable(vim.version.gt)
    and vim.is_callable(vim.version.eq)
  then
    local _0_8 = { 0, 8, 0 }
    NVIM_VERSION_0_8 = vim.version.gt(vim.version(), _0_8)
      or vim.version.eq(vim.version(), _0_8)
  else
    NVIM_VERSION_0_8 = vim.fn.has("nvim-0.8") > 0
  end
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

return M
