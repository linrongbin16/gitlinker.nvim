local logger = require("gitlinker.logger")

--- @return boolean
local function is_macos()
  return vim.fn.has("mac") > 0
end

--- @return boolean
local function is_windows()
  return vim.fn.has("win32") > 0 or vim.fn.has("win64") > 0
end

--- @param cwd string|nil
--- @return string
local function relative_path(cwd)
  logger.debug(
    "|util.relative_path| cwd1(%s):%s",
    vim.inspect(type(cwd)),
    vim.inspect(cwd)
  )

  local buf_path = vim.api.nvim_buf_get_name(0)
  if cwd == nil or string.len(cwd) <= 0 then
    cwd = vim.fn.getcwd()
  end
  logger.debug(
    "|util.relative_path| buf_path(%s):%s, cwd(%s):%s",
    vim.inspect(type(buf_path)),
    vim.inspect(buf_path),
    vim.inspect(type(cwd)),
    vim.inspect(cwd)
  )

  local relpath = nil
  if buf_path:sub(1, #cwd) == cwd then
    relpath = buf_path:sub(#cwd + 1, -1)
    if relpath:sub(1, 1) == "/" or relpath:sub(1, 1) == "\\" then
      relpath = relpath:sub(2, -1)
    end
  end
  logger.debug(
    "|util.relative_path| relpath(%s):%s",
    vim.inspect(type(relpath)),
    vim.inspect(relpath)
  )
  return relpath
end

--- @type table<string, function>
local M = {
  is_macos = is_macos,
  is_windows = is_windows,
  relative_path = relative_path,
}

return M
