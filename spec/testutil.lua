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
---
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

--- Wait until no async task is left running.
---
--- `link()` and `:GitLink` start a task nobody waits on. The url reaches the
--- action a few scheduled steps before the task ends, and the steps after that
--- still run git commands -- through whatever `vim.system` is installed at the
--- time. A fixed sleep guesses how many steps are left: too short and a
--- leftover step runs against the real API, too long and a fast machine idles.
--- Ask the async tree instead, which empties exactly when the last task ends.
---
--- `Task:wait()` cannot be used here: the callers do not keep the task, and
--- joining one fails on `highlight_duration` being nil (`_highlight_target`
--- compares it to 0).
--- @param timeout integer? milliseconds to wait, defaults to 5s.
--- @return boolean drained
local function wait_for_tasks(timeout)
  local tasks = require("gitlinker.async")
  local function drained()
    return tasks._inspect_tree() == ""
  end
  if not vim.wait(timeout or 5000, drained, 10) then
    return false
  end
  -- The logger hands its message to `vim.schedule()` before the task returns,
  -- so the tree can be empty while those notifications are still queued. Wait
  -- for a callback queued after them: `vim.schedule` runs callbacks in order.
  local flushed = false
  vim.schedule(function()
    flushed = true
  end)
  return vim.wait(1000, function()
    return flushed
  end, 1) and drained()
end

local M = {
  wait_async = wait_async,
  answering_picker = answering_picker,
  wait_for_tasks = wait_for_tasks,
}

return M
