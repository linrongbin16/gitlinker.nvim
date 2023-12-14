local M = {}

-- int32 max/min
M.INT32_MAX = 2147483647
M.INT32_MIN = -2147483648

--- @param a number
--- @param b number
--- @return boolean   returns `true` if equals, `false` if not.
M.eq = function(a, b)
  return type(a) == "number" and type(b) == "number" and a == b
end

--- @param a number
--- @param b number
--- @return boolean   returns `true` if not equals, `false` if equals.
M.ne = function(a, b)
  return not M.eq(a, b)
end

--- @param a number
--- @param b number
--- @return boolean   returns `true` if a is greater than b, `false` if not.
M.gt = function(a, b)
  return type(a) == "number" and type(b) == "number" and a > b
end

--- @param a number
--- @param b number
--- @return boolean   returns `true` if a is greater equals to b, `false` if not.
M.ge = function(a, b)
  return M.gt(a, b) or M.eq(a, b)
end

--- @param a number
--- @param b number
--- @return boolean   returns `true` if a is less than b, `false` if not.
M.lt = function(a, b)
  return type(a) == "number" and type(b) == "number" and a < b
end

--- @param a number
--- @param b number
--- @return boolean   returns `true` if a is less equals to b, `false` if not.
M.le = function(a, b)
  return M.lt(a, b) or M.eq(a, b)
end

--- @param value number
--- @param left number?   lower bound, by default INT32_MIN
--- @param right number?  upper bound, by default INT32_MAX
--- @return number
M.bound = function(value, left, right)
  return math.min(math.max(left or M.INT32_MIN, value), right or M.INT32_MAX)
end

local IncrementalId = 0

--- @return integer     returns auto-incremental integer, start from 1.
M.auto_incremental_id = function()
  if IncrementalId >= M.INT32_MAX then
    IncrementalId = 1
  else
    IncrementalId = IncrementalId + 1
  end
  return IncrementalId
end

return M
