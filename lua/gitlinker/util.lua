local log = require("gitlinker.commons.log")
local uv = vim.uv or vim.loop

--- @param cwd string?
--- @return string?
local function buffer_relative_path(cwd)
  local path = require("gitlinker.commons.path")

  cwd = cwd or vim.fn.getcwd()
  cwd = vim.fn.resolve(cwd)
  cwd = path.normalize(cwd, { double_backslash = true, expand = true })

  local bufpath = vim.api.nvim_buf_get_name(0)
  bufpath = vim.fn.resolve(bufpath)
  bufpath = path.normalize(bufpath, { double_backslash = true, expand = true })

  local result = nil
  if string.len(bufpath) >= string.len(cwd) and bufpath:sub(1, #cwd) == cwd then
    result = bufpath:sub(#cwd + 1)
    if result:sub(1, 1) == "/" or result:sub(1, 1) == "\\" then
      result = result:sub(2)
    end
  end
  -- logger.debug("|path.buffer_relpath| result:%s", vim.inspect(result))
  return result
end

--- @return integer
local function now_milliseconds()
  local ts = uv.clock_gettime("monotonic") --[[@as {sec:integer,nsec:integer} ]]
  log.debug(string.format("now_ts:%s", vim.inspect(ts)))
  local t1 = ts.sec * 1000
  local t2 = ts.nsec / 1000000
  local ms = math.ceil(t1 + t2)
  log.debug(string.format("now_ms:%s", vim.inspect(ms)))
  return ms
end

--- @param start_at integer
--- @param timeout_ms integer?
--- @return boolean
local function is_timeout(start_at, timeout_ms)
  return type(timeout_ms) == "number" and now_milliseconds() - start_at >= timeout_ms
end

local M = {
  buffer_relative_path = buffer_relative_path,
  now_milliseconds = now_milliseconds,
  is_timeout = is_timeout,
}

return M
