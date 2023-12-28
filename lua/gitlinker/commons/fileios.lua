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
        "|commons.fileios - FileLineReader:open| failed to fs_open file: %s",
        vim.inspect(filename)
      )
    )
    return nil
  end
  local fstat = uv.fs_fstat(handler) --[[@as table]]
  if type(fstat) ~= "table" then
    error(
      string.format(
        "|commons.fileios - FileLineReader:open| failed to fs_fstat file: %s",
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
  local chunksize = (self.filesize >= self.offset + self.batchsize)
      and self.batchsize
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
        "|commons.fileios - FileLineReader:_read_chunk| failed to fs_read file: %s, read_error:%s, read_name:%s",
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
    local strings = require("gitlinker.commons.strings")
    if self.buffer == nil then
      return nil
    end
    local nextpos = strings.find(self.buffer, "\n")
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

--- @param filename string                    file name.
--- @param on_complete fun(data:string?):nil  callback on read complete.
---                                             1. `data`: the file content.
--- @param opts {trim:boolean?}?              options:
---                                             1. `trim`: whether to trim whitespaces around text content, by default `false`.
M.asyncreadfile = function(filename, on_complete, opts)
  local uv = require("gitlinker.commons.uv")
  opts = opts or { trim = false }
  opts.trim = type(opts.trim) == "boolean" and opts.trim or false

  uv.fs_open(filename, "r", 438, function(open_err, fd)
    if open_err then
      error(
        string.format(
          "failed to open(r) file %s: %s",
          vim.inspect(filename),
          vim.inspect(open_err)
        )
      )
      return
    end
    uv.fs_fstat(
      ---@diagnostic disable-next-line: param-type-mismatch
      fd,
      function(fstat_err, stat)
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
        ---@diagnostic disable-next-line: param-type-mismatch
        uv.fs_read(fd, stat.size, 0, function(read_err, data)
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
          ---@diagnostic disable-next-line: param-type-mismatch
          uv.fs_close(fd, function(close_err)
            on_complete(
              (opts.trim and type(data) == "string") and vim.trim(data) or data
            )
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
      end
    )
  end)
end

--- @param filename string
--- @return string[]|nil
M.readlines = function(filename)
  local reader = M.FileLineReader:open(filename) --[[@as commons.FileLineReader]]
  if not reader then
    return nil
  end
  local results = {}
  while reader:has_next() do
    table.insert(results, reader:next())
  end
  reader:close()
  return results
end

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
        string.format(
          "failed to open(w) file %s: %s",
          vim.inspect(filename),
          vim.inspect(open_err)
        )
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
