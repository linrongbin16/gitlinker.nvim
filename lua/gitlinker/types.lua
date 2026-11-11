--- Value helpers shared across the plugin.
---
--- These used to live in `gitlinker.commons.{num,str,tbl}`, three modules taken
--- from a general-purpose library. Most of their surface was never called, so
--- only what the plugin calls is kept here.
---
--- The `str_`/`tbl_` prefixes name the type each helper guards. The predicates
--- (`str_empty`, `tbl_empty`, `str_blank`, `greater_equal`) take an optional
--- value, so a missing or wrongly typed argument comes back as `false`/`true`
--- instead of raising at the call site. `str_search` and `str_strip_suffix` are
--- not predicates: they take strings and their callers always have one.

local M = {}

--- Whether a value is a string with no characters, or is not a string at all.
---
--- Optional arguments are often `nil`, and `string.len(nil)` raises, so a
--- missing value counts as empty instead of being an error.
---
--- @param s any
--- @return boolean
function M.str_empty(s)
  return type(s) ~= "string" or string.len(s) == 0
end

--- Whether a value is a table with no key/value pairs, or is not a table at all.
---
--- `vim.tbl_isempty` raises for anything that is not a table, so the type check
--- stays: callers hand it optional values that may be `nil`.
---
--- @param t any
--- @return boolean
function M.tbl_empty(t)
  return type(t) ~= "table" or vim.tbl_isempty(t)
end

--- Whether a value is a string holding nothing but whitespace, or is not a
--- string at all.
---
--- @param s any
--- @return boolean
function M.str_blank(s)
  return type(s) ~= "string" or string.len(vim.trim(s)) == 0
end

--- Index of `needle` in `s`, or `nil` when it is absent.
---
--- The needle is always matched literally: `{` and `%` are not Lua patterns.
---
--- `string.find` also returns the index of the last matched character; callers
--- here only want the first one, so the second return value is dropped.
---
--- @param s string
--- @param needle string
--- @param start integer?  1-based index to start from, defaults to `1`
--- @return integer?
function M.str_search(s, needle, start)
  local first = string.find(s, needle, start or 1, true)
  return first
end

--- Remove `suffix` from the end of `s`, leaving `s` untouched when absent.
---
--- Both arguments are required: `vim.endswith` and `string.len` raise on
--- anything that is not a string. Callers always pass a repository name.
---
--- @param s string
--- @param suffix string
--- @return string
function M.str_strip_suffix(s, suffix)
  if string.len(suffix) > 0 and vim.endswith(s, suffix) then
    return string.sub(s, 1, string.len(s) - string.len(suffix))
  end
  return s
end

--- Whether both values are numbers and `a` is greater than or equal to `b`.
---
--- Comparing a missing value with `<`/`>=` raises an error, and line numbers and
--- commit counts are optional throughout the plugin, so the check is part of
--- the helper instead of every call site.
---
--- @param a number?
--- @param b number?
--- @return boolean
function M.greater_equal(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return false
  end
  return a >= b
end

return M
