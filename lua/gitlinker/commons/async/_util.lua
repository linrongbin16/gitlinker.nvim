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

--- Create a function that runs a function when it is garbage collected.
--- @generic F : function
--- @param f F
--- @param gc fun()
--- @return F
function M.gc_fun(f, gc)
  local proxy = newproxy(true)
  local proxy_mt = getmetatable(proxy)
  proxy_mt.__gc = gc
  proxy_mt.__call = function(_, ...)
    return f(...)
  end

  return proxy
end

return M
