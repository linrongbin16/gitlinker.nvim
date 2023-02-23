local path = require("plenary.path")
local log = require("gitlinker.log")
local os = vim.loop.os_uname().sysname

local function is_macos()
  return os == "Darwin"
end

local function is_windows()
  if os:match("Windows") then
    return true
  else
    return false
  end
end

local function normalize_path(p)
  if p == nil then
    return p
  end
  if is_windows() and p:find("\\") then
    return p:gsub("\\", "/")
  end
  return p
end

local function relative_path(cwd)
  local buf_path = path:new(vim.api.nvim_buf_get_name(0))
  local normalize_buf_path = normalize_path(buf_path)
  local normalize_cwd = normalize_path(cwd)
  local start_pos, end_pos = normalize_buf_path:find(normalize_cwd)
  local relpath
  if start_pos == 1 then
    relpath = normalize_buf_path:sub(end_pos + 1)
  else
    relpath = normalize_buf_path
  end
  local normalized_relpath = normalize_path(relpath)
  -- log.debug(
  --   "[util.get_relative_path] buf_path:%s, cwd:%s, relpath:%s",
  --   vim.inspect(buf_path),
  --   vim.inspect(cwd),
  --   vim.inspect(relpath)
  -- )
  return normalized_relpath
end

local function selected_line_range()
  -- local lstart
  -- local lend
  -- local mode = vim.api.nvim_get_mode().mode
  -- if mode:lower() == "v" or mode:lower() == "x" then
  local pos1 = vim.fn.getpos("v")[2]
  local pos2 = vim.fn.getcurpos()[2]
  local lstart = math.min(pos1, pos2)
  local lend = math.max(pos1, pos2)
  --   log.debug(
  --     "[util.selected_line_range] mode:%s, pos1:%d, pos2:%d",
  --     mode,
  --     pos1,
  --     pos2
  --   )
  -- else
  --   lstart = vim.api.nvim_win_get_cursor(0)[1]
  --   log.debug("[util.selected_line_range] mode:%s, lstart:%d", mode, lstart)
  -- end
  --
  return { lstart = lstart, lend = lend }
end

local M = {
  is_macos = is_macos,
  is_windows = is_windows,
  normalize_path = normalize_path,
  relative_path = relative_path,
  selected_line_range = selected_line_range,
}

return M
