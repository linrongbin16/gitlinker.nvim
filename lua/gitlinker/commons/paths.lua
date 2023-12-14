local IS_WINDOWS = vim.fn.has("win32") > 0 or vim.fn.has("win64") > 0

local M = {}

M.SEPARATOR = IS_WINDOWS and "\\" or "/"

--- @param p string
--- @param opts {double_backslash:boolean?,expand:boolean?}?
--- @return string
M.normalize = function(p, opts)
  opts = opts or { double_backslash = false, expand = false }
  opts.double_backslash = type(opts.double_backslash) == "boolean"
      and opts.double_backslash
    or false
  opts.expand = type(opts.expand) == "boolean" and opts.expand or false

  -- '\\\\' => '\\'
  local function _double_backslash(s)
    if string.match(s, [[\\]]) then
      s = string.gsub(s, [[\\]], [[\]])
    end
    return s
  end

  -- '\\' => '/'
  local function _single_backslash(s)
    if string.match(s, [[\]]) then
      s = string.gsub(s, [[\]], [[/]])
    end
    return s
  end

  local result = p

  if opts.double_backslash then
    result = _double_backslash(result)
  end
  result = _single_backslash(result)

  if opts.expand then
    result = vim.fn.expand(vim.trim(result)) --[[@as string]]
    if opts.double_backslash then
      result = _double_backslash(result)
    end
    result = _single_backslash(result)
  else
    result = vim.trim(result)
  end

  return result
end

--- @param ... any
--- @return string
M.join = function(...)
  return table.concat({ ... }, M.SEPARATOR)
end

--- @param p string?
--- @return string
M.reduce2home = function(p)
  return vim.fn.fnamemodify(p or vim.fn.getcwd(), ":~") --[[@as string]]
end

--- @param p string?
--- @return string
M.reduce = function(p)
  return vim.fn.fnamemodify(p or vim.fn.getcwd(), ":~:.") --[[@as string]]
end

--- @param p string?
--- @return string
M.shorten = function(p)
  return vim.fn.pathshorten(M.reduce(p)) --[[@as string]]
end

--- @return string
M.pipename = function()
  if IS_WINDOWS then
    local function uuid()
      local secs, ms = vim.loop.gettimeofday()
      return table.concat({
        string.format("%x", vim.loop.os_getpid()),
        string.format("%x", secs),
        string.format("%x", ms),
        string.format(
          "%x",
          math.random(1, require("fzfx.lib.numbers").INT32_MAX)
        ),
      }, "-")
    end
    return string.format([[\\.\pipe\nvim-pipe-%s]], uuid())
  else
    return vim.fn.tempname() --[[@as string]]
  end
end

return M
