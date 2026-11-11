local async = require("gitlinker.async")

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

--- Answer the builtin picker with its first item while `fn` runs.
---
--- Some cases run against this checkout, which may have more than one remote.
--- The builtin `vim.ui.select` then parks the editor in an `inputlist` prompt,
--- and nothing answers it in a headless run: the suite hangs instead of
--- failing. Answer it, and put the real picker back afterwards.
--- @param fn fun()
local function answering_picker(fn)
  local saved = vim.ui.select
  vim.ui.select = function(items, _, on_choice)
    on_choice(items[1], 1)
  end
  local ok, err = pcall(fn)
  vim.ui.select = saved
  if not ok then
    error(err, 0)
  end
end

local M = {
  wait_async = wait_async,
  answering_picker = answering_picker,
}

return M
