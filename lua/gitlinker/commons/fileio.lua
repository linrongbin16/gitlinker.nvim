local M = {}

-- FileLineReader {

--- @class commons.FileLineReader
--- @field filename string    file name.
--- @field handler integer    file handle.
--- @field filesize integer   file size in bytes.
--- @field offset integer     current read position.
--- @field batchsize integer  chunk size for each read operation running internally.
--- @field buffer string?     internal data buffer.
local FileLineReader = {}

--- @param filename string
--- @param batchsize integer?
--- @return commons.FileLineReader?
function FileLineReader:open(filename, batchsize)
  local uv = require("gitlinker.commons.uv")
  local handler = uv.fs_open(filename, "r", 438) --[[@as integer]]
  if type(handler) ~= "number" then
    error(
      string.format(
        "|commons.fileio - FileLineReader:open| failed to fs_open file: %s",
        vim.inspect(filename)
      )
    )
    return nil
  end
  local fstat = uv.fs_fstat(handler) --[[@as table]]
  if type(fstat) ~= "table" then
    error(
      string.format(
        "|commons.fileio - FileLineReader:open| failed to fs_fstat file: %s",
        vim.inspect(filename)
      )
    )
    uv.fs_close(handler)
    return nil
  end

  local o = {
    filename = filename,
    handler = handler,
    filesize = fstat.size,
    offset = 0,
    batchsize = batchsize or 4096,
    buffer = nil,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

--- @private
--- @return integer
function FileLineReader:_read_chunk()
  local uv = require("gitlinker.commons.uv")
  local chunksize = (self.filesize >= self.offset + self.batchsize) and self.batchsize
    or (self.filesize - self.offset)
  if chunksize <= 0 then
    return 0
  end
  local data, --[[@as string?]]
    read_err,
    read_name =
    uv.fs_read(self.handler, chunksize, self.offset)
  if read_err then
    error(
      string.format(
        "|commons.fileio - FileLineReader:_read_chunk| failed to fs_read file: %s, read_error:%s, read_name:%s",
        vim.inspect(self.filename),
        vim.inspect(read_err),
        vim.inspect(read_name)
      )
    )
    return -1
  end
  -- append to buffer
  self.buffer = self.buffer and (self.buffer .. data) or data --[[@as string]]
  self.offset = self.offset + #data
  return #data
end

--- @return boolean
function FileLineReader:has_next()
  self:_read_chunk()
  return self.buffer ~= nil and string.len(self.buffer) > 0
end

--- @return string?
function FileLineReader:next()
  --- @return string?
  local function impl()
    local str = require("gitlinker.commons.str")
    if self.buffer == nil then
      return nil
    end
    self.buffer = self.buffer:gsub("\r\n", "\n")
    local nextpos = str.find(self.buffer, "\n")
    if nextpos then
      local line = self.buffer:sub(1, nextpos - 1)
      self.buffer = self.buffer:sub(nextpos + 1)
      return line
    else
      return nil
    end
  end

  repeat
    local nextline = impl()
    if nextline then
      return nextline
    end
  until self:_read_chunk() <= 0

  local nextline = impl()
  if nextline then
    return nextline
  else
    local buf = self.buffer
    self.buffer = nil
    return buf
  end
end

-- Close the file reader.
function FileLineReader:close()
  local uv = require("gitlinker.commons.uv")
  if self.handler then
    uv.fs_close(self.handler)
    self.handler = nil
  end
end

M.FileLineReader = FileLineReader

-- FileLineReader }

-- CachedFileReader {

--- @class commons.CachedFileReader
--- @field filename string
--- @field cache string?
local CachedFileReader = {}

--- @param filename string
--- @return commons.CachedFileReader
function CachedFileReader:open(filename)
  local o = {
    filename = filename,
    cache = nil,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

--- @param opts {trim:boolean?}?
--- @return string?
function CachedFileReader:read(opts)
  opts = opts or {}
  opts.trim = type(opts.trim) == "boolean" and opts.trim or false

  if self.cache == nil then
    self.cache = M.readfile(self.filename)
  end
  if self.cache == nil then
    return self.cache
  end
  return opts.trim and vim.trim(self.cache) or self.cache
end

--- @return string?
function CachedFileReader:reset()
  local saved = self.cache
  self.cache = nil
  return saved
end

M.CachedFileReader = CachedFileReader

-- CachedFileReader }

--- @param filename string
--- @param opts {trim:boolean?}?
--- @return string?
M.readfile = function(filename, opts)
  opts = opts or { trim = false }
  opts.trim = type(opts.trim) == "boolean" and opts.trim or false

  local f = io.open(filename, "r")
  if f == nil then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return opts.trim and vim.trim(content) or content
end

--- @param filename string
--- @param on_complete fun(data:string?):any
--- @param opts {trim:boolean?}?
M.asyncreadfile = function(filename, on_complete, opts)
  local uv = require("gitlinker.commons.uv")
  opts = opts or { trim = false }
  opts.trim = type(opts.trim) == "boolean" and opts.trim or false

  local open_result, open_err = uv.fs_open(filename, "r", 438, function(open_complete_err, fd)
    if open_complete_err then
      error(
        string.format(
          "failed to complete open(r) file %s: %s",
          vim.inspect(filename),
          vim.inspect(open_complete_err)
        )
      )
      return
    end
    uv.fs_fstat(fd --[[@as integer]], function(fstat_err, stat)
      if fstat_err then
        error(
          string.format(
            "failed to fstat file %s: %s",
            vim.inspect(filename),
            vim.inspect(fstat_err)
          )
        )
        return
      end
      if not stat then
        error(
          string.format(
            "failed to fstat file %s (empty stat): %s",
            vim.inspect(filename),
            vim.inspect(fstat_err)
          )
        )
        return
      end
      uv.fs_read(fd --[[@as integer]], stat.size, 0, function(read_err, data)
        if read_err then
          error(
            string.format(
              "failed to read file %s: %s",
              vim.inspect(filename),
              vim.inspect(read_err)
            )
          )
          return
        end
        uv.fs_close(fd --[[@as integer]], function(close_err)
          on_complete((opts.trim and type(data) == "string") and vim.trim(data) or data)
          if close_err then
            error(
              string.format(
                "failed to close file %s: %s",
                vim.inspect(filename),
                vim.inspect(close_err)
              )
            )
          end
        end)
      end)
    end)
  end)
  assert(
    open_result ~= nil,
    string.format(
      "failed to open(read) file: %s, error: %s",
      vim.inspect(filename),
      vim.inspect(open_err)
    )
  )
end

--- @param filename string
--- @return string[]|nil
M.readlines = function(filename)
  local ok, reader = pcall(M.FileLineReader.open, M.FileLineReader, filename) --[[@as commons.FileLineReader]]
  if not ok or reader == nil then
    return nil
  end
  local results = {}
  while reader:has_next() do
    table.insert(results, reader:next())
  end
  reader:close()
  return results
end

--- @param filename string
--- @param opts {on_line:fun(line:string):any,on_complete:fun(bytes:integer):any,on_error:fun(err:string?):any,batchsize:integer?}
M.asyncreadlines = function(filename, opts)
  assert(type(opts) == "table")
  assert(type(opts.on_line) == "function")
  ---@diagnostic disable-next-line: undefined-field
  local batchsize = opts.batchsize or 4096

  local function _handle_error(err, msg)
    ---@diagnostic disable-next-line: undefined-field
    if type(opts.on_error) == "function" then
      ---@diagnostic disable-next-line: undefined-field
      opts.on_error(err)
    else
      error(
        string.format(
          "failed to async read file(%s): %s, error: %s",
          vim.inspect(msg),
          vim.inspect(filename),
          vim.inspect(err)
        )
      )
    end
  end

  local uv = require("gitlinker.commons.uv")
  local open_result, open_err = uv.fs_open(filename, "r", 438, function(open_complete_err, fd)
    if open_complete_err then
      _handle_error(open_complete_err, "fs_open complete")
      return
    end
    local fstat_result, fstat_err = uv.fs_fstat(
      fd --[[@as integer]],
      function(fstat_complete_err, stat)
        if fstat_complete_err then
          _handle_error(fstat_complete_err, "fs_fstat complete")
          return
        end
        if stat == nil then
          _handle_error("stat is nil", "fs_fstat complete")
          return
        end

        local fsize = stat.size
        local offset = 0
        local buffer = nil

        local function _process(buf, fn_line_processor)
          local str = require("gitlinker.commons.str")

          local i = 1
          while i <= #buf do
            local newline_pos = str.find(buf, "\n", i)
            if not newline_pos then
              break
            end
            local line = buf:sub(i, newline_pos - 1)
            fn_line_processor(line)
            i = newline_pos + 1
          end
          return i
        end

        local function _chunk_read()
          local read_result, read_err = uv.fs_read(
            fd --[[@as integer]],
            batchsize,
            offset,
            function(read_complete_err, data)
              if read_complete_err then
                _handle_error(read_complete_err, "fs_read complete")
                return
              end

              if data then
                offset = offset + #data

                buffer = buffer and (buffer .. data) or data --[[@as string]]
                buffer = buffer:gsub("\r\n", "\n")
                local pos = _process(buffer, opts.on_line)
                -- truncate the processed lines if still exists any
                buffer = pos <= #buffer and buffer:sub(pos, #buffer) or nil
              else
                -- no more data

                -- if buffer still has not been processed
                if buffer then
                  local pos = _process(buffer, opts.on_line)
                  buffer = pos <= #buffer and buffer:sub(pos, #buffer) or nil

                  -- process all the left buffer till the end of file
                  if buffer then
                    opts.on_line(buffer)
                  end
                end

                -- close file
                local close_result, close_err = uv.fs_close(
                  fd --[[@as integer]],
                  function(close_complete_err)
                    if close_complete_err then
                      _handle_error(close_complete_err, "fs_close complete")
                    end
                    ---@diagnostic disable-next-line: undefined-field
                    if type(opts.on_complete) == "function" then
                      ---@diagnostic disable-next-line: undefined-field
                      opts.on_complete(fsize)
                    end
                  end
                )
                if close_result == nil then
                  _handle_error(close_err, "fs_close")
                end
              end
            end
          )
          if read_result == nil then
            _handle_error(read_err, "fs_read")
          end
        end

        _chunk_read()
      end
    )

    if fstat_result == nil then
      _handle_error(fstat_err, "fs_fstat")
    end
  end)
  if open_result == nil then
    _handle_error(open_err, "fs_open")
  end
end

-- AsyncFileLineReader }

--- @param filename string  file name.
--- @param content string   file content.
--- @return integer         returns `0` if success, returns `-1` if failed.
M.writefile = function(filename, content)
  local f = io.open(filename, "w")
  if not f then
    return -1
  end
  f:write(content)
  f:close()
  return 0
end

--- @param filename string                      file name.
--- @param content string                       file content.
--- @param on_complete fun(bytes:integer?):any  callback on write complete.
---                                               1. `bytes`: written data bytes.
M.asyncwritefile = function(filename, content, on_complete)
  local uv = require("gitlinker.commons.uv")
  uv.fs_open(filename, "w", 438, function(open_err, fd)
    if open_err then
      error(
        string.format("failed to open(w) file %s: %s", vim.inspect(filename), vim.inspect(open_err))
      )
      return
    end
    ---@diagnostic disable-next-line: param-type-mismatch
    uv.fs_write(fd, content, nil, function(write_err, bytes)
      if write_err then
        error(
          string.format(
            "failed to write file %s: %s",
            vim.inspect(filename),
            vim.inspect(write_err)
          )
        )
        return
      end
      ---@diagnostic disable-next-line: param-type-mismatch
      uv.fs_close(fd, function(close_err)
        if close_err then
          error(
            string.format(
              "failed to close(w) file %s: %s",
              vim.inspect(filename),
              vim.inspect(close_err)
            )
          )
          return
        end
        if type(on_complete) == "function" then
          on_complete(bytes)
        end
      end)
    end)
  end)
end

--- @param filename string  file name.
--- @param lines string[]   content lines.
--- @return integer         returns `0` if success, returns `-1` if failed.
M.writelines = function(filename, lines)
  local f = io.open(filename, "w")
  if not f then
    return -1
  end
  assert(type(lines) == "table")
  for _, line in ipairs(lines) do
    assert(type(line) == "string")
    f:write(line .. "\n")
  end
  f:close()
  return 0
end

return M
