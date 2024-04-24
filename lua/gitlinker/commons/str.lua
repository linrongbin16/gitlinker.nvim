local M = {}

local string_len, string_byte, string_sub, string_gsub =
  string.len, string.byte, string.sub, string.gsub

--- @param s any
--- @return boolean
M.empty = function(s)
  return type(s) ~= "string" or string_len(s) == 0
end

--- @param s any
--- @return boolean
M.not_empty = function(s)
  return type(s) == "string" and string_len(s) > 0
end

--- @param s any
--- @return boolean
M.blank = function(s)
  return type(s) ~= "string" or string_len(vim.trim(s)) == 0
end

--- @param s any
--- @return boolean
M.not_blank = function(s)
  return type(s) == "string" and string_len(vim.trim(s)) > 0
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
      local a = string_byte(s, i + j - 1)
      local b = string_byte(t, j)
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
      local a = string_byte(s, i + j - 1)
      local b = string_byte(t, j)
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
--- @param t string?  by default is whitespace
--- @return string
M.ltrim = function(s, t)
  assert(type(s) == "string")
  assert(type(t) == "string" or t == nil)

  t = t or "%s+"
  ---@diagnostic disable-next-line: redundant-return-value
  return string_gsub(s, "^" .. t, "")
end

--- @param s string
--- @param t string?  by default is whitespace
--- @return string
M.rtrim = function(s, t)
  assert(type(s) == "string")
  assert(type(t) == "string" or t == nil)

  t = t or "%s+"
  ---@diagnostic disable-next-line: redundant-return-value
  return string_gsub(s, t .. "$", "")
end

--- @param s string
--- @param t string?  by default is whitespace
--- @return string
M.trim = function(s, t)
  assert(type(s) == "string")
  assert(type(t) == "string" or t == nil)
  return M.rtrim(M.ltrim(s, t), t)
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
    trimempty = false,
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
  opts.ignorecase = type(opts.ignorecase) == "boolean" and opts.ignorecase or false

  if opts.ignorecase then
    return string_len(s) >= string_len(t) and s:sub(1, #t):lower() == t:lower()
  else
    return string_len(s) >= string_len(t) and s:sub(1, #t) == t
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
  opts.ignorecase = type(opts.ignorecase) == "boolean" and opts.ignorecase or false

  if opts.ignorecase then
    return string_len(s) >= string_len(t) and s:sub(#s - #t + 1):lower() == t:lower()
  else
    return string_len(s) >= string_len(t) and s:sub(#s - #t + 1) == t
  end
end

--- @param s string
--- @param p string
--- @param r string
--- @return string, integer
M.replace = function(s, p, r)
  assert(type(s) == "string")
  assert(type(p) == "string")
  assert(type(r) == "string")

  local sn = string_len(s)
  local pn = string_len(p)
  local pos = 1
  local matched = 0
  local result = s

  while pos <= sn do
    pos = M.find(result, p, pos) --[[@as integer]]
    if type(pos) ~= "number" then
      break
    end
    result = string_sub(result, 1, pos - 1) .. r .. string_sub(result, pos + pn)
    pos = pos + pn
    matched = matched + 1
  end

  return result, matched
end

--- @param c string
--- @return boolean
M.isspace = function(c)
  assert(type(c) == "string")
  assert(string_len(c) == 1)
  return c:match("%s") ~= nil
end

--- @param c string
--- @return boolean
M.isalnum = function(c)
  assert(type(c) == "string")
  assert(string_len(c) == 1)
  return c:match("%w") ~= nil
end

--- @param c string
--- @return boolean
M.isdigit = function(c)
  assert(type(c) == "string")
  assert(string_len(c) == 1)
  return c:match("%d") ~= nil
end

--- @param c string
--- @return boolean
M.isxdigit = function(c)
  assert(type(c) == "string")
  assert(string_len(c) == 1)
  return c:match("%x") ~= nil
end

--- @param c string
--- @return boolean
M.isalpha = function(c)
  assert(type(c) == "string")
  assert(string_len(c) == 1)
  return c:match("%a") ~= nil
end

--- @param c string
--- @return boolean
M.islower = function(c)
  assert(type(c) == "string")
  assert(string_len(c) == 1)
  return c:match("%l") ~= nil
end

--- @param c string
--- @return boolean
M.isupper = function(c)
  assert(type(c) == "string")
  assert(string_len(c) == 1)
  return c:match("%u") ~= nil
end

--- @param s string
--- @param pos integer
--- @param ch string
--- @return string
M.setchar = function(s, pos, ch)
  assert(type(s) == "string")
  assert(type(pos) == "number")
  assert(type(ch) == "string")
  assert(string_len(ch) == 1)

  local n = string_len(s)
  pos = require("gitlinker.commons.tbl").list_index(pos, n)

  local buffer = ""
  if pos > 1 then
    buffer = string_sub(s, 1, pos - 1)
  end
  buffer = buffer .. ch
  if pos < n then
    buffer = buffer .. string_sub(s, pos + 1)
  end

  return buffer
end

--- @param s string
--- @return string[]
M.tochars = function(s)
  assert(type(s) == "string")
  local l = {}
  local n = string_len(s)
  for i = 1, n do
    table.insert(l, string_sub(s, i, i))
  end
  return l
end

return M
