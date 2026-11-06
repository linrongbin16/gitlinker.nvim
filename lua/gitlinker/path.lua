--- Remove the trailing separators of a normalized directory path, but keep a
--- bare root (`/`) intact so that it stays absolute.
--- @param dir string
--- @return string
local function _strip_trailing_sep(dir)
  local result = dir
  -- Keep the last character: a bare `/` is already the root the caller meant.
  while string.len(result) > 1 and string.sub(result, -1) == "/" do
    result = string.sub(result, 1, string.len(result) - 1)
  end
  return result
end

--- Return `p` relative to `dir`, or nil when `p` is not inside `dir`.
---
--- The comparison is made on separator boundaries: `/repo-other/f.lua` is NOT
--- inside `/repo`, even though its first characters spell the directory name.
--- @param p string
--- @param dir string
--- @return string?
local function _relative_to(p, dir)
  local prefix = dir == "/" and dir or (dir .. "/")
  if string.len(p) < string.len(prefix) or string.sub(p, 1, string.len(prefix)) ~= prefix then
    return nil
  end
  local result = string.sub(p, string.len(prefix) + 1)
  if string.len(result) == 0 then
    -- `p` is the directory itself, which has no path relative to it.
    return nil
  end
  return result
end

--- Get the current buffer path relative to `dir`.
---
--- Pass the directory the consumer resolves paths against, not blindly the
--- editor cwd: `git` resolves both pathspecs and `rev:path` entries against the
--- directory it runs in, which for this plugin is the repository root.
---
--- This reads the buffer name and calls Vimscript functions, so it must run
--- outside a fast event context.
--- @param dir string?  the directory to be relative to, defaults to `vim.fn.getcwd()`.
--- @return string?  the relative path, or nil when the buffer is not inside `dir`.
local function buffer_relpath(dir)
  local path = require("gitlinker.commons.path")

  dir = dir or vim.fn.getcwd()
  dir = vim.fn.resolve(dir)
  dir = path.normalize(dir, { double_backslash = true, expand = true })
  dir = _strip_trailing_sep(dir)
  if string.len(dir) == 0 then
    -- No directory means no meaningful "relative to": matching the empty
    -- prefix would hand back every absolute path minus its leading separator.
    return nil
  end

  local bufpath = vim.api.nvim_buf_get_name(0)
  bufpath = vim.fn.resolve(bufpath)
  bufpath = path.normalize(bufpath, { double_backslash = true, expand = true })

  local result = _relative_to(bufpath, dir)
  return result
end

local M = {
  buffer_relpath = buffer_relpath,
}

return M
