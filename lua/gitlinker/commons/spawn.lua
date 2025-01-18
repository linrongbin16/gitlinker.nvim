local M = {}

--- @alias commons.SpawnOnLine fun(line:string):any
--- @alias commons.SpawnOnExit fun(result:{exitcode:integer?,signal:integer?}?):nil
--- @alias commons.SpawnOpts {on_stdout:commons.SpawnOnLine,on_stderr:commons.SpawnOnLine?,[string]:any}
--- @alias commons.SpawnJob {obj:vim.SystemObj,opts:commons.SpawnOpts,on_exit:commons.SpawnOnExit?}

--- @param cmd string[]
--- @param opts commons.SpawnOpts?
--- @param on_exit commons.SpawnOnExit?
--- @return commons.SpawnJob
local function _impl(cmd, opts, on_exit)
  opts = opts or {}

  if opts.text == nil then
    opts.text = true
  end
  if type(opts.on_stderr) ~= "function" then
    opts.on_stderr = function() end
  end

  assert(type(opts.on_stdout) == "function", "Spawn job must have 'on_stdout' function in 'opts'")
  assert(type(opts.on_stderr) == "function", "Spawn job must have 'on_stderr' function in 'opts'")
  assert(type(on_exit) == "function" or on_exit == nil)

  --- @param buffer string
  --- @param fn_line_processor commons.SpawnOnLine
  --- @return integer
  local function _process(buffer, fn_line_processor)
    local str = require("gitlinker.commons.str")

    local i = 1
    while i <= #buffer do
      local newline_pos = str.find(buffer, "\n", i)
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
      -- truncate the processed lines if still exists any
      stdout_buffer = i <= #stdout_buffer and stdout_buffer:sub(i, #stdout_buffer) or nil
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
      stderr_buffer = i <= #stderr_buffer and stderr_buffer:sub(i, #stderr_buffer) or nil
    elseif stderr_buffer then
      local i = _process(stderr_buffer, opts.on_stderr)
      if i <= #stderr_buffer then
        local line = stderr_buffer:sub(i, #stderr_buffer)
        opts.on_stderr(line)
        stderr_buffer = nil
      end
    end
  end

  --- @param completed vim.SystemCompleted
  local function _handle_exit(completed)
    assert(type(on_exit) == "function")
    on_exit({ exitcode = completed.code, signal = completed.signal })
  end

  local obj
  if type(on_exit) == "function" then
    obj = vim.system(cmd, {
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
    }, _handle_exit)
  else
    obj = vim.system(cmd, {
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
    })
  end

  return { obj = obj, opts = opts, on_exit = on_exit }
end

--- @param cmd string[]
--- @param opts commons.SpawnOpts?
--- @param on_exit commons.SpawnOnExit
--- @return commons.SpawnJob
M.detached = function(cmd, opts, on_exit)
  opts = opts or {}

  assert(
    type(opts.on_stdout) == "function",
    "Detached spawn job must have 'on_stdout' function in 'opts'"
  )
  assert(opts.on_exit == nil, "Detached spawn job cannot have 'on_exit' function in 'opts'")
  assert(
    type(on_exit) == "function",
    "Detached spawn job must have 'on_exit' function in 3rd parameter"
  )

  return _impl(cmd, opts, on_exit)
end

--- @param cmd string[]
--- @param opts commons.SpawnOpts?
--- @return commons.SpawnJob
M.waitable = function(cmd, opts)
  opts = opts or {}

  assert(
    type(opts.on_stdout) == "function",
    "Waitable spawn job must have 'on_stdout' function in 'opts'"
  )
  assert(opts.on_exit == nil, "Waitable spawn job cannot have 'on_exit' function in 'opts'")

  return _impl(cmd, opts)
end

--- @param job commons.SpawnJob
--- @param timeout integer?
--- @return {exitcode:integer?,signal:integer?}
M.wait = function(job, timeout)
  assert(type(job) == "table", "Spawn job must be a 'commons.SpawnJob' object")
  assert(job.obj ~= nil, "Spawn job must be a 'commons.SpawnJob' object")
  assert(type(job.opts) == "table", "Spawn job must be a 'commons.SpawnJob' object")
  assert(
    job.on_exit == nil,
    "Detached spawn job cannot 'wait' for its exit, it already has 'on_exit' in 3rd parameter for its exit"
  )

  local completed
  if type(timeout) == "number" and timeout >= 0 then
    completed = job.obj:wait(timeout) --[[@as vim.SystemCompleted]]
  else
    completed = job.obj:wait() --[[@as vim.SystemCompleted]]
  end
  return { exitcode = completed.code, signal = completed.signal }
end

return M
