-- Numbers utilities

local M = {}

-- int32 max/min
M.INT32_MAX = 2147483647
M.INT32_MIN = -2147483648

M.eq = function(a, b)
  return type(a) == "number" and type(b) == "number" and a == b
end

M.ne = function(a, b)
  return not M.eq(a, b)
end

M.gt = function(a, b)
  return type(a) == "number" and type(b) == "number" and a > b
end

M.ge = function(a, b)
  return M.gt(a, b) or M.eq(a, b)
end

M.lt = function(a, b)
  return type(a) == "number" and type(b) == "number" and a < b
end

M.le = function(a, b)
  return M.lt(a, b) or M.eq(a, b)
end

--- @param value number
--- @param left number?   by default INT32_MIN
--- @param right number?  by default INT32_MAX
--- @return number
M.bound = function(value, left, right)
  return math.min(math.max(left or M.INT32_MIN, value), right or M.INT32_MAX)
end

local IncrementalId = 0

--- @return integer
M.auto_incremental_id = function()
  if IncrementalId >= M.INT32_MAX then
    IncrementalId = 1
  else
    IncrementalId = IncrementalId + 1
  end
  return IncrementalId
end

return M
