---@diagnostic disable
local M = {}

--- @param ... any
--- @return {[integer]: any, n: integer}
function M.pack_len(...)
  return { n = select('#', ...), ... }
end

--- like unpack() but use the length set by F.pack_len if present
--- @param t? { [integer]: any, n?: integer }
--- @param first? integer
--- @return any...
function M.unpack_len(t, first)
  if t then
    return unpack(t, first or 1, t.n or table.maxn(t))
  end
end

--- @return_cast obj function
function M.is_callable(obj)
  return vim.is_callable(obj)
end

--- Convert an error to a string without letting its metamethod interrupt cleanup.
--- @param err any
--- @return string
function M.stringify(err)
  local ok, message = pcall(tostring, err)
  return ok and message or '<unprintable error>'
end

--- Create a function that runs a function when it is garbage collected.
--- @generic F : function
--- @param f F
--- @param gc fun()
--- @return F
function M.gc_fun(f, gc)
  local proxy = newproxy(true)
  local proxy_mt = getmetatable(proxy)
  proxy_mt.__gc = gc

  -- The closure keeps `proxy` reachable for as long as the returned function
  -- lives, so `gc` runs only once the caller drops this function. Returning the
  -- proxy itself would not do: callable userdata is not accepted everywhere we
  -- hand this function over (e.g. `vim.schedule()` requires a real function).
  return function(...)
    local _ = proxy
    return f(...)
  end
end

return M
