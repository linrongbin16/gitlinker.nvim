local M = {}

local string_len = string.len
local string_byte = string.byte
local string_gsub = string.gsub

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

return M
