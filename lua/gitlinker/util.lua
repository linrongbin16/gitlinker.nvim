local path = require("plenary.path")
local log = require("gitlinker.log")

-- \\ to /
local function to_slash_path(p)
  if p == nil then
    return p
  end
  return string.gsub(p, "\\", "/")
end

-- / to \\
local function to_backslash_path(p)
  if p == nil then
    return p
  end
  return string.gsub(p, "/", "\\")
end

local function relative_path(cwd)
  local buf_path = path:new(vim.api.nvim_buf_get_name(0))
  if cwd ~= nil then
    cwd = to_backslash_path(cwd)
  end
  local relative_path = buf_path:make_relative(cwd)
  log.debug(
    "[buffer.get_relative_path] buf_path:%s, cwd:%s, relative_path:%s",
    vim.inspect(buf_path),
    vim.inspect(cwd),
    vim.inspect(relative_path)
  )
  return relative_path
end

local function selected_line_range()
  local pos1 = vim.fn.getpos("v")[2]
  local pos2 = vim.fn.getcurpos()[2]
  local lstart = math.min(pos1, pos2)
  local lend = math.max(pos1, pos2)
  return { lstart = lstart, lend = lend }
end

local M = {
  to_slash_path = to_slash_path,
  to_backslash_path = to_backslash_path,
  relative_path = relative_path,
  selected_line_range = selected_line_range,
}

return M
