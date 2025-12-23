local uv = vim.uv or vim.loop

local M = {}

--- @param filename string
--- @return string?
M.readfile = function(filename)
  local f = io.open(filename, "r")
  if f == nil then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

--- @alias commons.AsyncReadFileOnComplete fun(data:string?):any
--- @alias commons.AsyncReadFileOnError fun(step:string?,err:string?):any
--- @param filename string
--- @param opts {on_complete:commons.AsyncReadFileOnComplete,on_error:commons.AsyncReadFileOnError?}
M.asyncreadfile = function(filename, opts)
  assert(type(opts) == "table")
  assert(type(opts.on_complete) == "function")

  if type(opts.on_error) ~= "function" then
    opts.on_error = function(step, err)
      error(
        string.format(
          "failed to read file(%s), filename:%s, error:%s",
          vim.inspect(step),
          vim.inspect(filename),
          vim.inspect(err)
        )
      )
    end
  end

  uv.fs_open(filename, "r", 438, function(on_open_err, fd)
    if on_open_err then
      opts.on_error("fs_open", on_open_err)
      return
    end
    uv.fs_fstat(fd --[[@as integer]], function(on_fstat_err, stat)
      if on_fstat_err then
        opts.on_error("fs_fstat", on_fstat_err)
        return
      end
      if not stat then
        opts.on_error("fs_fstat", "fs_fstat returns nil")
        return
      end
      uv.fs_read(fd --[[@as integer]], stat.size, 0, function(on_read_err, data)
        if on_read_err then
          opts.on_error("fs_read", on_read_err)
          return
        end
        uv.fs_close(fd --[[@as integer]], function(on_close_err)
          opts.on_complete(data)
          if on_close_err then
            opts.on_error("fs_close", on_close_err)
          end
        end)
      end)
    end)
  end)
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

--- @alias commons.AsyncWriteFileOnComplete fun(bytes:integer?):any
--- @alias commons.AsyncWriteFileOnError fun(step:string?,err:string?):any
--- @param filename string                      file name.
--- @param content string                       file content.
--- @param opts {on_complete:commons.AsyncWriteFileOnComplete,on_error:commons.AsyncWriteFileOnError?}
M.asyncwritefile = function(filename, content, opts)
  assert(type(opts) == "table")
  assert(type(opts.on_complete) == "function")

  if type(opts.on_error) ~= "function" then
    opts.on_error = function(step, err)
      error(
        string.format(
          "failed to write file(%s), filename:%s, error:%s",
          vim.inspect(step),
          vim.inspect(filename),
          vim.inspect(err)
        )
      )
    end
  end

  uv.fs_open(filename, "w", 438, function(on_open_err, fd)
    if on_open_err then
      opts.on_error("fs_open", on_open_err)
      return
    end
    ---@diagnostic disable-next-line: param-type-mismatch
    uv.fs_write(fd, content, nil, function(on_write_err, bytes)
      if on_write_err then
        opts.on_error("fs_write", on_write_err)
        return
      end
      ---@diagnostic disable-next-line: param-type-mismatch
      uv.fs_close(fd, function(on_close_err)
        if on_close_err then
          opts.on_error("fs_close", on_close_err)
          return
        end
        opts.on_complete(bytes)
      end)
    end)
  end)
end

return M
