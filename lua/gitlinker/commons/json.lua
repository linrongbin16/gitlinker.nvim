local M = {}

--- @param t table?
--- @return string?
M.encode = function(t)
  if t == nil then
    return nil
  end
  if vim.json ~= nil and vim.is_callable(vim.json.encode) then
    return vim.json.encode(t)
  else
    return require("gitlinker.commons._json").encode(t)
  end
end

--- @param j string?
--- @return table?
M.decode = function(j)
  if j == nil then
    return nil
  end
  if vim.json ~= nil and vim.is_callable(vim.json.decode) then
    return vim.json.decode(j)
  else
    return require("gitlinker.commons._json").decode(j)
  end
end

return M
