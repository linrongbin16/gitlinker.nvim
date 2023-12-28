local M = {}

-- buffer {

--- @param bufnr integer
--- @param name string
--- @return any
M.get_buf_option = function(bufnr, name)
  if vim.fn.has("nvim-0.8") > 0 then
    return vim.api.nvim_get_option_value(name, { buf = bufnr })
  else
    return vim.api.nvim_buf_get_option(bufnr, name)
  end
end

--- @param bufnr integer
--- @param name string
--- @param value any
M.set_buf_option = function(bufnr, name, value)
  if vim.fn.has("nvim-0.8") > 0 then
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
  if vim.fn.has("nvim-0.8") > 0 then
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
  if vim.fn.has("nvim-0.8") > 0 then
    return vim.api.nvim_set_option_value(name, value, { win = winnr })
  else
    return vim.api.nvim_win_set_option(winnr, name, value)
  end
end

-- window }

return M
