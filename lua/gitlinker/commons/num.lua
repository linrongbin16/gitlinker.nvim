local M = {}

--- @param a number?
--- @param b number?
--- @return boolean
M.ge = function(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return false
  end
  return a >= b
end

return M
