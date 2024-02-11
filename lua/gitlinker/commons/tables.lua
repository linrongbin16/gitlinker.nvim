local M = {}

--- @param t any?
--- @return boolean
M.tbl_empty = function(t)
  return type(t) ~= "table" or vim.tbl_isempty(t)
end

--- @param t any?
--- @return boolean
M.tbl_not_empty = function(t)
  return type(t) == "table" and not vim.tbl_isempty(t)
end

--- @param t any?
--- @param ... any
--- @return any
M.tbl_get = function(t, ...)
  local e = t --[[@as table]]
  for _, k in ipairs({ ... }) do
    if type(e) == "table" and e[k] ~= nil then
      e = e[k]
    else
      return nil
    end
  end
  return e
end

--- @param t any[]
--- @param v any
--- @param compare (fun(a:any, b:any):boolean)|nil
--- @return boolean
M.tbl_contains = function(t, v, compare)
  assert(type(t) == "table")
  for k, item in pairs(t) do
    if type(compare) == "function" then
      if compare(item, v) then
        return true
      end
    else
      if item == v then
        return true
      end
    end
  end
  return false
end

--- @param l any?
--- @return boolean
M.list_empty = function(l)
  return type(l) ~= "table" or #l == 0
end

--- @param l any?
--- @return boolean
M.list_not_empty = function(l)
  return type(l) == "table" and #l > 0
end

--- @param i integer
--- @param n integer
--- @return integer
M.list_index = function(i, n)
  assert(n > 0)
  assert((i >= 1 and i <= n) or (i <= -1 and i >= -n))
  return i > 0 and i or (n + i + 1)
end

--- @param l any[]
--- @param v any
--- @param compare (fun(a:any, b:any):boolean)|nil
--- @return boolean
M.list_contains = function(l, v, compare)
  assert(type(l) == "table")
  for _, item in ipairs(l) do
    if type(compare) == "function" then
      if compare(item, v) then
        return true
      end
    else
      if item == v then
        return true
      end
    end
  end
  return false
end

return M
