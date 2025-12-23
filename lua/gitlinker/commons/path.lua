local IS_WINDOWS = vim.fn.has("win32") > 0 or vim.fn.has("win64") > 0
local uv = vim.uv or vim.loop

local M = {}

M.SEPARATOR = IS_WINDOWS and "\\" or "/"

--- @param p string
--- @return boolean
M.exists = function(p)
  assert(type(p) == "string")
  local result, _ = uv.fs_lstat(p)
  return result ~= nil
end

--- @param p string
--- @return boolean
M.isfile = function(p)
  assert(type(p) == "string")
  local result, _ = uv.fs_lstat(p)
  -- print(
  --   string.format(
  --     "|paths.isfile| p:%s, result:%s\n",
  --     vim.inspect(p),
  --     vim.inspect(result)
  --   )
  -- )
  return result ~= nil and result.type == "file"
end

--- @param p string
--- @return boolean
M.isdir = function(p)
  assert(type(p) == "string")
  local result, _ = uv.fs_lstat(p)
  -- print(
  --   string.format(
  --     "|paths.isdir| p:%s, result:%s\n",
  --     vim.inspect(p),
  --     vim.inspect(result)
  --   )
  -- )
  return result ~= nil and result.type == "directory"
end

--- @param p string
--- @return boolean
M.islink = function(p)
  assert(type(p) == "string")
  local result, _ = uv.fs_lstat(p)
  -- print(
  --   string.format(
  --     "|paths.issymlink| p:%s, result:%s\n",
  --     vim.inspect(p),
  --     vim.inspect(result)
  --   )
  -- )
  return result ~= nil and result.type == "link"
end

--- @param p string
--- @return string
M._normalize_slash = function(p, opts)
  assert(type(p) == "string")

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
  local result = vim.trim(p)

  result = _double_backslash(result)
  result = _single_backslash(result)
  return result
end

--- @param p string
--- @return string
M.expand = function(p)
  assert(type(p) == "string")
  if string.len(p) >= 1 and string.sub(p, 1, 1) == "~" then
    return uv.os_homedir() .. string.sub(p, 2)
  else
    return p
  end
end

--- @param p string
--- @return string
M.resolve = function(p)
  assert(type(p) == "string")
  if not M.islink(p) then
    return p
  end
  local result, _ = uv.fs_realpath(p)
  -- print(
  --   string.format(
  --     "|paths.resolve|-4 p:%s, result:%s\n",
  --     vim.inspect(p),
  --     vim.inspect(result)
  --   )
  -- )
  return result ~= nil and result or p
end

--- @param p string
--- @param opts {expand:boolean?,resolve:boolean?}?
--- @return string
M.normalize = function(p, opts)
  assert(type(p) == "string")
  opts = opts or { expand = false, resolve = false }
  opts.expand = type(opts.expand) == "boolean" and opts.expand or false
  opts.resolve = type(opts.resolve) == "boolean" and opts.resolve or false

  local result = M._normalize_slash(p, opts)
  -- print(
  --   string.format(
  --     "|paths.normalize| slash, p:%s, result:%s\n",
  --     vim.inspect(p),
  --     vim.inspect(result)
  --   )
  -- )
  if opts.expand then
    result = M.expand(result)
    -- print(
    --   string.format(
    --     "|paths.normalize| expand, p:%s, result:%s\n",
    --     vim.inspect(p),
    --     vim.inspect(result)
    --   )
    -- )
  end

  if opts.resolve then
    result = M.resolve(result)
    -- print(
    --   string.format(
    --     "|paths.normalize| resolve, p:%s, result:%s\n",
    --     vim.inspect(p),
    --     vim.inspect(result)
    --   )
    -- )
  end

  return M._normalize_slash(result, opts)
end

return M
