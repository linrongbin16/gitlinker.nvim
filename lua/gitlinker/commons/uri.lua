local M = {}

---@param value string?
---@param rfc "rfc2396"|"rfc2732"|"rfc3986"|nil
---@return string?
M.encode = function(value, rfc)
  if type(value) ~= "string" then
    return nil
  end
  return require("gitlinker.commons._uri").uri_encode(value, rfc)
end

---@param value string?
---@return string?
M.decode = function(value)
  if type(value) ~= "string" then
    return nil
  end
  return require("gitlinker.commons._uri").uri_decode(value)
end

return M
