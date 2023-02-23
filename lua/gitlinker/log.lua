local M = {}

local echohl = {
  ["ERROR"] = "ErrorMsg",
  ["WARN"] = "ErrorMsg",
  ["INFO"] = "None",
  ["DEBUG"] = "Comment",
}
local log_level = "ERROR"
local use_console = nil
local use_file = nil
local filename = nil

function M.setup(opts)
  if opts.debug then
    log_level = "DEBUG"
  end
  use_console = opts.console_log
  use_file = opts.file_log
  filename = string.format("%s/%s", vim.fn.stdpath("data"), opts.file_log_name)
end

local function log(level, msg)
  if vim.log.levels[level] < vim.log.levels[log_level] then
    return
  end

  local function log_format(s)
    return string.format("[gitlinker] %s: %s", level, s)
  end

  local split_msg = vim.split(msg, "\n")
  if use_console then
    vim.cmd("echohl " .. echohl[level])
    for _, m in ipairs(split_msg) do
      -- vim.cmd(
      --   string.format(
      --     'echom "%s"',
      --     vim.fn.escape(vim.fn.escape(log_format(m), '"'), "\\")
      --   )
      -- )
      print(log_format(m))
    end
    vim.cmd("echohl None")
  end
  if use_file then
    local fp = io.open(filename, "a")
    for _, m in ipairs(split_msg) do
      fp:write(log_format(m) .. "\n")
    end
    fp:close()
  end
end

function M.debug(fmt, ...)
  log("DEBUG", string.format(fmt, ...))
end

function M.info(fmt, ...)
  log("INFO", string.format(fmt, ...))
end

function M.warn(fmt, ...)
  log("WARN", string.format(fmt, ...))
end

function M.error(fmt, ...)
  log("ERROR", string.format(fmt, ...))
end

return M
