local uv = vim.uv or vim.loop
local IS_WINDOWS = vim.fn.has("win32") > 0 or vim.fn.has("win64") > 0
local PATH_SEPARATOR = IS_WINDOWS and "\\" or "/"

-- :lua print(vim.inspect(vim.log.levels))
local LogLevels = vim.log.levels

local LogLevelNames = {
  [0] = "TRACE",
  [1] = "DEBUG",
  [2] = "INFO",
  [3] = "WARN",
  [4] = "ERROR",
  [5] = "OFF",
}

local LogHighlights = {
  [0] = "Comment",
  [1] = "Comment",
  [2] = "None",
  [3] = "WarningMsg",
  [4] = "ErrorMsg",
  [5] = "ErrorMsg",
}

local LogConfigs = {
  name = nil,
  level = LogLevels.INFO,
  use_console = true,
  use_file = false,
  file_name = nil,
}

--- @param opts {name: string, level: integer?, use_console: boolean?, use_file: boolean?, file_name: string?}?
local function setup(opts)
  opts = opts or {}
  local level = opts.level or LogLevels.INFO
  local use_console
  if type(opts.use_console) == "boolean" then
    use_console = opts.use_console
  else
    use_console = true
  end
  local use_file = type(opts.use_file) == "boolean" and opts.use_file or false
  local name = opts.name
  local file_name = opts.file_name

  LogConfigs.name = name
  LogConfigs.level = level
  LogConfigs.use_console = use_console
  LogConfigs.use_file = use_file

  -- For Windows: $env:USERPROFILE\AppData\Local\nvim-data\${file_name}.log
  -- For *NIX: ~/.local/share/nvim/${file_name}.log
  LogConfigs.file_name = string.format("%s%s%s", vim.fn.stdpath("data"), PATH_SEPARATOR, file_name)
end

--- @param level integer
--- @param msg string
local function log(level, msg)
  if level < LogConfigs.level then
    return
  end

  local msg_lines = vim.split(msg, "\n", { plain = true })
  if LogConfigs.use_console and level >= LogLevels.INFO then
    local msg_chunks = {}
    for _, line in ipairs(msg_lines) do
      table.insert(msg_chunks, {
        string.format("[%s] %s\n", LogConfigs.name, line),
        LogHighlights[level],
      })
    end
    vim.api.nvim_echo(msg_chunks, false, {})
  end
  if LogConfigs.use_file then
    local fp = io.open(LogConfigs.file_name, "a")
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
  log(LogLevels.DEBUG, s)
end

--- @param s string
local function info(s)
  log(LogLevels.INFO, s)
end

--- @param s string
local function warn(s)
  log(LogLevels.WARN, s)
end

--- @param s string
local function err(s)
  log(LogLevels.ERROR, s)
end

--- @param s string
local function throw(s)
  log(LogLevels.ERROR, s)
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
  log = log,
  info = info,
  warn = warn,
  err = err,
  throw = throw,
  ensure = ensure,
}

return M
