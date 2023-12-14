---@diagnostic disable: undefined-doc-param
local M = {}

--- @param t table?   lua table.
--- @return string?   returns json string.
M.encode = function(t)
  if t == nil then
    return nil
  end
  if vim.fn.has("nvim-0.9") and vim.json ~= nil then
    return vim.json.encode(t)
  else
    return require("gitlinker.commons._json").encode(t)
  end
end

--- @param j string?  json string.
--- @return table?    returns lua table.
M.decode = function(j)
  if j == nil then
    return nil
  end
  if vim.fn.has("nvim-0.9") and vim.json ~= nil then
    return vim.json.decode(j)
  else
    return require("gitlinker.commons._json").decode(j)
  end
end

return M
