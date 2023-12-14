local M = {}

--- @param s any
--- @return boolean
M.empty = function(s)
  return type(s) ~= "string" or string.len(s) == 0
end

--- @param s any
--- @return boolean
M.not_empty = function(s)
  return type(s) == "string" and string.len(s) > 0
end

--- @param s any
--- @return boolean
M.blank = function(s)
  return type(s) ~= "string" or string.len(vim.trim(s)) == 0
end

--- @param s any
--- @return boolean
M.not_blank = function(s)
  return type(s) == "string" and string.len(vim.trim(s)) > 0
end

--- @param s string
--- @param t string
--- @param start integer?  by default start=1
--- @return integer?
M.find = function(s, t, start)
  assert(type(s) == "string")
  assert(type(t) == "string")

  start = start or 1
  for i = start, #s do
    local match = true
    for j = 1, #t do
      if i + j - 1 > #s then
        match = false
        break
      end
      local a = string.byte(s, i + j - 1)
      local b = string.byte(t, j)
      if a ~= b then
        match = false
        break
      end
    end
    if match then
      return i
    end
  end
  return nil
end

--- @param s string
--- @param t string
--- @param rstart integer?  by default rstart=#s
--- @return integer?
M.rfind = function(s, t, rstart)
  assert(type(s) == "string")
  assert(type(t) == "string")

  rstart = rstart or #s
  for i = rstart, 1, -1 do
    local match = true
    for j = 1, #t do
      if i + j - 1 > #s then
        match = false
        break
      end
      local a = string.byte(s, i + j - 1)
      local b = string.byte(t, j)
      if a ~= b then
        match = false
        break
      end
    end
    if match then
      return i
    end
  end
  return nil
end

--- @param s string
--- @param t string?  by default t is whitespace
--- @return string
M.ltrim = function(s, t)
  assert(type(s) == "string")
  assert(type(t) == "string" or t == nil)

  local function has(idx)
    if not t then
      return M.isspace(s:sub(idx, idx))
    end

    local c = string.byte(s, idx)
    local found = false
    for j = 1, #t do
      if string.byte(t, j) == c then
        found = true
        break
      end
    end
    return found
  end

  local i = 1
  while i <= #s do
    if not has(i) then
      break
    end
    i = i + 1
  end
  return s:sub(i, #s)
end

--- @param s string
--- @param t string?  by default t is whitespace
--- @return string
M.rtrim = function(s, t)
  assert(type(s) == "string")
  assert(type(t) == "string" or t == nil)

  local function has(idx)
    if not t then
      return M.isspace(s:sub(idx, idx))
    end

    local c = string.byte(s, idx)
    local found = false
    for j = 1, #t do
      if string.byte(t, j) == c then
        found = true
        break
      end
    end
    return found
  end

  local i = #s
  while i >= 1 do
    if not has(i) then
      break
    end
    i = i - 1
  end
  return s:sub(1, i)
end

--- @param s string
--- @param sep string
--- @param opts {plain:boolean?,trimempty:boolean?}?  by default opts={plain=true,trimempty=false}
--- @return string[]
M.split = function(s, sep, opts)
  assert(type(s) == "string")
  assert(type(sep) == "string")
  opts = opts or {
    plain = true,
    trimempty = true,
  }
  opts.plain = type(opts.plain) == "boolean" and opts.plain or true
  opts.trimempty = type(opts.trimempty) == "boolean" and opts.trimempty or false
  return vim.split(s, sep, opts)
end

--- @param s string
--- @param t string
--- @param opts {ignorecase:boolean?}?
--- @return boolean
M.startswith = function(s, t, opts)
  assert(type(s) == "string")
  assert(type(t) == "string")

  opts = opts or { ignorecase = false }
  opts.ignorecase = type(opts.ignorecase) == "boolean" and opts.ignorecase
    or false

  if opts.ignorecase then
    return string.len(s) >= string.len(t) and s:sub(1, #t):lower() == t:lower()
  else
    return string.len(s) >= string.len(t) and s:sub(1, #t) == t
  end
end

--- @param s string
--- @param t string
--- @param opts {ignorecase:boolean?}?
--- @return boolean
M.endswith = function(s, t, opts)
  assert(type(s) == "string")
  assert(type(t) == "string")

  opts = opts or { ignorecase = false }
  opts.ignorecase = type(opts.ignorecase) == "boolean" and opts.ignorecase
    or false

  if opts.ignorecase then
    return string.len(s) >= string.len(t)
      and s:sub(#s - #t + 1):lower() == t:lower()
  else
    return string.len(s) >= string.len(t) and s:sub(#s - #t + 1) == t
  end
end

--- @param c string
--- @return boolean
M.isspace = function(c)
  assert(type(c) == "string")
  assert(string.len(c) == 1)
  return c:match("%s") ~= nil
end

--- @param c string
--- @return boolean
M.isalnum = function(c)
  assert(type(c) == "string")
  assert(string.len(c) == 1)
  return c:match("%w") ~= nil
end

--- @param c string
--- @return boolean
M.isdigit = function(c)
  assert(type(c) == "string")
  assert(string.len(c) == 1)
  return c:match("%d") ~= nil
end

--- @param c string
--- @return boolean
M.isxdigit = function(c)
  assert(type(c) == "string")
  assert(string.len(c) == 1)
  return c:match("%x") ~= nil
end

--- @param c string
--- @return boolean
M.isalpha = function(c)
  assert(type(c) == "string")
  assert(string.len(c) == 1)
  return c:match("%a") ~= nil
end

--- @param c string
--- @return boolean
M.islower = function(c)
  assert(type(c) == "string")
  assert(string.len(c) == 1)
  return c:match("%l") ~= nil
end

--- @param c string
--- @return boolean
M.isupper = function(c)
  assert(type(c) == "string")
  assert(string.len(c) == 1)
  return c:match("%u") ~= nil
end

return M
