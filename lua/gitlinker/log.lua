local uv = vim.uv or vim.loop

-- For Windows: $env:USERPROFILE\AppData\Local\nvim-data\gitlinker.log
-- For *NIX: ~/.local/share/nvim/gitlinker.log
local LOG_NAME = "gitlinker"
local LOG_FILE = vim.fs.joinpath(vim.fn.stdpath("data"), "gitlinker.log")

local LogLevelNames = {
  [vim.log.levels.TRACE] = "TRACE",
  [vim.log.levels.DEBUG] = "DEBUG",
  [vim.log.levels.INFO] = "INFO",
  [vim.log.levels.WARN] = "WARN",
  [vim.log.levels.ERROR] = "ERROR",
  [vim.log.levels.OFF] = "OFF",
}

local LogConfigs = {
  level = vim.log.levels.INFO,
  use_console = true,
  use_file = false,
}

--- @param opts {level: integer?, use_console: boolean?, use_file: boolean?}?
local function setup(opts)
  opts = opts or {}
  local level = opts.level or vim.log.levels.INFO

  local use_console
  if type(opts.use_console) == "boolean" then
    use_console = opts.use_console
  else
    use_console = true
  end

  local use_file = type(opts.use_file) == "boolean" and opts.use_file or false

  LogConfigs.level = level
  LogConfigs.use_console = use_console
  LogConfigs.use_file = use_file
end

--- @param level integer
--- @param msg string
local function log(level, msg)
  if level < LogConfigs.level then
    return
  end

  local msg_lines = vim.split(msg, "\n", { plain = true })
  if LogConfigs.use_console and level >= vim.log.levels.INFO then
    for _, line in ipairs(msg_lines) do
      if type(line) == "string" and string.len(line) > 0 then
        local fmt_line = string.format("[%s] %s", LOG_NAME, line)
        vim.schedule(function()
          vim.notify(fmt_line, level)
        end)
      end
    end
  end
  if LogConfigs.use_file then
    local fp = io.open(LOG_FILE, "a")
    if fp then
      for _, line in ipairs(msg_lines) do
        local secs, ms = uv.gettimeofday()
        fp:write(
          string.format(
            "%s.%03d [%s]: %s\n",
            os.date("%Y-%m-%d %H:%M:%S", secs),
            math.floor(ms / 1000),
            LogLevelNames[level],
            line
          )
        )
      end
      fp:close()
    end
  end
end

--- @param s string
local function debug(s)
  log(vim.log.levels.DEBUG, s)
end

--- @param s string
local function info(s)
  log(vim.log.levels.INFO, s)
end

--- @param s string
local function warn(s)
  log(vim.log.levels.WARN, s)
end

--- @param s string
local function err(s)
  log(vim.log.levels.ERROR, s)
end

--- @param s string
local function throw(s)
  log(vim.log.levels.ERROR, s)
  error(s)
end

--- @param cond boolean
--- @param s string
local function ensure(cond, s)
  if not cond then
    throw(s)
  end
end

local M = {
  setup = setup,
  debug = debug,
  info = info,
  warn = warn,
  err = err,
  ensure = ensure,
}

return M
