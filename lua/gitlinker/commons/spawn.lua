local _system
if vim.fn.has("nvim-0.10") == 1 then
  _system = vim.system
else
  _system = require("gitlinker.commons._system").run
end

local M = {}

--- @alias commons.SpawnLineProcessor fun(line:string):any
--- @alias commons.SpawnOpts {on_stdout:commons.SpawnLineProcessor, on_stderr:commons.SpawnLineProcessor, [string]:any}
--- @alias commons.SpawnOnExit fun(completed:vim.SystemCompleted):nil
--- @param cmd string[]
--- @param opts commons.SpawnOpts?  by default {text = true}
--- @param on_exit commons.SpawnOnExit?
--- @return vim.SystemObj
M.run = function(cmd, opts, on_exit)
  opts = opts or {}
  opts.text = type(opts.text) == "boolean" and opts.text or true

  assert(type(opts.on_stdout) == "function")
  assert(type(opts.on_stderr) == "function")

  --- @param buffer string
  --- @param fn_line_processor commons.SpawnLineProcessor
  --- @return integer
  local function _process(buffer, fn_line_processor)
    local strings = require("gitlinker.commons.strings")

    local i = 1
    while i <= #buffer do
      local newline_pos = strings.find(buffer, "\n", i)
      if not newline_pos then
        break
      end
      local line = buffer:sub(i, newline_pos - 1)
      fn_line_processor(line)
      i = newline_pos + 1
    end
    return i
  end

  local stdout_buffer = nil

  --- @param err string?
  --- @param data string?
  local function _handle_stdout(err, data)
    if err then
      error(
        string.format(
          "failed to read stdout on cmd:%s, error:%s",
          vim.inspect(cmd),
          vim.inspect(err)
        )
      )
      return
    end

    if data then
      -- append data to buffer
      stdout_buffer = stdout_buffer and (stdout_buffer .. data) or data
      -- search buffer and process each line
      local i = _process(stdout_buffer, opts.on_stdout)
      -- truncate the printed lines if found any
      stdout_buffer = i <= #stdout_buffer
          and stdout_buffer:sub(i, #stdout_buffer)
        or nil
    elseif stdout_buffer then
      -- foreach the data_buffer and find every line
      local i = _process(stdout_buffer, opts.on_stdout)
      if i <= #stdout_buffer then
        local line = stdout_buffer:sub(i, #stdout_buffer)
        opts.on_stdout(line)
        stdout_buffer = nil
      end
    end
  end

  local stderr_buffer = nil

  --- @param err string?
  --- @param data string?
  local function _handle_stderr(err, data)
    if err then
      error(
        string.format(
          "failed to read stderr on cmd:%s, error:%s",
          vim.inspect(cmd),
          vim.inspect(err)
        )
      )
      return
    end

    if data then
      stderr_buffer = stderr_buffer and (stderr_buffer .. data) or data
      local i = _process(stderr_buffer, opts.on_stderr)
      stderr_buffer = i <= #stderr_buffer
          and stderr_buffer:sub(i, #stderr_buffer)
        or nil
    elseif stderr_buffer then
      local i = _process(stderr_buffer, opts.on_stderr)
      if i <= #stderr_buffer then
        local line = stderr_buffer:sub(i, #stderr_buffer)
        opts.on_stderr(line)
        stderr_buffer = nil
      end
    end
  end

  return _system(cmd, {
    cwd = opts.cwd,
    env = opts.env,
    clear_env = opts.clear_env,
    ---@diagnostic disable-next-line: assign-type-mismatch
    stdin = opts.stdin,
    stdout = _handle_stdout,
    stderr = _handle_stderr,
    text = opts.text,
    timeout = opts.timeout,
    detach = opts.detach,
  }, on_exit)
end

return M
