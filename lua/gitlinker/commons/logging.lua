local IS_WINDOWS = vim.fn.has("win32") > 0 or vim.fn.has("win64") > 0
local uv = vim.uv or vim.loop

local M = {}

-- see: `lua print(vim.inspect(vim.log.levels))`
--- @enum commons.LogLevels
local LogLevels = {
  TRACE = 0,
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
  OFF = 5,
}

--- @enum commons.LogLevelNames
local LogLevelNames = {
  [0] = "TRACE",
  [1] = "DEBUG",
  [2] = "INFO",
  [3] = "WARN",
  [4] = "ERROR",
  [5] = "OFF",
}

M.LogLevels = LogLevels
M.LogLevelNames = LogLevelNames

local LogHighlights = {
  [0] = "Comment",
  [1] = "Comment",
  [2] = "None",
  [3] = "WarningMsg",
  [4] = "ErrorMsg",
  [5] = "ErrorMsg",
}

-- Formatter {

--- @class commons.logging.Formatter
--- @field fmt string
--- @field datefmt string
--- @field msecsfmt string
local Formatter = {}

--- @param fmt string
--- @param opts {datefmt:string?,msecsfmt:string?}?
--- @return commons.logging.Formatter
function Formatter:new(fmt, opts)
  assert(type(fmt) == "string")

  opts = opts or { datefmt = "%Y-%m-%d %H:%M:%S", msecsfmt = "%06d" }
  opts.datefmt = type(opts.datefmt) == "string" and opts.datefmt or "%Y-%m-%d %H:%M:%S"
  opts.msecsfmt = type(opts.msecsfmt) == "string" and opts.msecsfmt or "%06d"

  local o = {
    fmt = fmt,
    datefmt = opts.datefmt,
    msecsfmt = opts.msecsfmt,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

local FORMATTING_TAGS = {
  LEVEL_NO = "%(levelno)s",
  LEVEL_NAME = "%(levelname)s",
  MESSAGE = "%(message)s",
  ASCTIME = "%(asctime)s",
  MSECS = "%(msecs)d",
  NAME = "%(name)s",
  PROCESS = "%(process)d",
  FILE_NAME = "%(filename)s",
  LINE_NO = "%(lineno)d",
  FUNC_NAME = "%(funcName)s",
}

--- @param meta table<string,any>
--- @return string
function Formatter:format(meta)
  local str = require("gitlinker.commons.str")

  local n = string.len(self.fmt)

  local function make_detect(tag)
    local function impl(idx)
      if idx - 1 >= 1 and string.sub(self.fmt, idx - 1, idx) == "%%" then
        return false
      end

      local endpos = idx + string.len(FORMATTING_TAGS[tag]) - 1
      if endpos > n then
        return false
      end

      return str.startswith(string.sub(self.fmt, idx, endpos), FORMATTING_TAGS[tag])
    end
    return impl
  end

  local tags = {
    "LEVEL_NO",
    "LEVEL_NAME",
    "MESSAGE",
    "ASCTIME",
    "MSECS",
    "NAME",
    "PROCESS",
    "FILE_NAME",
    "LINE_NO",
    "FUNC_NAME",
  }

  local builder = {}
  local i = 1
  local tmp = ""

  while i <= n do
    local hit = false
    for _, tag in ipairs(tags) do
      local is_tag = make_detect(tag)
      if is_tag(i) then
        if string.len(tmp) > 0 then
          table.insert(builder, tmp)
          tmp = ""
        end
        i = i + string.len(FORMATTING_TAGS[tag])
        hit = true
        if tag == "ASCTIME" then
          table.insert(builder, os.date(self.datefmt, meta.SECONDS))
        elseif tag == "MSECS" then
          table.insert(builder, string.format(self.msecsfmt, meta.MSECS))
        elseif meta[tag] ~= nil then
          table.insert(builder, tostring(meta[tag]))
        end
        break
      end
    end

    if not hit then
      tmp = tmp .. string.sub(self.fmt, i, i)
      i = i + 1
    end
  end

  return table.concat(builder, "")
end

M.Formatter = Formatter

-- Formatter }

-- Handler {

--- @class commons.logging.Handler
local Handler = {}

--- @param meta commons.logging._MetaInfo
function Handler:write(meta)
  assert(false)
end

-- ConsoleHandler {

--- @class commons.logging.ConsoleHandler : commons.logging.Handler
--- @field formatter commons.logging.Formatter
local ConsoleHandler = {}

--- @param formatter commons.logging.Formatter?
--- @return commons.logging.ConsoleHandler
function ConsoleHandler:new(formatter)
  if formatter == nil then
    formatter = Formatter:new("[%(name)s] %(message)s")
  end

  local o = {
    formatter = formatter,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

--- @param meta commons.logging._MetaInfo
function ConsoleHandler:write(meta)
  if meta.LEVEL_NO < LogLevels.INFO then
    return
  end

  local msg_lines = vim.split(meta.MESSAGE, "\n", { plain = true })
  for _, line in ipairs(msg_lines) do
    local chunks = {}
    local line_meta = vim.tbl_deep_extend("force", vim.deepcopy(meta), { MESSAGE = line })
    local record = self.formatter:format(line_meta)
    table.insert(chunks, {
      record,
      LogHighlights[line_meta.LEVEL_NO],
    })
    vim.schedule(function()
      vim.api.nvim_echo(chunks, false, {})
    end)
  end
end

M.ConsoleHandler = ConsoleHandler

-- ConsoleHandler }

-- FileHandler {

--- @class commons.logging.FileHandler : commons.logging.Handler
--- @field formatter commons.logging.Formatter
--- @field filepath string
--- @field filemode "a"|"w"
--- @field filehandle any
local FileHandler = {}

--- @param filepath string
--- @param filemode "a"|"w"|nil
--- @param formatter commons.logging.Formatter?
--- @return commons.logging.FileHandler
function FileHandler:new(filepath, filemode, formatter)
  assert(type(filepath) == "string")
  assert(filemode == "a" or filemode == "w" or filemode == nil)

  if formatter == nil then
    formatter =
      Formatter:new("%(asctime)s,%(msecs)d [%(filename)s:%(lineno)d] %(levelname)s: %(message)s")
  end

  filemode = filemode ~= nil and string.lower(filemode) or "a"
  local filehandle = nil

  if filemode == "w" then
    filehandle = io.open(filepath, "w")
    assert(filehandle ~= nil, string.format("failed to open file:%s", vim.inspect(filepath)))
  end

  local o = {
    formatter = formatter,
    filepath = filepath,
    filemode = filemode,
    filehandle = filehandle,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function FileHandler:close()
  if self.filemode == "w" or self.filehandle ~= nil then
    self.filehandle:close()
    self.filehandle = nil
  end
end

--- @param meta commons.logging._MetaInfo
function FileHandler:write(meta)
  local fp = nil

  if self.filemode == "w" then
    assert(
      self.filehandle ~= nil,
      string.format("failed to write file log:%s", vim.inspect(self.filepath))
    )
    fp = self.filehandle
  elseif self.filemode == "a" then
    fp = io.open(self.filepath, "a")
  end

  if fp then
    local record = self.formatter:format(meta)
    fp:write(string.format("%s\n", record))
  end

  if self.filemode == "a" and fp ~= nil then
    fp:close()
  end
end

M.FileHandler = FileHandler

-- FileHandler }

-- Handler }

-- Logger {

--- @class commons.logging.Logger
--- @field name string
--- @field level commons.LogLevels
--- @field handlers commons.logging.Handler[]
local Logger = {}

--- @param name string
--- @param level commons.LogLevels
--- @return commons.logging.Logger
function Logger:new(name, level)
  assert(type(name) == "string")
  assert(type(level) == "number" and LogLevelNames[level] ~= nil)

  local o = {
    name = name,
    level = level,
    handlers = {},
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

--- @param handler commons.logging.Handler
function Logger:add_handler(handler)
  assert(type(handler) == "table")
  table.insert(self.handlers, handler)
end

--- @param dbg debuginfo?
--- @param lvl integer
--- @param msg string
function Logger:_log(dbg, lvl, msg)
  assert(type(lvl) == "number" and LogLevelNames[lvl] ~= nil)

  if lvl < self.level then
    return
  end

  for _, handler in ipairs(self.handlers) do
    local secs, millis = uv.gettimeofday()
    --- @alias commons.logging._MetaInfo {LEVEL_NO:commons.LogLevels,LEVEL_NAME:commons.LogLevelNames,MESSAGE:string,SECONDS:integer,MILLISECONDS:integer,FILE_NAME:string,LINE_NO:integer,FUNC_NAME:string}
    local meta_info = {
      LEVEL_NO = lvl,
      LEVEL_NAME = LogLevelNames[lvl],
      MESSAGE = msg,
      SECONDS = secs,
      MSECS = millis,
      NAME = self.name,
      PROCESS = uv.os_getpid(),
      FILE_NAME = dbg ~= nil and (dbg.source or dbg.short_src) or nil,
      LINE_NO = dbg ~= nil and (dbg.currentline or dbg.linedefined) or nil,
      FUNC_NAME = dbg ~= nil and (dbg.func or dbg.what) or nil,
    }
    handler:write(meta_info)
  end
end

--- @param level integer|string
--- @param msg string
function Logger:log(level, msg)
  if type(level) == "string" then
    assert(LogLevels[string.upper(level)] ~= nil)
    level = LogLevels[string.upper(level)]
  end
  assert(type(level) == "number" and LogHighlights[level] ~= nil)
  local dbglvl = 2
  local dbg = nil
  while true do
    dbg = debug.getinfo(dbglvl, "nfSl")
    if not dbg or dbg.what ~= "C" then
      break
    end
    dbglvl = dbglvl + 1
  end
  self:_log(dbg, level, msg)
end

--- @param msg string
function Logger:debug(msg)
  local dbglvl = 2
  local dbg = nil
  while true do
    dbg = debug.getinfo(dbglvl, "nfSl")
    if not dbg or dbg.what ~= "C" then
      break
    end
    dbglvl = dbglvl + 1
  end
  self:_log(dbg, LogLevels.DEBUG, msg)
end

--- @param msg string
function Logger:info(msg)
  local dbglvl = 2
  local dbg = nil
  while true do
    dbg = debug.getinfo(dbglvl, "nfSl")
    if not dbg or dbg.what ~= "C" then
      break
    end
    dbglvl = dbglvl + 1
  end
  self:_log(dbg, LogLevels.INFO, msg)
end

--- @param msg string
function Logger:warn(msg)
  local dbglvl = 2
  local dbg = nil
  while true do
    dbg = debug.getinfo(dbglvl, "nfSl")
    if not dbg or dbg.what ~= "C" then
      break
    end
    dbglvl = dbglvl + 1
  end
  self:_log(dbg, LogLevels.WARN, msg)
end

--- @param msg string
function Logger:err(msg)
  local dbglvl = 2
  local dbg = nil
  while true do
    dbg = debug.getinfo(dbglvl, "nfSl")
    if not dbg or dbg.what ~= "C" then
      break
    end
    dbglvl = dbglvl + 1
  end
  self:_log(dbg, LogLevels.ERROR, msg)
end

--- @param msg string
function Logger:throw(msg)
  local dbglvl = 2
  local dbg = nil
  while true do
    dbg = debug.getinfo(dbglvl, "nfSl")
    if not dbg or dbg.what ~= "C" then
      break
    end
    dbglvl = dbglvl + 1
  end
  self:_log(dbg, LogLevels.ERROR, msg)
  error(msg)
end

--- @param cond any
--- @param msg string
function Logger:ensure(cond, msg)
  if not cond then
    local dbglvl = 2
    local dbg = nil
    while true do
      dbg = debug.getinfo(dbglvl, "nfSl")
      if not dbg or dbg.what ~= "C" then
        break
      end
      dbglvl = dbglvl + 1
    end
    self:_log(dbg, LogLevels.ERROR, msg)
  end
  assert(cond, msg)
end

M.Logger = Logger

-- Logger }

--- @type table<string, commons.logging.Logger>
local NAMESPACE = {}

--- @alias commons.LoggingConfigs {name:string,level:(commons.LogLevels|string)?,console_log:boolean?,file_log:boolean?,file_log_name:string?,file_log_dir:string?,file_log_mode:"a"|"w"|nil}
--- @type commons.LoggingConfigs
local Defaults = {
  --- @type string
  name = nil,
  level = LogLevels.INFO,
  console_log = true,
  file_log = false,
  file_log_name = nil,
  file_log_dir = vim.fn.stdpath("data") --[[@as string]],
  file_log_mode = "a",
}

--- @param opts commons.LoggingConfigs
M.setup = function(opts)
  local conf = vim.tbl_deep_extend("force", vim.deepcopy(Defaults), opts or {})
  if type(conf.level) == "string" then
    assert(LogLevels[string.upper(conf.level)] ~= nil)
    conf.level = LogLevels[string.upper(conf.level)]
  end
  assert(type(conf.level) == "number" and LogHighlights[conf.level] ~= nil)

  local console_handler = ConsoleHandler:new()
  local logger = Logger:new(conf.name, conf.level --[[@as commons.LogLevels]])
  logger:add_handler(console_handler)

  if conf.file_log then
    assert(type(conf.file_log_name) == "string")
    local SEPARATOR = IS_WINDOWS and "\\" or "/"
    local filepath = string.format(
      "%s%s",
      type(conf.file_log_dir) == "string" and (conf.file_log_dir .. SEPARATOR) or "",
      conf.file_log_name
    )
    local file_handler = FileHandler:new(filepath, conf.file_log_mode or "a")
    logger:add_handler(file_handler)
  end

  M.add(logger)
end

--- @param name string
--- @return boolean
M.has = function(name)
  assert(type(name) == "string")
  return NAMESPACE[name] ~= nil
end

--- @param name string
--- @return commons.logging.Logger
M.get = function(name)
  assert(type(name) == "string")
  return NAMESPACE[name]
end

--- @param logger commons.logging.Logger
M.add = function(logger)
  assert(type(logger) == "table")
  assert((type(logger.name) == "string" and string.len(logger.name) > 0) or logger.name ~= nil)
  assert(NAMESPACE[logger.name] == nil)
  NAMESPACE[logger.name] = logger
end

local ROOT = "root"

--- @param level integer|string
--- @param msg string
M.log = function(level, msg)
  if type(level) == "string" then
    assert(LogLevels[string.upper(level)] ~= nil)
    level = LogLevels[string.upper(level)]
  end
  assert(type(level) == "number" and LogHighlights[level] ~= nil)
  local dbglvl = 2
  local dbg = nil
  while true do
    dbg = debug.getinfo(dbglvl, "nfSl")
    if not dbg or dbg.what ~= "C" then
      break
    end
    dbglvl = dbglvl + 1
  end
  local logger = M.get(ROOT)
  assert(logger ~= nil)
  logger:_log(dbg, level, msg)
end

--- @param msg string
M.debug = function(msg)
  local dbglvl = 2
  local dbg = nil
  while true do
    dbg = debug.getinfo(dbglvl, "nfSl")
    if not dbg or dbg.what ~= "C" then
      break
    end
    dbglvl = dbglvl + 1
  end
  local logger = M.get(ROOT)
  assert(logger ~= nil)
  logger:_log(dbg, LogLevels.DEBUG, msg)
end

--- @param msg string
M.info = function(msg)
  local dbglvl = 2
  local dbg = nil
  while true do
    dbg = debug.getinfo(dbglvl, "nfSl")
    if not dbg or dbg.what ~= "C" then
      break
    end
    dbglvl = dbglvl + 1
  end
  local logger = M.get(ROOT)
  assert(logger ~= nil)
  logger:_log(dbg, LogLevels.INFO, msg)
end

--- @param msg string
M.warn = function(msg)
  local dbg = debug.getinfo(2, "nfSl")
  local logger = M.get(ROOT)
  assert(logger ~= nil)
  logger:_log(dbg, LogLevels.WARN, msg)
end

--- @param msg string
M.err = function(msg)
  local dbglvl = 2
  local dbg = nil
  while true do
    dbg = debug.getinfo(dbglvl, "nfSl")
    if not dbg or dbg.what ~= "C" then
      break
    end
    dbglvl = dbglvl + 1
  end
  local logger = M.get(ROOT)
  assert(logger ~= nil)
  logger:_log(dbg, LogLevels.ERROR, msg)
end

--- @param msg string
M.throw = function(msg)
  local dbglvl = 2
  local dbg = nil
  while true do
    dbg = debug.getinfo(dbglvl, "nfSl")
    if not dbg or dbg.what ~= "C" then
      break
    end
    dbglvl = dbglvl + 1
  end
  local logger = M.get(ROOT)
  assert(logger ~= nil)
  logger:_log(dbg, LogLevels.ERROR, msg)
  error(msg)
end

--- @param cond any
--- @param msg string
M.ensure = function(cond, msg)
  local dbglvl = 2
  local dbg = nil
  while true do
    dbg = debug.getinfo(dbglvl, "nfSl")
    if not dbg or dbg.what ~= "C" then
      break
    end
    dbglvl = dbglvl + 1
  end
  local logger = M.get(ROOT)
  assert(logger ~= nil)
  if not cond then
    logger:_log(dbg, LogLevels.ERROR, msg)
  end
  assert(cond, msg)
end

return M
