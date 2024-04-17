local M = {}

---@param value string?
---@param rfc "rfc2396"|"rfc2732"|"rfc3986"|nil
---@return string?
M.encode = function(value, rfc)
  if type(value) ~= "string" then
    return nil
  end
  if vim.is_callable(vim.uri_encode) then
    return vim.uri_encode(value, rfc)
  else
    return require("gitlinker.commons._uri").uri_encode(value, rfc)
  end
end

---@param value string?
---@return string?
M.decode = function(value)
  if type(value) ~= "string" then
    return nil
  end
  if vim.is_callable(vim.uri_decode) then
    return vim.uri_decode(value)
  else
    return require("gitlinker.commons._uri").uri_decode(value)
  end
end

return M
