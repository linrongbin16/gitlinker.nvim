local async = require("gitlinker.commons.async")

--- Run `fn` in an async context and let its failures reach the test runner.
---
--- `async.run` swallows errors raised in the task body: an assertion written
--- directly inside it passes no matter what. Join the task here and re-raise
--- its traceback on the test thread instead.
--- @param fn fun()
--- @param timeout integer?  milliseconds to wait for `fn`, defaults to 60s.
local function wait_async(fn, timeout)
  local done, err = false, nil
  async.run(function()
    local ok, e = xpcall(fn, debug.traceback)
    if not ok then
      err = e
    end
    done = true
  end)
  if not vim.wait(timeout or 60000, function()
    return done
  end, 10) then
    error("async task timed out", 2)
  end
  if err then
    error(err, 2)
  end
end

local M = {
  wait_async = wait_async,
}

return M
